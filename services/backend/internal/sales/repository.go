package sales

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

type Sale struct {
	ID                string         `db:"id" json:"id"`
	SaleNumber        string         `db:"sale_number" json:"sale_number"`
	OperatorID        string         `db:"operator_id" json:"operator_id"`
	DeviceID          string         `db:"device_id" json:"device_id"`
	PaymentMethod     string         `db:"payment_method" json:"payment_method"`
	TotalAmountMmk    int            `db:"total_amount_mmk" json:"total_amount_mmk"`
	DiscountAmountMmk int            `db:"discount_amount_mmk" json:"discount_amount_mmk"`
	Note              nulljson.String `db:"note" json:"note"`
	Status            string          `db:"status" json:"status"`
	VoidedAt          sql.NullTime    `db:"voided_at" json:"-"`
	VoidedBy          nulljson.String `db:"voided_by" json:"voided_by"`
	VoidReason        nulljson.String `db:"void_reason" json:"void_reason"`
	CreatedAt         time.Time      `db:"created_at" json:"-"`
	ServerReceivedAt  sql.NullTime   `db:"server_received_at" json:"-"`
	CreatedAtMs       int64          `json:"created_at"`
	ServerReceivedAtMs *int64        `json:"server_received_at"`
	Items             []SaleItem     `json:"sale_items,omitempty"`
}

type SaleItem struct {
	ID                  string    `db:"id" json:"id"`
	SaleID              string    `db:"sale_id" json:"sale_id"`
	ProductID           string    `db:"product_id" json:"product_id"`
	ProductNameSnapshot string    `db:"product_name_snapshot" json:"product_name_snapshot"`
	PriceSnapshotMmk    int       `db:"price_snapshot_mmk" json:"price_snapshot_mmk"`
	Quantity            int       `db:"quantity" json:"quantity"`
	SubtotalMmk         int       `db:"subtotal_mmk" json:"subtotal_mmk"`
	CreatedAt           time.Time `db:"created_at" json:"-"`
}

type Repository struct{ db *sqlx.DB }

func NewRepository(db *sqlx.DB) *Repository { return &Repository{db: db} }

func (r *Repository) GetTx(ctx context.Context, tx *sqlx.Tx, id string) (*Sale, error) {
	var s Sale
	err := tx.GetContext(ctx, &s, `SELECT * FROM sales WHERE id = $1`, id)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("sales.GetTx: %w", err)
	}
	return &s, nil
}

func (r *Repository) Insert(ctx context.Context, tx *sqlx.Tx, s Sale) error {
	_, err := tx.ExecContext(ctx, `
		INSERT INTO sales (id, sale_number, operator_id, device_id, payment_method,
			total_amount_mmk, discount_amount_mmk, note, status, created_at, server_received_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
		ON CONFLICT (id) DO NOTHING`,
		s.ID, s.SaleNumber, s.OperatorID, s.DeviceID, s.PaymentMethod,
		s.TotalAmountMmk, s.DiscountAmountMmk, nullStr(s.Note), s.Status, s.CreatedAt, s.ServerReceivedAt)
	if err != nil {
		return fmt.Errorf("sales.Insert: %w", err)
	}
	return nil
}

func (r *Repository) InsertItem(ctx context.Context, tx *sqlx.Tx, it SaleItem) error {
	_, err := tx.ExecContext(ctx, `
		INSERT INTO sale_items (id, sale_id, product_id, product_name_snapshot, price_snapshot_mmk, quantity, subtotal_mmk, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		ON CONFLICT (id) DO NOTHING`,
		it.ID, it.SaleID, it.ProductID, it.ProductNameSnapshot, it.PriceSnapshotMmk, it.Quantity, it.SubtotalMmk, it.CreatedAt)
	if err != nil {
		return fmt.Errorf("sales.InsertItem: %w", err)
	}
	return nil
}

