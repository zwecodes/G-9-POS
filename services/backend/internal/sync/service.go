package sync

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/jmoiron/sqlx"

	"github.com/zwecodes/g9pos/backend/internal/categories"
	"github.com/zwecodes/g9pos/backend/internal/dashboard"
	"github.com/zwecodes/g9pos/backend/internal/devices"
	"github.com/zwecodes/g9pos/backend/internal/inventory"
	"github.com/zwecodes/g9pos/backend/internal/products"
	"github.com/zwecodes/g9pos/backend/internal/sales"
)

const (
	maxBatchEvents = 50
	maxBatchBytes  = 5 << 20
)

type Service struct {
	repo       *Repository
	processor  *Processor
	categories *categories.Service
	products   *products.Service
	inventory  *inventory.Service
	sales      *sales.Service
	devices    *devices.Service
	hub        *dashboard.Hub
}

func NewService(
	repo *Repository,
	processor *Processor,
	categories *categories.Service,
	products *products.Service,
	inventory *inventory.Service,
	sales *sales.Service,
	devices *devices.Service,
	hub *dashboard.Hub,
) *Service {
	return &Service{
		repo:       repo,
		processor:  processor,
		categories: categories,
		products:   products,
		inventory:  inventory,
		sales:      sales,
		devices:    devices,
		hub:        hub,
	}
}

type BatchRequest struct {
	DeviceID string            `json:"device_id"`
	Events   []json.RawMessage `json:"events"`
}

type RejectedEvent struct {
	ID          string         `json:"id"`
	ReferenceID *string        `json:"reference_id"`
	Reason      string         `json:"reason"`
	Message     string         `json:"message"`
	Detail      map[string]any `json:"detail"`
}

type ConflictEvent struct {
	ID             string `json:"id"`
	Resolution     string `json:"resolution"`
	WinningPayload any    `json:"winning_payload"`
}

type StockCorrection struct {
	ProductID      string `json:"product_id"`
	ComputedStock  int    `json:"computed_stock"`
	StockNegative  bool   `json:"stock_negative"`
}

type BatchResult struct {
	Accepted         []string          `json:"accepted"`
	Conflicts        []ConflictEvent   `json:"conflicts"`
	Rejected         []RejectedEvent   `json:"rejected"`
	StockCorrections []StockCorrection `json:"stock_corrections"`
}

func (s *Service) SubmitBatch(ctx context.Context, role, jwtDeviceID string, raw []byte, req BatchRequest) (BatchResult, error) {
	out := BatchResult{
		Accepted:         []string{},
		Conflicts:        []ConflictEvent{},
		Rejected:         []RejectedEvent{},
		StockCorrections: []StockCorrection{},
	}
	if len(raw) > maxBatchBytes {
		return out, errPayloadTooLarge
	}
	if len(req.Events) > maxBatchEvents {
		return out, errPayloadTooLarge
	}
	if req.DeviceID != "" && jwtDeviceID != "" && req.DeviceID != jwtDeviceID {
		return out, errDeviceMismatch
	}
	deviceID := jwtDeviceID
	if deviceID == "" {
		deviceID = req.DeviceID
	}

	events := make([]Event, 0, len(req.Events))
	for _, rawEv := range req.Events {
		ev, err := Unmarshal(rawEv)
		if err != nil || ev.ID == "" || ev.EventType == "" {
			return out, errInvalidBatch
		}
		if ev.DeviceID == "" {
			ev.DeviceID = deviceID
		}
		events = append(events, ev)
	}

	receivedAt := time.Now().UTC()
	for _, group := range groupEvents(events) {
		res, err := s.applyGroup(ctx, group, role, receivedAt)
		if err != nil {
			return out, err
		}
		out.Accepted = append(out.Accepted, res.accepted...)
		out.Conflicts = append(out.Conflicts, res.conflicts...)
		out.Rejected = append(out.Rejected, res.rejected...)
		out.StockCorrections = append(out.StockCorrections, res.stock...)
	}

	if deviceID != "" {
		s.devices.TouchSync(ctx, deviceID)
		if s.hub != nil {
			s.hub.Broadcast("device.sync_status", map[string]any{
				"device_id":    deviceID,
				"last_sync_at": receivedAt.UnixMilli(),
			})
		}
	}
	return out, nil
}

type groupOutcome struct {
	accepted  []string
	conflicts []ConflictEvent
	rejected  []RejectedEvent
	stock     []StockCorrection
}

