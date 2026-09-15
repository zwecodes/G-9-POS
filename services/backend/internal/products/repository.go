package products

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"

	"github.com/zwecodes/g9pos/backend/pkg/nulljson"
)

type Product struct {
	ID                string         `db:"id" json:"id"`
	CategoryID        nulljson.String `db:"category_id" json:"category_id"`
	Name              string          `db:"name" json:"name"`
	Barcode           nulljson.String `db:"barcode" json:"barcode"`
	PriceMmk          int             `db:"price_mmk" json:"price_mmk"`
	CostPriceMmk      nulljson.Int64  `db:"cost_price_mmk" json:"cost_price_mmk"`
	Unit              string          `db:"unit" json:"unit"`
	LowStockThreshold int             `db:"low_stock_threshold" json:"low_stock_threshold"`
	ImagePath         nulljson.String `db:"image_path" json:"image_path"`
	IsActive          bool           `db:"is_active" json:"is_active"`
	StockNegative     bool           `db:"stock_negative" json:"stock_negative"`
	CreatedAt         time.Time      `db:"created_at" json:"-"`
	UpdatedAt         time.Time      `db:"updated_at" json:"-"`
	DeletedAt         sql.NullTime   `db:"deleted_at" json:"-"`
	DeviceID          string         `db:"device_id" json:"device_id"`
	ComputedStock     int            `db:"computed_stock" json:"computed_stock"`
	CreatedAtMs       int64          `json:"created_at"`
	UpdatedAtMs       int64          `json:"updated_at"`
}

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository { return &Repository{db: db} }

func (r *Repository) List(ctx context.Context, categoryID, q string, active *bool, lowStockOnly bool) ([]Product, error) {
	query := `
		SELECT p.id, p.category_id, p.name, p.barcode, p.price_mmk, p.cost_price_mmk, p.unit,
		       p.low_stock_threshold, p.image_path, p.is_active, p.stock_negative,
		       p.created_at, p.updated_at, p.deleted_at, p.device_id,
		       COALESCE((SELECT SUM(quantity_delta) FROM inventory_events e WHERE e.product_id = p.id), 0) AS computed_stock
		FROM products p
		WHERE p.deleted_at IS NULL`
	args := []any{}
	n := 1
	if categoryID != "" {
		query += fmt.Sprintf(` AND p.category_id = $%d`, n)
		args = append(args, categoryID)
		n++
	}
	if active != nil {
		query += fmt.Sprintf(` AND p.is_active = $%d`, n)
		args = append(args, *active)
		n++
	}
	if q != "" {
		query += fmt.Sprintf(` AND (p.name ILIKE $%d OR COALESCE(p.barcode,'') ILIKE $%d)`, n, n)
		args = append(args, "%"+q+"%")
		n++
	}
	query += ` ORDER BY p.name ASC`
	var rows []Product
	if err := r.db.SelectContext(ctx, &rows, query, args...); err != nil {
		return nil, fmt.Errorf("products.List: %w", err)
	}
	if lowStockOnly {
		filtered := rows[:0]
		for _, p := range rows {
			if p.ComputedStock <= p.LowStockThreshold {
				filtered = append(filtered, p)
			}
		}
		rows = filtered
	}
	return rows, nil
}

func (r *Repository) Get(ctx context.Context, id string) (*Product, error) {
	var p Product
	err := r.db.GetContext(ctx, &p, `
		SELECT p.id, p.category_id, p.name, p.barcode, p.price_mmk, p.cost_price_mmk, p.unit,
		       p.low_stock_threshold, p.image_path, p.is_active, p.stock_negative,
		       p.created_at, p.updated_at, p.deleted_at, p.device_id,
		       COALESCE((SELECT SUM(quantity_delta) FROM inventory_events e WHERE e.product_id = p.id), 0) AS computed_stock
		FROM products p WHERE p.id = $1 AND p.deleted_at IS NULL`, id)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("products.Get: %w", err)
	}
	return &p, nil
}

