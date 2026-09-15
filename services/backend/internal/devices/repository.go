package devices

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"

	syn "github.com/zwecodes/g9pos/backend/internal/event"
	"github.com/zwecodes/g9pos/backend/pkg/nulljson"
)

type Device struct {
	ID          string         `db:"id" json:"id"`
	UserID      string         `db:"user_id" json:"user_id"`
	Name        string         `db:"name" json:"name"`
	Type        string         `db:"type" json:"type"`
	IsActivePOS bool           `db:"is_active_pos" json:"is_active_pos"`
	LastSeenAt  sql.NullTime   `db:"last_seen_at" json:"-"`
	LastSyncAt  sql.NullTime   `db:"last_sync_at" json:"-"`
	AppVersion  nulljson.String `db:"app_version" json:"app_version"`
	CreatedAt   time.Time      `db:"created_at" json:"-"`
	RevokedAt   sql.NullTime   `db:"revoked_at" json:"-"`
	LastSeenAtMs *int64        `json:"last_seen_at"`
	LastSyncAtMs *int64        `json:"last_sync_at"`
	RevokedAtMs  *int64        `json:"revoked_at"`
	CreatedAtMs  int64         `json:"created_at"`
}

type Repository struct{ db *sqlx.DB }

func NewRepository(db *sqlx.DB) *Repository { return &Repository{db: db} }

func (r *Repository) List(ctx context.Context) ([]Device, error) {
	var rows []Device
	err := r.db.SelectContext(ctx, &rows, `SELECT * FROM devices ORDER BY created_at`)
	if err != nil {
		return nil, fmt.Errorf("devices.List: %w", err)
	}
	return rows, nil
}

func (r *Repository) Rename(ctx context.Context, id, name string) error {
	res, err := r.db.ExecContext(ctx, `UPDATE devices SET name=$2 WHERE id=$1`, id, name)
	if err != nil {
		return fmt.Errorf("devices.Rename: %w", err)
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *Repository) Revoke(ctx context.Context, id string, at time.Time) error {
	res, err := r.db.ExecContext(ctx, `UPDATE devices SET revoked_at=$2 WHERE id=$1`, id, at)
	if err != nil {
		return fmt.Errorf("devices.Revoke: %w", err)
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *Repository) Activate(ctx context.Context, tx *sqlx.Tx, id string) error {
	if _, err := tx.ExecContext(ctx, `UPDATE devices SET is_active_pos = false WHERE is_active_pos = true`); err != nil {
		return fmt.Errorf("devices.Activate clear: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `UPDATE devices SET is_active_pos = true WHERE id = $1`, id); err != nil {
		return fmt.Errorf("devices.Activate: %w", err)
	}
	return nil
}

func (r *Repository) TouchSync(ctx context.Context, id string, at time.Time) error {
	_, err := r.db.ExecContext(ctx, `UPDATE devices SET last_sync_at=$2, last_seen_at=$2 WHERE id=$1`, id, at)
	if err != nil {
		return fmt.Errorf("devices.TouchSync: %w", err)
	}
	return nil
}

type Service struct{ repo *Repository }

func NewService(repo *Repository) *Service { return &Service{repo: repo} }

func (s *Service) List(ctx context.Context) ([]Device, error) {
	rows, err := s.repo.List(ctx)
	if err != nil {
		return nil, err
	}
	for i := range rows {
		decorate(&rows[i])
	}
	return rows, nil
}

func (s *Service) Rename(ctx context.Context, id, name string) error {
	if name == "" {
		return fmt.Errorf("validation")
	}
	return s.repo.Rename(ctx, id, name)
}

func (s *Service) Revoke(ctx context.Context, id string) error {
	return s.repo.Revoke(ctx, id, time.Now().UTC())
}

func (s *Service) HandleEvent(ctx context.Context, tx *sqlx.Tx, ev syn.Event) error {
	if ev.EventType != "DEVICE_ACTIVATED" {
		return syn.Reject("EVENT_VALIDATION_FAILED", "This change could not be saved.", map[string]any{"field": "event_type"})
	}
	return s.repo.Activate(ctx, tx, ev.DeviceID)
}

func (s *Service) TouchSync(ctx context.Context, id string) {
	_ = s.repo.TouchSync(ctx, id, time.Now().UTC())
}

func decorate(d *Device) {
	d.CreatedAtMs = d.CreatedAt.UnixMilli()
	if d.LastSeenAt.Valid {
		ms := d.LastSeenAt.Time.UnixMilli()
		d.LastSeenAtMs = &ms
	}
	if d.LastSyncAt.Valid {
		ms := d.LastSyncAt.Time.UnixMilli()
		d.LastSyncAtMs = &ms
	}
	if d.RevokedAt.Valid {
		ms := d.RevokedAt.Time.UnixMilli()
		d.RevokedAtMs = &ms
	}
}
