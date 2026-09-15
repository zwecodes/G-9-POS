package sync

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"
)

type PullUser struct {
	ID          string         `db:"id" json:"id"`
	Name        string         `db:"name" json:"name"`
	Username    sql.NullString `db:"username" json:"username"`
	PIN         string         `db:"pin" json:"pin"`
	Role        string         `db:"role" json:"role"`
	CreatedAt   time.Time      `db:"created_at" json:"-"`
	UpdatedAt   time.Time      `db:"updated_at" json:"-"`
	DeletedAt   sql.NullTime   `db:"deleted_at" json:"-"`
	CreatedAtMs int64          `json:"created_at"`
	UpdatedAtMs int64          `json:"updated_at"`
	DeletedAtMs *int64         `json:"deleted_at,omitempty"`
}

type PullPayload struct {
	Users              []map[string]any `json:"users"`
	Categories         []map[string]any `json:"categories"`
	Products           []map[string]any `json:"products"`
	Suppliers          []map[string]any `json:"suppliers"`
	InventoryEvents    []map[string]any `json:"inventory_events"`
	Sales              []map[string]any `json:"sales"`
	SaleItems          []map[string]any `json:"sale_items"`
	Expenses           []map[string]any `json:"expenses"`
	SupplierOrders     []map[string]any `json:"supplier_orders"`
	SupplierOrderItems []map[string]any `json:"supplier_order_items"`
	SaleServerReceived []map[string]any `json:"sale_server_received"`
}

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository { return &Repository{db: db} }

func (r *Repository) BeginTx(ctx context.Context) (*sqlx.Tx, error) {
	return r.db.BeginTxx(ctx, nil)
}

func (r *Repository) Pull(ctx context.Context, deviceID string, since time.Time, firstRun bool) (PullPayload, error) {
	out := PullPayload{
		Users:              []map[string]any{},
		Categories:         []map[string]any{},
		Products:           []map[string]any{},
		Suppliers:          []map[string]any{},
		InventoryEvents:    []map[string]any{},
		Sales:              []map[string]any{},
		SaleItems:          []map[string]any{},
		Expenses:           []map[string]any{},
		SupplierOrders:     []map[string]any{},
		SupplierOrderItems: []map[string]any{},
		SaleServerReceived: []map[string]any{},
	}

	historyStart := since
	if firstRun {
		historyStart = time.Now().UTC().Add(-90 * 24 * time.Hour)
	}

	users, err := r.pullUsers(ctx, since, firstRun)
	if err != nil {
		return out, err
	}
	out.Users = users

	cats, err := r.pullMaps(ctx, `
		SELECT id, name, sort_order, created_at, updated_at, deleted_at, device_id
		FROM categories
		WHERE ($1 OR updated_at > $2) AND ($1 OR device_id <> $3::uuid)
		ORDER BY updated_at ASC LIMIT 200`, firstRun, since, deviceID)
	if err != nil {
		return out, fmt.Errorf("sync.Pull categories: %w", err)
	}
	out.Categories = cats

	prods, err := r.pullMaps(ctx, `
		SELECT id, category_id, name, barcode, price_mmk, cost_price_mmk, unit,
		       low_stock_threshold, image_path, is_active, stock_negative,
		       created_at, updated_at, deleted_at, device_id
		FROM products
		WHERE ($1 OR updated_at > $2) AND ($1 OR device_id <> $3::uuid)
		ORDER BY updated_at ASC LIMIT 200`, firstRun, since, deviceID)
	if err != nil {
		return out, fmt.Errorf("sync.Pull products: %w", err)
	}
	out.Products = prods

	sups, err := r.pullMaps(ctx, `
		SELECT id, name, phone, address, note, created_at, updated_at, deleted_at, device_id
		FROM suppliers
		WHERE ($1 OR updated_at > $2) AND ($1 OR device_id <> $3::uuid)
		ORDER BY updated_at ASC LIMIT 200`, firstRun, since, deviceID)
	if err != nil {
		return out, fmt.Errorf("sync.Pull suppliers: %w", err)
	}
	out.Suppliers = sups

	inv, err := r.pullMaps(ctx, `
		SELECT id, product_id, event_type, quantity_delta, reference_id, reference_type,
		       note, operator_id, device_id, created_at, server_received_at
		FROM inventory_events
		WHERE COALESCE(server_received_at, created_at) > $1
		  AND device_id <> $2::uuid
		ORDER BY created_at ASC LIMIT 200`, historyStart, deviceID)
	if err != nil {
		return out, fmt.Errorf("sync.Pull inventory: %w", err)
	}
	out.InventoryEvents = inv

	sales, err := r.pullMaps(ctx, `
		SELECT id, sale_number, operator_id, device_id, payment_method, total_amount_mmk,
		       discount_amount_mmk, note, status, voided_at, voided_by, void_reason,
		       created_at, server_received_at
		FROM sales
		WHERE created_at > $1 AND device_id <> $2::uuid
		ORDER BY created_at ASC LIMIT 200`, historyStart, deviceID)
	if err != nil {
		return out, fmt.Errorf("sync.Pull sales: %w", err)
	}
	out.Sales = sales

	items, err := r.pullMaps(ctx, `
		SELECT si.id, si.sale_id, si.product_id, si.product_name_snapshot, si.price_snapshot_mmk,
		       si.quantity, si.subtotal_mmk, si.created_at
		FROM sale_items si
		JOIN sales s ON s.id = si.sale_id
		WHERE s.created_at > $1 AND s.device_id <> $2::uuid
		ORDER BY si.created_at ASC LIMIT 200`, historyStart, deviceID)
	if err != nil {
		return out, fmt.Errorf("sync.Pull sale_items: %w", err)
	}
	out.SaleItems = items

	exps, err := r.pullMaps(ctx, `
		SELECT id, category, amount_mmk, note, expense_date, operator_id, device_id,
		       created_at, updated_at, deleted_at
		FROM expenses
		WHERE ($1::timestamptz IS NULL OR updated_at > $1)
		  AND created_at > $2
		  AND device_id <> $3::uuid
		ORDER BY updated_at ASC LIMIT 200`, nullableTime(since, firstRun), historyStart, deviceID)
	if err != nil {
		return out, fmt.Errorf("sync.Pull expenses: %w", err)
	}
	out.Expenses = exps

	orders, err := r.pullMaps(ctx, `
		SELECT id, supplier_id, order_date, total_cost_mmk, note, status, received_at,
		       operator_id, device_id, created_at, updated_at
		FROM supplier_orders
		WHERE updated_at > $1 AND device_id <> $2::uuid
		ORDER BY updated_at ASC LIMIT 200`, historyStart, deviceID)
	if err != nil {
		return out, fmt.Errorf("sync.Pull orders: %w", err)
	}
	out.SupplierOrders = orders

	orderItems, err := r.pullMaps(ctx, `
		SELECT soi.id, soi.order_id, soi.product_id, soi.quantity, soi.cost_per_unit_mmk,
		       soi.subtotal_mmk, soi.created_at
		FROM supplier_order_items soi
		JOIN supplier_orders so ON so.id = soi.order_id
		WHERE so.updated_at > $1 AND so.device_id <> $2::uuid
		ORDER BY soi.created_at ASC LIMIT 200`, historyStart, deviceID)
	if err != nil {
		return out, fmt.Errorf("sync.Pull order_items: %w", err)
	}
	out.SupplierOrderItems = orderItems

	stamps, err := r.pullMaps(ctx, `
		SELECT id, server_received_at
		FROM sales
		WHERE device_id = $1::uuid AND server_received_at IS NOT NULL AND server_received_at > $2
		ORDER BY server_received_at ASC LIMIT 200`, deviceID, since)
	if err != nil {
		return out, fmt.Errorf("sync.Pull sale stamps: %w", err)
	}
	out.SaleServerReceived = stamps

	return out, nil
}