func (r *Repository) GetTx(ctx context.Context, tx *sqlx.Tx, id string) (*Product, error) {
	var p Product
	err := tx.GetContext(ctx, &p, `
		SELECT id, category_id, name, barcode, price_mmk, cost_price_mmk, unit,
		       low_stock_threshold, image_path, is_active, stock_negative,
		       created_at, updated_at, deleted_at, device_id, 0 AS computed_stock
		FROM products WHERE id = $1`, id)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("products.GetTx: %w", err)
	}
	return &p, nil
}

func (r *Repository) FindActiveByBarcodeTx(ctx context.Context, tx *sqlx.Tx, barcode string) (*Product, error) {
	var p Product
	err := tx.GetContext(ctx, &p, `
		SELECT id, category_id, name, barcode, price_mmk, cost_price_mmk, unit,
		       low_stock_threshold, image_path, is_active, stock_negative,
		       created_at, updated_at, deleted_at, device_id, 0 AS computed_stock
		FROM products WHERE barcode = $1 AND deleted_at IS NULL`, barcode)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("products.FindActiveByBarcodeTx: %w", err)
	}
	return &p, nil
}

func (r *Repository) Insert(ctx context.Context, tx *sqlx.Tx, p Product) error {
	_, err := tx.ExecContext(ctx, `
		INSERT INTO products (id, category_id, name, barcode, price_mmk, cost_price_mmk, unit,
			low_stock_threshold, image_path, is_active, stock_negative, created_at, updated_at, device_id)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
		ON CONFLICT (id) DO NOTHING`,
		p.ID, nullStr(p.CategoryID), p.Name, nullStr(p.Barcode), p.PriceMmk, nullInt(p.CostPriceMmk),
		p.Unit, p.LowStockThreshold, nullStr(p.ImagePath), p.IsActive, p.StockNegative,
		p.CreatedAt, p.UpdatedAt, p.DeviceID)
	if err != nil {
		return fmt.Errorf("products.Insert: %w", err)
	}
	return nil
}

func (r *Repository) Update(ctx context.Context, tx *sqlx.Tx, p Product) error {
	_, err := tx.ExecContext(ctx, `
		UPDATE products SET category_id=$2, name=$3, barcode=$4, price_mmk=$5, cost_price_mmk=$6,
			unit=$7, low_stock_threshold=$8, image_path=$9, is_active=$10, updated_at=$11, device_id=$12
		WHERE id=$1`,
		p.ID, nullStr(p.CategoryID), p.Name, nullStr(p.Barcode), p.PriceMmk, nullInt(p.CostPriceMmk),
		p.Unit, p.LowStockThreshold, nullStr(p.ImagePath), p.IsActive, p.UpdatedAt, p.DeviceID)
	if err != nil {
		return fmt.Errorf("products.Update: %w", err)
	}
	return nil
}

func (r *Repository) SoftDelete(ctx context.Context, tx *sqlx.Tx, id string, at time.Time, deviceID string) error {
	_, err := tx.ExecContext(ctx, `
		UPDATE products SET deleted_at=$2, updated_at=$2, device_id=$3 WHERE id=$1`, id, at, deviceID)
	if err != nil {
		return fmt.Errorf("products.SoftDelete: %w", err)
	}
	return nil
}

func (r *Repository) SetStockNegative(ctx context.Context, tx *sqlx.Tx, id string, negative bool) error {
	_, err := tx.ExecContext(ctx, `UPDATE products SET stock_negative=$2 WHERE id=$1`, id, negative)
	if err != nil {
		return fmt.Errorf("products.SetStockNegative: %w", err)
	}
	return nil
}

func nullStr(v nulljson.String) any {
	if !v.Valid {
		return nil
	}
	return v.String
}

func nullInt(v nulljson.Int64) any {
	if !v.Valid {
		return nil
	}
	return v.Int64
}