func (r *Repository) Void(ctx context.Context, tx *sqlx.Tx, id string, at time.Time, by, reason string) error {
	_, err := tx.ExecContext(ctx, `
		UPDATE sales SET status='voided', voided_at=$2, voided_by=$3, void_reason=$4 WHERE id=$1`,
		id, at, by, reason)
	if err != nil {
		return fmt.Errorf("sales.Void: %w", err)
	}
	return nil
}

func (r *Repository) List(ctx context.Context, operatorID, status, dateFrom, dateTo, productID string) ([]Sale, error) {
	q := `SELECT DISTINCT s.id, s.sale_number, s.operator_id, s.device_id, s.payment_method,
		s.total_amount_mmk, s.discount_amount_mmk, s.note, s.status, s.voided_at, s.voided_by,
		s.void_reason, s.created_at, s.server_received_at
		FROM sales s`
	if productID != "" {
		q += ` JOIN sale_items si ON si.sale_id = s.id`
	}
	q += ` WHERE 1=1`
	args := []any{}
	n := 1
	if operatorID != "" {
		q += fmt.Sprintf(` AND s.operator_id = $%d`, n)
		args = append(args, operatorID)
		n++
	}
	if status != "" {
		q += fmt.Sprintf(` AND s.status = $%d`, n)
		args = append(args, status)
		n++
	}
	if productID != "" {
		q += fmt.Sprintf(` AND si.product_id = $%d`, n)
		args = append(args, productID)
		n++
	}
	if dateFrom != "" {
		start, _, err := timezone.ShopDayBounds(dateFrom)
		if err != nil {
			return nil, fmt.Errorf("sales.List date_from: %w", err)
		}
		q += fmt.Sprintf(` AND s.created_at >= $%d`, n)
		args = append(args, start.UTC())
		n++
	}
	if dateTo != "" {
		_, end, err := timezone.ShopDayBounds(dateTo)
		if err != nil {
			return nil, fmt.Errorf("sales.List date_to: %w", err)
		}
		q += fmt.Sprintf(` AND s.created_at < $%d`, n)
		args = append(args, end.UTC())
		n++
	}
	q += ` ORDER BY s.created_at DESC LIMIT 200`
	var rows []Sale
	if err := r.db.SelectContext(ctx, &rows, q, args...); err != nil {
		return nil, fmt.Errorf("sales.List: %w", err)
	}
	return rows, nil
}

func (r *Repository) Get(ctx context.Context, id string) (*Sale, error) {
	var s Sale
	err := r.db.GetContext(ctx, &s, `SELECT * FROM sales WHERE id = $1`, id)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("sales.Get: %w", err)
	}
	var items []SaleItem
	if err := r.db.SelectContext(ctx, &items, `SELECT * FROM sale_items WHERE sale_id = $1`, id); err != nil {
		return nil, fmt.Errorf("sales.Get items: %w", err)
	}
	s.Items = items
	return &s, nil
}

func nullStr(v nulljson.String) any {
	if !v.Valid {
		return nil
	}
	return v.String
}

type Service struct{ repo *Repository }

func NewService(repo *Repository) *Service { return &Service{repo: repo} }

type salePayload struct {
	SaleNumber        string `json:"sale_number"`
	OperatorID        string `json:"operator_id"`
	PaymentMethod     string `json:"payment_method"`
	TotalAmountMmk    int    `json:"total_amount_mmk"`
	DiscountAmountMmk int    `json:"discount_amount_mmk"`
	Note              *string `json:"note"`
	VoidReason        *string `json:"void_reason"`
	VoidedBy          *string `json:"voided_by"`
	Items             []struct {
		ID                  string `json:"id"`
		ProductID           string `json:"product_id"`
		ProductNameSnapshot string `json:"product_name_snapshot"`
		PriceSnapshotMmk    int    `json:"price_snapshot_mmk"`
		Quantity            int    `json:"quantity"`
		SubtotalMmk         int    `json:"subtotal_mmk"`
	} `json:"sale_items"`
}

