package products

import (
	"context"
	"encoding/json"
	"time"

	"github.com/jmoiron/sqlx"

	syn "github.com/zwecodes/g9pos/backend/internal/event"
	"github.com/zwecodes/g9pos/backend/pkg/nulljson"
	"github.com/zwecodes/g9pos/backend/pkg/timezone"
)

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service { return &Service{repo: repo} }

func (s *Service) List(ctx context.Context, categoryID, q string, active *bool, lowStockOnly bool) ([]Product, error) {
	rows, err := s.repo.List(ctx, categoryID, q, active, lowStockOnly)
	if err != nil {
		return nil, err
	}
	for i := range rows {
		decorateProduct(&rows[i])
	}
	return rows, nil
}

func (s *Service) Get(ctx context.Context, id string) (*Product, error) {
	p, err := s.repo.Get(ctx, id)
	if err != nil || p == nil {
		return p, err
	}
	decorateProduct(p)
	return p, nil
}

func (s *Service) FindActiveByBarcodeTx(ctx context.Context, tx *sqlx.Tx, barcode string) (*Product, error) {
	return s.repo.FindActiveByBarcodeTx(ctx, tx, barcode)
}

func (s *Service) GetTx(ctx context.Context, tx *sqlx.Tx, id string) (*Product, error) {
	return s.repo.GetTx(ctx, tx, id)
}

func (s *Service) InsertTx(ctx context.Context, tx *sqlx.Tx, p Product) error {
	return s.repo.Insert(ctx, tx, p)
}

func (s *Service) SetStockNegative(ctx context.Context, tx *sqlx.Tx, id string, negative bool) error {
	return s.repo.SetStockNegative(ctx, tx, id, negative)
}

type productPayload struct {
	CategoryID        *string `json:"category_id"`
	Name              string  `json:"name"`
	Barcode           *string `json:"barcode"`
	PriceMmk          int     `json:"price_mmk"`
	CostPriceMmk      *int    `json:"cost_price_mmk"`
	Unit              string  `json:"unit"`
	LowStockThreshold int     `json:"low_stock_threshold"`
	ImagePath         *string `json:"image_path"`
	IsActive          *bool   `json:"is_active"`
}

func (s *Service) HandleEvent(ctx context.Context, tx *sqlx.Tx, ev syn.Event) error {
	var p productPayload
	_ = json.Unmarshal(ev.Raw, &p)
	at := timezone.FromUnixMs(ev.CreatedAt)
	existing, err := s.repo.GetTx(ctx, tx, ev.ID)
	if err != nil {
		return err
	}
	row := fromPayload(ev, p, at)

	switch ev.EventType {
	case "PRODUCT_CREATED":
		if existing != nil {
			return nil
		}
		return s.repo.Insert(ctx, tx, row)
	case "PRODUCT_UPDATED":
		if existing != nil && !syn.IncomingWins(existing.UpdatedAt.UnixMilli(), ev.CreatedAt) {
			return &syn.ConflictError{WinningPayload: winningProduct(existing)}
		}
		if existing == nil {
			return s.repo.Insert(ctx, tx, row)
		}
		return s.repo.Update(ctx, tx, row)
	case "PRODUCT_DELETED":
		if existing != nil && !syn.IncomingWins(existing.UpdatedAt.UnixMilli(), ev.CreatedAt) {
			return &syn.ConflictError{WinningPayload: winningProduct(existing)}
		}
		return s.repo.SoftDelete(ctx, tx, ev.ID, at, ev.DeviceID)
	}
	return syn.Reject("EVENT_VALIDATION_FAILED", "This change could not be saved.", map[string]any{"field": "event_type"})
}

func fromPayload(ev syn.Event, p productPayload, at time.Time) Product {
	unit := p.Unit
	if unit == "" {
		unit = "pcs"
	}
	threshold := p.LowStockThreshold
	if threshold == 0 {
		threshold = 5
	}
	active := true
	if p.IsActive != nil {
		active = *p.IsActive
	}
	row := Product{
		ID:                ev.ID,
		Name:              p.Name,
		PriceMmk:          p.PriceMmk,
		Unit:              unit,
		LowStockThreshold: threshold,
		IsActive:          active,
		CreatedAt:         at,
		UpdatedAt:         at,
		DeviceID:          ev.DeviceID,
	}
	if p.CategoryID != nil && *p.CategoryID != "" {
		row.CategoryID = nulljson.Text(*p.CategoryID)
	}
	if p.Barcode != nil && *p.Barcode != "" {
		row.Barcode = nulljson.Text(*p.Barcode)
	}
	if p.CostPriceMmk != nil {
		row.CostPriceMmk = nulljson.Int(int64(*p.CostPriceMmk))
	}
	if p.ImagePath != nil && *p.ImagePath != "" {
		row.ImagePath = nulljson.Text(*p.ImagePath)
	}
	return row
}

func decorateProduct(p *Product) {
	p.CreatedAtMs = p.CreatedAt.UnixMilli()
	p.UpdatedAtMs = p.UpdatedAt.UnixMilli()
}

func winningProduct(p *Product) map[string]any {
	return map[string]any{
		"id": p.ID, "name": p.Name, "price_mmk": p.PriceMmk,
		"updated_at": p.UpdatedAt.UnixMilli(),
	}
}
