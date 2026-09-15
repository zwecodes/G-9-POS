package categories

import (
	"context"
	"encoding/json"

	"github.com/jmoiron/sqlx"

	syn "github.com/zwecodes/g9pos/backend/internal/event"
	"github.com/zwecodes/g9pos/backend/pkg/timezone"
)

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service { return &Service{repo: repo} }

func (s *Service) List(ctx context.Context, includeDeleted bool) ([]Category, error) {
	rows, err := s.repo.List(ctx, includeDeleted)
	if err != nil {
		return nil, err
	}
	for i := range rows {
		decorateCategory(&rows[i])
	}
	return rows, nil
}

func (s *Service) FindByNameTx(ctx context.Context, tx *sqlx.Tx, name string) (*Category, error) {
	return s.repo.FindByName(ctx, tx, name)
}

func (s *Service) InsertTx(ctx context.Context, tx *sqlx.Tx, c Category) error {
	return s.repo.Insert(ctx, tx, c)
}

type catPayload struct {
	Name      string `json:"name"`
	SortOrder int    `json:"sort_order"`
}

func (s *Service) HandleEvent(ctx context.Context, tx *sqlx.Tx, ev syn.Event) error {
	var p catPayload
	_ = json.Unmarshal(ev.Raw, &p)
	at := timezone.FromUnixMs(ev.CreatedAt)
	existing, err := s.repo.Get(ctx, tx, ev.ID)
	if err != nil {
		return err
	}

	switch ev.EventType {
	case "CATEGORY_CREATED":
		if existing != nil {
			return nil
		}
		return s.repo.Insert(ctx, tx, Category{
			ID: ev.ID, Name: p.Name, SortOrder: p.SortOrder,
			CreatedAt: at, UpdatedAt: at, DeviceID: ev.DeviceID,
		})
	case "CATEGORY_UPDATED":
		if existing != nil && !syn.IncomingWins(existing.UpdatedAt.UnixMilli(), ev.CreatedAt) {
			return &syn.ConflictError{WinningPayload: winningCategory(existing)}
		}
		if existing == nil {
			return s.repo.Insert(ctx, tx, Category{
				ID: ev.ID, Name: p.Name, SortOrder: p.SortOrder,
				CreatedAt: at, UpdatedAt: at, DeviceID: ev.DeviceID,
			})
		}
		existing.Name = p.Name
		existing.SortOrder = p.SortOrder
		existing.UpdatedAt = at
		existing.DeviceID = ev.DeviceID
		return s.repo.Update(ctx, tx, *existing)
	case "CATEGORY_DELETED":
		n, err := s.repo.CountActiveProducts(ctx, tx, ev.ID)
		if err != nil {
			return err
		}
		if n > 0 {
			return syn.Reject("CATEGORY_HAS_PRODUCTS",
				"This category still has products. Move them first.",
				map[string]any{"blocking_product_count": n})
		}
		if existing != nil && !syn.IncomingWins(existing.UpdatedAt.UnixMilli(), ev.CreatedAt) {
			return &syn.ConflictError{WinningPayload: winningCategory(existing)}
		}
		return s.repo.SoftDelete(ctx, tx, ev.ID, at, ev.DeviceID)
	}
	return syn.Reject("EVENT_VALIDATION_FAILED", "This change could not be saved.", map[string]any{"field": "event_type"})
}

func decorateCategory(c *Category) {
	c.CreatedAtMs = c.CreatedAt.UnixMilli()
	c.UpdatedAtMs = c.UpdatedAt.UnixMilli()
	if c.DeletedAt.Valid {
		ms := c.DeletedAt.Time.UnixMilli()
		c.DeletedAtMs = &ms
	}
}

func winningCategory(c *Category) map[string]any {
	return map[string]any{
		"id": c.ID, "name": c.Name, "sort_order": c.SortOrder,
		"created_at": c.CreatedAt.UnixMilli(), "updated_at": c.UpdatedAt.UnixMilli(),
	}
}