func nullableTime(since time.Time, firstRun bool) any {
	if firstRun {
		return nil
	}
	return since
}

func (r *Repository) pullUsers(ctx context.Context, since time.Time, firstRun bool) ([]map[string]any, error) {
	var rows []PullUser
	q := `
		SELECT id, name, username, pin, role, created_at, updated_at, deleted_at
		FROM users`
	var err error
	if firstRun {
		err = r.db.SelectContext(ctx, &rows, q+` ORDER BY created_at ASC LIMIT 200`)
	} else {
		err = r.db.SelectContext(ctx, &rows, q+` WHERE updated_at > $1 ORDER BY updated_at ASC LIMIT 200`, since)
	}
	if err != nil {
		return nil, fmt.Errorf("sync.Pull users: %w", err)
	}
	out := make([]map[string]any, 0, len(rows))
	for _, u := range rows {
		m := map[string]any{
			"id":         u.ID,
			"name":       u.Name,
			"pin":        u.PIN,
			"role":       u.Role,
			"created_at": u.CreatedAt.UnixMilli(),
			"updated_at": u.UpdatedAt.UnixMilli(),
		}
		if u.Username.Valid {
			m["username"] = u.Username.String
		}
		if u.DeletedAt.Valid {
			ms := u.DeletedAt.Time.UnixMilli()
			m["deleted_at"] = ms
		}
		out = append(out, m)
	}
	return out, nil
}

func (r *Repository) pullMaps(ctx context.Context, query string, args ...any) ([]map[string]any, error) {
	rows, err := r.db.QueryxContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		m := map[string]any{}
		if err := rows.MapScan(m); err != nil {
			return nil, err
		}
		out = append(out, convertTimes(m))
	}
	return out, rows.Err()
}

func convertTimes(m map[string]any) map[string]any {
	for k, v := range m {
		switch t := v.(type) {
		case time.Time:
			m[k] = t.UnixMilli()
		case []byte:
			m[k] = string(t)
		}
	}
	return m
}
