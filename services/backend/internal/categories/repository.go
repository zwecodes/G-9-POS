package categories

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"
)

type Category struct {
	ID        string       `db:"id" json:"id"`
	Name      string       `db:"name" json:"name"`
	SortOrder int          `db:"sort_order" json:"sort_order"`
	CreatedAt time.Time    `db:"created_at" json:"-"`
	UpdatedAt time.Time    `db:"updated_at" json:"-"`
	DeletedAt sql.NullTime `db:"deleted_at" json:"-"`
	DeviceID  string       `db:"device_id" json:"device_id"`
	CreatedAtMs int64      `json:"created_at"`
	UpdatedAtMs int64      `json:"updated_at"`
	DeletedAtMs *int64     `json:"deleted_at,omitempty"`
}

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository { return &Repository{db: db} }

func (r *Repository) List(ctx context.Context, includeDeleted bool) ([]Category, error) {
	q := `SELECT id, name, sort_order, created_at, updated_at, deleted_at, device_id FROM categories`
	if !includeDeleted {
		q += ` WHERE deleted_at IS NULL`
	}
	q += ` ORDER BY sort_order ASC, name ASC`
	var rows []Category
	if err := r.db.SelectContext(ctx, &rows, q); err != nil {
		return nil, fmt.Errorf("categories.List: %w", err)
	}
	return rows, nil
}

func (r *Repository) Get(ctx context.Context, tx *sqlx.Tx, id string) (*Category, error) {
	var c Category
	err := tx.GetContext(ctx, &c, `
		SELECT id, name, sort_order, created_at, updated_at, deleted_at, device_id
		FROM categories WHERE id = $1`, id)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("categories.Get: %w", err)
	}
	return &c, nil
}

func (r *Repository) FindByName(ctx context.Context, tx *sqlx.Tx, name string) (*Category, error) {
	var c Category
	err := tx.GetContext(ctx, &c, `
		SELECT id, name, sort_order, created_at, updated_at, deleted_at, device_id
		FROM categories WHERE name = $1 AND deleted_at IS NULL`, name)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("categories.FindByName: %w", err)
	}
	return &c, nil
}

func (r *Repository) Insert(ctx context.Context, tx *sqlx.Tx, c Category) error {
	_, err := tx.ExecContext(ctx, `
		INSERT INTO categories (id, name, sort_order, created_at, updated_at, device_id)
		VALUES ($1,$2,$3,$4,$5,$6)
		ON CONFLICT (id) DO NOTHING`,
		c.ID, c.Name, c.SortOrder, c.CreatedAt, c.UpdatedAt, c.DeviceID)
	if err != nil {
		return fmt.Errorf("categories.Insert: %w", err)
	}
	return nil
}

func (r *Repository) Update(ctx context.Context, tx *sqlx.Tx, c Category) error {
	_, err := tx.ExecContext(ctx, `
		UPDATE categories SET name=$2, sort_order=$3, updated_at=$4, device_id=$5, deleted_at=NULL
		WHERE id=$1`, c.ID, c.Name, c.SortOrder, c.UpdatedAt, c.DeviceID)
	if err != nil {
		return fmt.Errorf("categories.Update: %w", err)
	}
	return nil
}

func (r *Repository) SoftDelete(ctx context.Context, tx *sqlx.Tx, id string, at time.Time, deviceID string) error {
	_, err := tx.ExecContext(ctx, `
		UPDATE categories SET deleted_at=$2, updated_at=$2, device_id=$3 WHERE id=$1`,
		id, at, deviceID)
	if err != nil {
		return fmt.Errorf("categories.SoftDelete: %w", err)
	}
	return nil
}

func (r *Repository) CountActiveProducts(ctx context.Context, tx *sqlx.Tx, categoryID string) (int, error) {
	var n int
	err := tx.GetContext(ctx, &n, `
		SELECT COUNT(*) FROM products WHERE category_id = $1 AND deleted_at IS NULL`, categoryID)
	if err != nil {
		return 0, fmt.Errorf("categories.CountActiveProducts: %w", err)
	}
	return n, nil
}