func (s *Service) applyGroup(ctx context.Context, group []Event, role string, receivedAt time.Time) (groupOutcome, error) {
	out := groupOutcome{}
	if len(group) == 0 {
		return out, nil
	}

	for _, ev := range group {
		if !roleAllows(role, ev.EventType) {
			return rejectGroup(group, Reject("ROLE_NOT_PERMITTED",
				"You do not have permission to do that.", map[string]any{})), nil
		}
	}

	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return out, fmt.Errorf("sync.applyGroup begin: %w", err)
	}
	defer tx.Rollback()

	productIDs := map[string]struct{}{}
	var saleCreatedID string
	var saleVoidedID string
	var voidReason string
	var activatedDevice string

	for _, ev := range group {
		if err := s.processor.Apply(ctx, tx, ev, receivedAt); err != nil {
			var perm *PermanentError
			if errors.As(err, &perm) {
				return rejectGroup(group, perm), nil
			}
			var conf *ConflictError
			if errors.As(err, &conf) {
				return conflictGroup(group, conf), nil
			}
			return out, fmt.Errorf("sync.applyGroup %s: %w", ev.EventType, err)
		}
		if pid := eventProductID(ev); pid != "" && isInventoryType(ev.EventType) {
			productIDs[pid] = struct{}{}
		}
		switch ev.EventType {
		case "SALE_CREATED":
			saleCreatedID = ev.ID
		case "SALE_VOIDED":
			saleVoidedID = ev.ID
			if ev.ReferenceID != nil && *ev.ReferenceID != "" {
				saleVoidedID = *ev.ReferenceID
			}
			var p struct {
				VoidReason *string `json:"void_reason"`
			}
			_ = json.Unmarshal(ev.Raw, &p)
			if p.VoidReason != nil {
				voidReason = *p.VoidReason
			}
		case "DEVICE_ACTIVATED":
			activatedDevice = ev.DeviceID
		}
	}

	stock, alerts, err := s.stockAfter(ctx, tx, productIDs)
	if err != nil {
		return out, err
	}
	if err := tx.Commit(); err != nil {
		return out, fmt.Errorf("sync.applyGroup commit: %w", err)
	}

	ids := make([]string, 0, len(group))
	for _, ev := range group {
		ids = append(ids, ev.ID)
	}
	out.accepted = ids
	out.stock = stock

	if s.hub != nil {
		for _, a := range alerts {
			s.hub.Broadcast(a.event, a.payload)
		}
		if saleCreatedID != "" {
			if sale, err := s.sales.Get(ctx, saleCreatedID); err == nil && sale != nil {
				s.hub.Broadcast("sale.created", map[string]any{"sale": sale})
			}
		}
		if saleVoidedID != "" {
			s.hub.Broadcast("sale.voided", map[string]any{
				"sale_id":     saleVoidedID,
				"void_reason": voidReason,
			})
		}
		if activatedDevice != "" {
			s.hub.Broadcast("device.activated", map[string]any{"device_id": activatedDevice})
		}
	}
	return out, nil
}

type wsAlert struct {
	event   string
	payload map[string]any
}

func (s *Service) stockAfter(ctx context.Context, tx *sqlx.Tx, productIDs map[string]struct{}) ([]StockCorrection, []wsAlert, error) {
	var corrections []StockCorrection
	var alerts []wsAlert
	for id := range productIDs {
		stock, err := s.inventory.Stock(ctx, tx, id)
		if err != nil {
			return nil, nil, err
		}
		negative := stock < 0
		if err := s.products.SetStockNegative(ctx, tx, id, negative); err != nil {
			return nil, nil, err
		}
		if negative {
			corrections = append(corrections, StockCorrection{
				ProductID: id, ComputedStock: stock, StockNegative: true,
			})
			alerts = append(alerts, wsAlert{
				event:   "stock.negative",
				payload: map[string]any{"product_id": id, "computed_stock": stock},
			})
		}
		p, err := s.products.GetTx(ctx, tx, id)
		if err != nil {
			return nil, nil, err
		}
		if p != nil && stock <= p.LowStockThreshold {
			alerts = append(alerts, wsAlert{
				event: "stock.low",
				payload: map[string]any{
					"product_id":     id,
					"computed_stock": stock,
					"threshold":      p.LowStockThreshold,
				},
			})
		}
	}
	return corrections, alerts, nil
}

func rejectGroup(group []Event, perm *PermanentError) groupOutcome {
	out := groupOutcome{rejected: make([]RejectedEvent, 0, len(group))}
	for _, ev := range group {
		out.rejected = append(out.rejected, RejectedEvent{
			ID:          ev.ID,
			ReferenceID: ev.ReferenceID,
			Reason:      perm.Reason,
			Message:     perm.Message,
			Detail:      perm.Detail,
		})
	}
	return out
}

func conflictGroup(group []Event, conf *ConflictError) groupOutcome {
	out := groupOutcome{conflicts: make([]ConflictEvent, 0, len(group))}
	for _, ev := range group {
		out.conflicts = append(out.conflicts, ConflictEvent{
			ID:             ev.ID,
			Resolution:     "server_version_wins",
			WinningPayload: conf.WinningPayload,
		})
	}
	return out
}

func (s *Service) Pull(ctx context.Context, deviceID, lastSync string) (PullPayload, error) {
	since, firstRun := parseLastSync(lastSync)
	return s.repo.Pull(ctx, deviceID, since, firstRun)
}

func parseLastSync(s string) (time.Time, bool) {
	if s == "" || s == "0" {
		return time.Time{}, true
	}
	n, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		t, err := time.Parse(time.RFC3339, s)
		if err != nil {
			return time.Time{}, true
		}
		return t.UTC(), false
	}
	if n <= 0 {
		return time.Time{}, true
	}
	if n > 1e12 {
		return time.UnixMilli(n).UTC(), false
	}
	return time.Unix(n, 0).UTC(), false
}

var (
	errPayloadTooLarge = errors.New("payload too large")
	errInvalidBatch    = errors.New("invalid batch")
	errDeviceMismatch  = errors.New("device mismatch")
)

func IsPayloadTooLarge(err error) bool { return errors.Is(err, errPayloadTooLarge) }
func IsInvalidBatch(err error) bool    { return errors.Is(err, errInvalidBatch) }
func IsDeviceMismatch(err error) bool  { return errors.Is(err, errDeviceMismatch) }
