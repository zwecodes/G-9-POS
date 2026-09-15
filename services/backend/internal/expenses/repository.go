package expenses

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

type Expense struct {
	ID          string         `db:"id" json:"id"`
	Category    string         `db:"category" json:"category"`
	AmountMmk   int            `db:"amount_mmk" json:"amount_mmk"`
	Note        nulljson.String `db:"note" json:"note"`
	ExpenseDate string         `db:"expense_date" json:"expense_date"`
	OperatorID  string         `db:"operator_id" json:"operator_id"`
	DeviceID    string         `db:"device_id" json:"device_id"`
	CreatedAt   time.Time      `db:"created_at" json:"-"`
	UpdatedAt   time.Time      `db:"updated_at" json:"-"`
	DeletedAt   sql.NullTime   `db:"deleted_at" json:"-"`
	CreatedAtMs int64          `json:"created_at"`
	UpdatedAtMs int64          `json:"updated_at"`
}

type Repository struct{ db *sqlx.DB }

func NewRepository(db *sqlx.DB) *Repository { return &Repository{db: db} }

func (r *Repository) List(ctx context.Context, dateFrom, dateTo, category string) ([]Expense, error) {
	q := `SELECT * FROM expenses WHERE deleted_at IS NULL`
	args := []any{}
	n := 1
	if dateFrom != "" {
		q += fmt.Sprintf(` AND expense_date >= $%d`, n)
		args = append(args, dateFrom)
		n++
	}
	if dateTo != "" {
		q += fmt.Sprintf(` AND expense_date <= $%d`, n)
		args = append(args, dateTo)
		n++
	}
	if category != "" {
		q += fmt.Sprintf(` AND category = $%d`, n)
		args = append(args, category)
		n++
	}
	q += ` ORDER BY expense_date DESC, created_at DESC`
	var rows []Expense
	if err := r.db.SelectContext(ctx, &rows, q, args...); err != nil {
		return nil, fmt.Errorf("expenses.List: %w", err)
	}
	return rows, nil
}

func (r *Repository) GetTx(ctx context.Context, tx *sqlx.Tx, id string) (*Expense, error) {
	var e Expense
	err := tx.GetContext(ctx, &e, `SELECT * FROM expenses WHERE id = $1`, id)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("expenses.GetTx: %w", err)
	}
	return &e, nil
}

func (r *Repository) Insert(ctx context.Context, tx *sqlx.Tx, e Expense) error {
	_, err := tx.ExecContext(ctx, `
		INSERT INTO expenses (id, category, amount_mmk, note, expense_date, operator_id, device_id, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) ON CONFLICT (id) DO NOTHING`,
		e.ID, e.Category, e.AmountMmk, nullStr(e.Note), e.ExpenseDate, e.OperatorID, e.DeviceID, e.CreatedAt, e.UpdatedAt)
	if err != nil {
		return fmt.Errorf("expenses.Insert: %w", err)
	}
	return nil
}

func (r *Repository) Update(ctx context.Context, tx *sqlx.Tx, e Expense) error {
	_, err := tx.ExecContext(ctx, `
		UPDATE expenses SET category=$2, amount_mmk=$3, note=$4, expense_date=$5, updated_at=$6, device_id=$7
		WHERE id=$1`, e.ID, e.Category, e.AmountMmk, nullStr(e.Note), e.ExpenseDate, e.UpdatedAt, e.DeviceID)
	if err != nil {
		return fmt.Errorf("expenses.Update: %w", err)
	}
	return nil
}

func (r *Repository) SoftDelete(ctx context.Context, tx *sqlx.Tx, id string, at time.Time) error {
	_, err := tx.ExecContext(ctx, `UPDATE expenses SET deleted_at=$2, updated_at=$2 WHERE id=$1`, id, at)
	if err != nil {
		return fmt.Errorf("expenses.SoftDelete: %w", err)
	}
	return nil
}

func nullStr(v nulljson.String) any {
	if !v.Valid {
		return nil
	}
	return v.String
}

type Service struct{ repo *Repository }

func NewService(repo *Repository) *Service { return &Service{repo: repo} }

type expPayload struct {
	Category    string  `json:"category"`
	AmountMmk   int     `json:"amount_mmk"`
	Note        *string `json:"note"`
	ExpenseDate string  `json:"expense_date"`
	OperatorID  string  `json:"operator_id"`
}

func (s *Service) HandleEvent(ctx context.Context, tx *sqlx.Tx, ev syn.Event) error {
	var p expPayload
	_ = json.Unmarshal(ev.Raw, &p)
	at := timezone.FromUnixMs(ev.CreatedAt)
	existing, err := s.repo.GetTx(ctx, tx, ev.ID)
	if err != nil {
		return err
	}
	row := Expense{
		ID: ev.ID, Category: p.Category, AmountMmk: p.AmountMmk,
		ExpenseDate: p.ExpenseDate, OperatorID: firstNonEmpty(p.OperatorID, ev.OperatorID),
		DeviceID: ev.DeviceID, CreatedAt: at, UpdatedAt: at,
	}
	if p.Note != nil {
		row.Note = nulljson.Text(*p.Note)
	}
	switch ev.EventType {
	case "EXPENSE_CREATED":
		if existing != nil {
			return nil
		}
		return s.repo.Insert(ctx, tx, row)
	case "EXPENSE_UPDATED":
		if existing != nil && !syn.IncomingWins(existing.UpdatedAt.UnixMilli(), ev.CreatedAt) {
			return &syn.ConflictError{WinningPayload: existing}
		}
		if existing == nil {
			return s.repo.Insert(ctx, tx, row)
		}
		return s.repo.Update(ctx, tx, row)
	case "EXPENSE_DELETED":
		return s.repo.SoftDelete(ctx, tx, ev.ID, at)
	}
	return syn.Reject("EVENT_VALIDATION_FAILED", "This change could not be saved.", map[string]any{"field": "event_type"})
}

func (s *Service) List(ctx context.Context, dateFrom, dateTo, category string) ([]Expense, error) {
	rows, err := s.repo.List(ctx, dateFrom, dateTo, category)
	if err != nil {
		return nil, err
	}
	for i := range rows {
		rows[i].CreatedAtMs = rows[i].CreatedAt.UnixMilli()
		rows[i].UpdatedAtMs = rows[i].UpdatedAt.UnixMilli()
	}
	return rows, nil
}

func firstNonEmpty(a, b string) string {
	if a != "" {
		return a
	}
	return b
}
