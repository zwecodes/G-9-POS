package suppliers

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"

	syn "github.com/zwecodes/g9pos/backend/internal/event"
	"github.com/zwecodes/g9pos/backend/pkg/nulljson"
	"github.com/zwecodes/g9pos/backend/pkg/timezone"
)

type Supplier struct {
	ID          string         `db:"id" json:"id"`
	Name        string         `db:"name" json:"name"`
	Phone       nulljson.String `db:"phone" json:"phone"`
	Address     nulljson.String `db:"address" json:"address"`
	Note        nulljson.String `db:"note" json:"note"`
	CreatedAt   time.Time      `db:"created_at" json:"-"`
	UpdatedAt   time.Time      `db:"updated_at" json:"-"`
	DeletedAt   sql.NullTime   `db:"deleted_at" json:"-"`
	DeviceID    string         `db:"device_id" json:"device_id"`
	CreatedAtMs int64          `json:"created_at"`
	UpdatedAtMs int64          `json:"updated_at"`
}

type Order struct {
	ID           string         `db:"id" json:"id"`
	SupplierID   nulljson.String `db:"supplier_id" json:"supplier_id"`
	OrderDate    string          `db:"order_date" json:"order_date"`
	TotalCostMmk int             `db:"total_cost_mmk" json:"total_cost_mmk"`
	Note         nulljson.String `db:"note" json:"note"`
	Status       string         `db:"status" json:"status"`
	ReceivedAt   sql.NullTime   `db:"received_at" json:"-"`
	OperatorID   string         `db:"operator_id" json:"operator_id"`
	DeviceID     string         `db:"device_id" json:"device_id"`
	CreatedAt    time.Time      `db:"created_at" json:"-"`
	UpdatedAt    time.Time      `db:"updated_at" json:"-"`
	Items        []OrderItem    `json:"items,omitempty"`
}

type OrderItem struct {
	ID             string    `db:"id" json:"id"`
	OrderID        string    `db:"order_id" json:"order_id"`
	ProductID      string    `db:"product_id" json:"product_id"`
	Quantity       int       `db:"quantity" json:"quantity"`
	CostPerUnitMmk int       `db:"cost_per_unit_mmk" json:"cost_per_unit_mmk"`
	SubtotalMmk    int       `db:"subtotal_mmk" json:"subtotal_mmk"`
	CreatedAt      time.Time `db:"created_at" json:"-"`
}

type Repository struct{ db *sqlx.DB }

func NewRepository(db *sqlx.DB) *Repository { return &Repository{db: db} }

func (r *Repository) ListSuppliers(ctx context.Context) ([]Supplier, error) {
	var rows []Supplier
	err := r.db.SelectContext(ctx, &rows, `SELECT * FROM suppliers WHERE deleted_at IS NULL ORDER BY name`)
	if err != nil {
		return nil, fmt.Errorf("suppliers.List: %w", err)
	}
	return rows, nil
}

func (r *Repository) ListOrders(ctx context.Context) ([]Order, error) {
	var rows []Order
	err := r.db.SelectContext(ctx, &rows, `SELECT * FROM supplier_orders ORDER BY created_at DESC`)
	if err != nil {
		return nil, fmt.Errorf("suppliers.ListOrders: %w", err)
	}
	return rows, nil
}

func (r *Repository) GetSupplierTx(ctx context.Context, tx *sqlx.Tx, id string) (*Supplier, error) {
	var s Supplier
	err := tx.GetContext(ctx, &s, `SELECT * FROM suppliers WHERE id=$1`, id)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("suppliers.GetSupplierTx: %w", err)
	}
	return &s, nil
}

func (r *Repository) GetOrderTx(ctx context.Context, tx *sqlx.Tx, id string) (*Order, error) {
	var o Order
	err := tx.GetContext(ctx, &o, `SELECT * FROM supplier_orders WHERE id=$1`, id)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("suppliers.GetOrderTx: %w", err)
	}
	return &o, nil
}

func (r *Repository) InsertSupplier(ctx context.Context, tx *sqlx.Tx, s Supplier) error {
	_, err := tx.ExecContext(ctx, `
		INSERT INTO suppliers (id, name, phone, address, note, created_at, updated_at, device_id)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT (id) DO NOTHING`,
		s.ID, s.Name, nullStr(s.Phone), nullStr(s.Address), nullStr(s.Note), s.CreatedAt, s.UpdatedAt, s.DeviceID)
	return wrap(err, "InsertSupplier")
}