func (s *Service) HandleEvent(ctx context.Context, tx *sqlx.Tx, ev syn.Event, receivedAt time.Time) error {
	var p salePayload
	_ = json.Unmarshal(ev.Raw, &p)
	at := timezone.FromUnixMs(ev.CreatedAt)

	switch ev.EventType {
	case "SALE_CREATED":
		existing, err := s.repo.GetTx(ctx, tx, ev.ID)
		if err != nil {
			return err
		}
		if existing != nil {
			return nil
		}
		pay := p.PaymentMethod
		if pay == "" {
			pay = "cash"
		}
		row := Sale{
			ID: ev.ID, SaleNumber: p.SaleNumber,
			OperatorID: firstNonEmpty(p.OperatorID, ev.OperatorID),
			DeviceID: ev.DeviceID, PaymentMethod: pay,
			TotalAmountMmk: p.TotalAmountMmk, DiscountAmountMmk: p.DiscountAmountMmk,
			Status: "completed", CreatedAt: at,
			ServerReceivedAt: sql.NullTime{Time: receivedAt, Valid: true},
		}
		if p.Note != nil {
			row.Note = nulljson.Text(*p.Note)
		}
		if err := s.repo.Insert(ctx, tx, row); err != nil {
			return err
		}
		for _, it := range p.Items {
			id := it.ID
			if id == "" {
				id = ev.ID + "-" + it.ProductID
			}
			if err := s.repo.InsertItem(ctx, tx, SaleItem{
				ID: id, SaleID: ev.ID, ProductID: it.ProductID,
				ProductNameSnapshot: it.ProductNameSnapshot,
				PriceSnapshotMmk: it.PriceSnapshotMmk, Quantity: it.Quantity,
				SubtotalMmk: it.SubtotalMmk, CreatedAt: at,
			}); err != nil {
				return err
			}
		}
		return nil
	case "SALE_VOIDED":
		saleID := ev.ID
		if ev.ReferenceID != nil && *ev.ReferenceID != "" {
			saleID = *ev.ReferenceID
		}
		existing, err := s.repo.GetTx(ctx, tx, saleID)
		if err != nil {
			return err
		}
		if existing == nil {
			return fmt.Errorf("sales.void missing sale")
		}
		if existing.Status == "voided" {
			return nil
		}
		if !existing.ServerReceivedAt.Valid || !timezone.IsSameShopDay(existing.ServerReceivedAt.Time, receivedAt) {
			return syn.Reject("VOID_WINDOW_CLOSED",
				"This sale can no longer be cancelled.",
				map[string]any{})
		}
		by := ev.OperatorID
		if p.VoidedBy != nil {
			by = *p.VoidedBy
		}
		reason := ""
		if p.VoidReason != nil {
			reason = *p.VoidReason
		}
		return s.repo.Void(ctx, tx, saleID, at, by, reason)
	}
	return syn.Reject("EVENT_VALIDATION_FAILED", "This change could not be saved.", map[string]any{"field": "event_type"})
}

func (s *Service) List(ctx context.Context, operatorID, status, dateFrom, dateTo, productID string) ([]Sale, error) {
	rows, err := s.repo.List(ctx, operatorID, status, dateFrom, dateTo, productID)
	if err != nil {
		return nil, err
	}
	for i := range rows {
		decorateSale(&rows[i])
	}
	return rows, nil
}

func (s *Service) Get(ctx context.Context, id string) (*Sale, error) {
	row, err := s.repo.Get(ctx, id)
	if err != nil || row == nil {
		return row, err
	}
	decorateSale(row)
	return row, nil
}

func decorateSale(s *Sale) {
	s.CreatedAtMs = s.CreatedAt.UnixMilli()
	if s.ServerReceivedAt.Valid {
		ms := s.ServerReceivedAt.Time.UnixMilli()
		s.ServerReceivedAtMs = &ms
	}
}

func firstNonEmpty(a, b string) string {
	if a != "" {
		return a
	}
	return b
}
