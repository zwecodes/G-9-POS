package inventory

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"

	syn "github.com/zwecodes/g9pos/backend/internal/event"
	"github.com/zwecodes/g9pos/backend/pkg/nulljson"
	"github.com/zwecodes/g9pos/backend/pkg/timezone"
)

type EventRow struct {
	ID               string         `db:"id" json:"id"`
	ProductID        string         `db:"product_id" json:"product_id"`
	EventType        string         `db:"event_type" json:"event_type"`
	QuantityDelta    int            `db:"quantity_delta" json:"quantity_delta"`
	ReferenceID      nulljson.String `db:"reference_id" json:"reference_id"`
	ReferenceType    string          `db:"reference_type" json:"reference_type"`
	Note             nulljson.String `db:"note" json:"note"`
	OperatorID       string         `db:"operator_id" json:"operator_id"`
	DeviceID         string         `db:"device_id" json:"device_id"`
	CreatedAt        time.Time      `db:"created_at" json:"-"`
	ServerReceivedAt sql.NullTime   `db:"server_received_at" json:"-"`
	CreatedAtMs      int64          `json:"created_at"`
}

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository { return &Repository{db: db} }

func (r *Repository) Exists(ctx context.Context, tx *sqlx.Tx, id string) (bool, error) {
	var n int
	err := tx.GetContext(ctx, &n, `SELECT COUNT(*) FROM inventory_events WHERE id = $1`, id)
	if err != nil {
		return false, fmt.Errorf("inventory.Exists: %w", err)
	}
	return n > 0, nil
}

func (r *Repository) Insert(ctx context.Context, tx *sqlx.Tx, e EventRow) error {
	_, err := tx.ExecContext(ctx, `
		INSERT INTO inventory_events (
			id, product_id, event_type, quantity_delta, reference_id, reference_type,
			note, operator_id, device_id, created_at, server_received_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
		ON CONFLICT (id) DO NOTHING`,
		e.ID, e.ProductID, e.EventType, e.QuantityDelta, nullStr(e.ReferenceID), e.ReferenceType,
		nullStr(e.Note), e.OperatorID, e.DeviceID, e.CreatedAt, e.ServerReceivedAt)
	if err != nil {
		return fmt.Errorf("inventory.Insert: %w", err)
	}
	return nil
}

func (r *Repository) Stock(ctx context.Context, tx *sqlx.Tx, productID string) (int, error) {
	var n sql.NullInt64
	err := tx.GetContext(ctx, &n, `SELECT SUM(quantity_delta) FROM inventory_events WHERE product_id = $1`, productID)
	if err != nil {
		return 0, fmt.Errorf("inventory.Stock: %w", err)
	}
	if !n.Valid {
		return 0, nil
	}
	return int(n.Int64), nil
}

func (r *Repository) ListForProduct(ctx context.Context, productID string) ([]EventRow, error) {
	var rows []EventRow
	err := r.db.SelectContext(ctx, &rows, `
		SELECT id, product_id, event_type, quantity_delta, reference_id, reference_type,
		       note, operator_id, device_id, created_at, server_received_at
		FROM inventory_events WHERE product_id = $1 ORDER BY created_at DESC`, productID)
	if err != nil {
		return nil, fmt.Errorf("inventory.ListForProduct: %w", err)
	}
	return rows, nil
}

func nullStr(v nulljson.String) any {
	if !v.Valid {
		return nil
	}
	return v.String
}

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service { return &Service{repo: repo} }

type invPayload struct {
	ProductID     string  `json:"product_id"`
	QuantityDelta int     `json:"quantity_delta"`
	ReferenceID   *string `json:"reference_id"`
	ReferenceType string  `json:"reference_type"`
	Note          *string `json:"note"`
	OperatorID    string  `json:"operator_id"`
}

func (s *Service) HandleEvent(ctx context.Context, tx *sqlx.Tx, ev syn.Event, receivedAt time.Time) error {
	exists, err := s.repo.Exists(ctx, tx, ev.ID)
	if err != nil {
		return err
	}
	if exists {
		return nil
	}

	if ev.EventType == "INVENTORY_ADJUSTED" || ev.EventType == "INVENTORY_DAMAGED" {
		var p invPayload
		_ = json.Unmarshal(ev.Raw, &p)
		if p.Note == nil || *p.Note == "" {
			return syn.Reject("EVENT_VALIDATION_FAILED",
				"Please add a note for this stock change.",
				map[string]any{"field": "note"})
		}
	}

	var p invPayload
	_ = json.Unmarshal(ev.Raw, &p)
	if p.ProductID == "" {
		p.ProductID = ev.ID
	}
	refType := p.ReferenceType
	if refType == "" {
		refType = defaultRefType(ev.EventType)
	}
	row := EventRow{
		ID:            ev.ID,
		ProductID:     p.ProductID,
		EventType:     ev.EventType,
		QuantityDelta: p.QuantityDelta,
		ReferenceType: refType,
		OperatorID:    firstNonEmpty(p.OperatorID, ev.OperatorID),
		DeviceID:      ev.DeviceID,
		CreatedAt:     timezone.FromUnixMs(ev.CreatedAt),
		ServerReceivedAt: sql.NullTime{Time: receivedAt, Valid: true},
	}
	ref := p.ReferenceID
	if ref == nil {
		ref = ev.ReferenceID
	}
	if ref != nil && *ref != "" {
		row.ReferenceID = nulljson.Text(*ref)
	}
	if p.Note != nil && *p.Note != "" {
		row.Note = nulljson.Text(*p.Note)
	}
	return s.repo.Insert(ctx, tx, row)
}

func (s *Service) Stock(ctx context.Context, tx *sqlx.Tx, productID string) (int, error) {
	return s.repo.Stock(ctx, tx, productID)
}

func (s *Service) InsertTx(ctx context.Context, tx *sqlx.Tx, e EventRow) error {
	return s.repo.Insert(ctx, tx, e)
}

func (s *Service) ListForProduct(ctx context.Context, productID string) ([]EventRow, error) {
	rows, err := s.repo.ListForProduct(ctx, productID)
	if err != nil {
		return nil, err
	}
	for i := range rows {
		rows[i].CreatedAtMs = rows[i].CreatedAt.UnixMilli()
	}
	return rows, nil
}

func defaultRefType(t string) string {
	switch t {
	case "INVENTORY_SOLD":
		return "sale"
	case "INVENTORY_VOIDED":
		return "sale_void"
	case "INVENTORY_RESTOCKED":
		return "restock"
	case "INVENTORY_ADJUSTED":
		return "adjustment"
	case "INVENTORY_DAMAGED":
		return "damage"
	case "INVENTORY_RETURNED":
		return "return"
	default:
		return "adjustment"
	}
}

func firstNonEmpty(a, b string) string {
	if a != "" {
		return a
	}
	return b
}