func (r *Repository) UpdateSupplier(ctx context.Context, tx *sqlx.Tx, s Supplier) error {
	_, err := tx.ExecContext(ctx, `
		UPDATE suppliers SET name=$2, phone=$3, address=$4, note=$5, updated_at=$6, device_id=$7 WHERE id=$1`,
		s.ID, s.Name, nullStr(s.Phone), nullStr(s.Address), nullStr(s.Note), s.UpdatedAt, s.DeviceID)
	return wrap(err, "UpdateSupplier")
}

func (r *Repository) SoftDeleteSupplier(ctx context.Context, tx *sqlx.Tx, id string, at time.Time) error {
	_, err := tx.ExecContext(ctx, `UPDATE suppliers SET deleted_at=$2, updated_at=$2 WHERE id=$1`, id, at)
	return wrap(err, "SoftDeleteSupplier")
}

func (r *Repository) InsertOrder(ctx context.Context, tx *sqlx.Tx, o Order) error {
	_, err := tx.ExecContext(ctx, `
		INSERT INTO supplier_orders (id, supplier_id, order_date, total_cost_mmk, note, status, operator_id, device_id, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) ON CONFLICT (id) DO NOTHING`,
		o.ID, nullStr(o.SupplierID), o.OrderDate, o.TotalCostMmk, nullStr(o.Note), o.Status, o.OperatorID, o.DeviceID, o.CreatedAt, o.UpdatedAt)
	return wrap(err, "InsertOrder")
}

func (r *Repository) InsertOrderItem(ctx context.Context, tx *sqlx.Tx, it OrderItem) error {
	_, err := tx.ExecContext(ctx, `
		INSERT INTO supplier_order_items (id, order_id, product_id, quantity, cost_per_unit_mmk, subtotal_mmk, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7) ON CONFLICT (id) DO NOTHING`,
		it.ID, it.OrderID, it.ProductID, it.Quantity, it.CostPerUnitMmk, it.SubtotalMmk, it.CreatedAt)
	return wrap(err, "InsertOrderItem")
}

func (r *Repository) MarkReceived(ctx context.Context, tx *sqlx.Tx, id string, at time.Time) error {
	_, err := tx.ExecContext(ctx, `
		UPDATE supplier_orders SET status='received', received_at=$2, updated_at=$2 WHERE id=$1`, id, at)
	return wrap(err, "MarkReceived")
}

func (r *Repository) UpdateOrder(ctx context.Context, tx *sqlx.Tx, o Order) error {
	_, err := tx.ExecContext(ctx, `
		UPDATE supplier_orders SET supplier_id=$2, order_date=$3, total_cost_mmk=$4, note=$5, status=$6, updated_at=$7, device_id=$8
		WHERE id=$1`,
		o.ID, nullStr(o.SupplierID), o.OrderDate, o.TotalCostMmk, nullStr(o.Note), o.Status, o.UpdatedAt, o.DeviceID)
	return wrap(err, "UpdateOrder")
}

func wrap(err error, op string) error {
	if err == nil {
		return nil
	}
	return fmt.Errorf("suppliers.%s: %w", op, err)
}

func nullStr(v nulljson.String) any {
	if !v.Valid {
		return nil
	}
	return v.String
}

type Service struct{ repo *Repository }

func NewService(repo *Repository) *Service { return &Service{repo: repo} }

type supplierPayload struct {
	Name    string  `json:"name"`
	Phone   *string `json:"phone"`
	Address *string `json:"address"`
	Note    *string `json:"note"`
}

type orderPayload struct {
	SupplierID   *string `json:"supplier_id"`
	OrderDate    string  `json:"order_date"`
	TotalCostMmk int     `json:"total_cost_mmk"`
	Note         *string `json:"note"`
	Status       string  `json:"status"`
	OperatorID   string  `json:"operator_id"`
	Items        []struct {
		ID             string `json:"id"`
		ProductID      string `json:"product_id"`
		Quantity       int    `json:"quantity"`
		CostPerUnitMmk int    `json:"cost_per_unit_mmk"`
		SubtotalMmk    int    `json:"subtotal_mmk"`
	} `json:"items"`
}

func (s *Service) HandleEvent(ctx context.Context, tx *sqlx.Tx, ev syn.Event) error {
	at := timezone.FromUnixMs(ev.CreatedAt)
	switch ev.EventType {
	case "SUPPLIER_CREATED", "SUPPLIER_UPDATED", "SUPPLIER_DELETED":
		return s.handleSupplier(ctx, tx, ev, at)
	case "SUPPLIER_ORDER_CREATED", "SUPPLIER_ORDER_UPDATED", "SUPPLIER_ORDER_RECEIVED":
		return s.handleOrder(ctx, tx, ev, at)
	}
	return syn.Reject("EVENT_VALIDATION_FAILED", "This change could not be saved.", map[string]any{"field": "event_type"})
}

func (s *Service) handleSupplier(ctx context.Context, tx *sqlx.Tx, ev syn.Event, at time.Time) error {
	var p supplierPayload
	_ = json.Unmarshal(ev.Raw, &p)
	existing, err := s.repo.GetSupplierTx(ctx, tx, ev.ID)
	if err != nil {
		return err
	}
	row := Supplier{ID: ev.ID, Name: p.Name, DeviceID: ev.DeviceID, CreatedAt: at, UpdatedAt: at}
	if p.Phone != nil {
		row.Phone = nulljson.Text(*p.Phone)
	}
	if p.Address != nil {
		row.Address = nulljson.Text(*p.Address)
	}
	if p.Note != nil {
		row.Note = nulljson.Text(*p.Note)
	}
	switch ev.EventType {
	case "SUPPLIER_CREATED":
		if existing != nil {
			return nil
		}
		return s.repo.InsertSupplier(ctx, tx, row)
	case "SUPPLIER_UPDATED":
		if existing != nil && !syn.IncomingWins(existing.UpdatedAt.UnixMilli(), ev.CreatedAt) {
			return &syn.ConflictError{WinningPayload: existing}
		}
		if existing == nil {
			return s.repo.InsertSupplier(ctx, tx, row)
		}
		return s.repo.UpdateSupplier(ctx, tx, row)
	case "SUPPLIER_DELETED":
		return s.repo.SoftDeleteSupplier(ctx, tx, ev.ID, at)
	}
	return nil
}

func (s *Service) handleOrder(ctx context.Context, tx *sqlx.Tx, ev syn.Event, at time.Time) error {
	var p orderPayload
	_ = json.Unmarshal(ev.Raw, &p)
	existing, err := s.repo.GetOrderTx(ctx, tx, ev.ID)
	if err != nil {
		return err
	}
	if ev.EventType == "SUPPLIER_ORDER_RECEIVED" {
		id := ev.ID
		if ev.ReferenceID != nil && *ev.ReferenceID != "" {
			id = *ev.ReferenceID
		}
		return s.repo.MarkReceived(ctx, tx, id, at)
	}
	status := p.Status
	if status == "" {
		status = "pending"
	}
	row := Order{
		ID: ev.ID, OrderDate: p.OrderDate, TotalCostMmk: p.TotalCostMmk,
		Status: status, OperatorID: firstNonEmpty(p.OperatorID, ev.OperatorID),
		DeviceID: ev.DeviceID, CreatedAt: at, UpdatedAt: at,
	}
	if p.SupplierID != nil {
		row.SupplierID = nulljson.Text(*p.SupplierID)
	}
	if p.Note != nil {
		row.Note = nulljson.Text(*p.Note)
	}
	if existing != nil && ev.EventType == "SUPPLIER_ORDER_CREATED" {
		return nil
	}
	if existing != nil && ev.EventType == "SUPPLIER_ORDER_UPDATED" {
		if err := s.repo.UpdateOrder(ctx, tx, row); err != nil {
			return err
		}
	} else if err := s.repo.InsertOrder(ctx, tx, row); err != nil {
		return err
	}
	for _, it := range p.Items {
		id := it.ID
		if id == "" {
			id = uuid.NewString()
		}
		if err := s.repo.InsertOrderItem(ctx, tx, OrderItem{
			ID: id, OrderID: ev.ID, ProductID: it.ProductID,
			Quantity: it.Quantity, CostPerUnitMmk: it.CostPerUnitMmk,
			SubtotalMmk: it.SubtotalMmk, CreatedAt: at,
		}); err != nil {
			return err
		}
	}
	return nil
}

func (s *Service) ListSuppliers(ctx context.Context) ([]Supplier, error) {
	rows, err := s.repo.ListSuppliers(ctx)
	if err != nil {
		return nil, err
	}
	for i := range rows {
		rows[i].CreatedAtMs = rows[i].CreatedAt.UnixMilli()
		rows[i].UpdatedAtMs = rows[i].UpdatedAt.UnixMilli()
	}
	return rows, nil
}

func (s *Service) ListOrders(ctx context.Context) ([]Order, error) {
	return s.repo.ListOrders(ctx)
}

func firstNonEmpty(a, b string) string {
	if a != "" {
		return a
	}
	return b
}
