package sync

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"

	"github.com/zwecodes/g9pos/backend/internal/auth"
	"github.com/zwecodes/g9pos/backend/internal/categories"
	"github.com/zwecodes/g9pos/backend/internal/devices"
	"github.com/zwecodes/g9pos/backend/internal/expenses"
	"github.com/zwecodes/g9pos/backend/internal/inventory"
	"github.com/zwecodes/g9pos/backend/internal/products"
	"github.com/zwecodes/g9pos/backend/internal/sales"
	"github.com/zwecodes/g9pos/backend/internal/suppliers"
	"github.com/zwecodes/g9pos/backend/internal/testpg"
)

type harness struct {
	db       *sqlx.DB
	svc      *Service
	inv      *inventory.Service
	sales    *sales.Service
	ownerID  string
	deviceID string
}

func newHarness(t *testing.T) *harness {
	t.Helper()
	database := testpg.Open(t)
	ctx := context.Background()
	deviceID := uuid.NewString()

	authSvc := auth.NewService(auth.NewRepository(database), "test-secret")
	_, err := authSvc.Setup(ctx, auth.SetupInput{
		Username: "owner", Password: "secret12", Name: "Owner", PIN: "1234",
	})
	if err != nil {
		t.Fatalf("setup: %v", err)
	}
	pair, _, err := authSvc.Login(ctx, auth.LoginInput{
		Username: "owner", Password: "secret12",
		DeviceID: deviceID, DeviceName: "Tablet", DeviceType: "tablet",
	})
	if err != nil {
		t.Fatalf("login: %v", err)
	}

	cat := categories.NewService(categories.NewRepository(database))
	prod := products.NewService(products.NewRepository(database))
	inv := inventory.NewService(inventory.NewRepository(database))
	sale := sales.NewService(sales.NewRepository(database))
	exp := expenses.NewService(expenses.NewRepository(database))
	sup := suppliers.NewService(suppliers.NewRepository(database))
	dev := devices.NewService(devices.NewRepository(database))
	proc := NewProcessor(cat, prod, inv, sale, exp, sup, dev)
	svc := NewService(NewRepository(database), proc, cat, prod, inv, sale, dev, nil)

	return &harness{
		db: database, svc: svc, inv: inv, sales: sale,
		ownerID: pair.User.ID, deviceID: deviceID,
	}
}

func (h *harness) submit(t *testing.T, role string, events ...map[string]any) BatchResult {
	t.Helper()
	rawEvents := make([]json.RawMessage, 0, len(events))
	for _, e := range events {
		if _, ok := e["device_id"]; !ok {
			e["device_id"] = h.deviceID
		}
		if _, ok := e["operator_id"]; !ok {
			e["operator_id"] = h.ownerID
		}
		if _, ok := e["created_at"]; !ok {
			e["created_at"] = time.Now().UnixMilli()
		}
		b, err := json.Marshal(e)
		if err != nil {
			t.Fatalf("marshal event: %v", err)
		}
		rawEvents = append(rawEvents, b)
	}
	req := BatchRequest{DeviceID: h.deviceID, Events: rawEvents}
	raw, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("marshal batch: %v", err)
	}
	out, err := h.svc.SubmitBatch(context.Background(), role, h.deviceID, raw, req)
	if err != nil {
		t.Fatalf("SubmitBatch: %v", err)
	}
	return out
}

func (h *harness) submitErr(t *testing.T, role string, events ...map[string]any) error {
	t.Helper()
	rawEvents := make([]json.RawMessage, 0, len(events))
	for _, e := range events {
		if _, ok := e["device_id"]; !ok {
			e["device_id"] = h.deviceID
		}
		if _, ok := e["operator_id"]; !ok {
			e["operator_id"] = h.ownerID
		}
		if _, ok := e["created_at"]; !ok {
			e["created_at"] = time.Now().UnixMilli()
		}
		b, err := json.Marshal(e)
		if err != nil {
			t.Fatalf("marshal event: %v", err)
		}
		rawEvents = append(rawEvents, b)
	}
	req := BatchRequest{DeviceID: h.deviceID, Events: rawEvents}
	raw, _ := json.Marshal(req)
	_, err := h.svc.SubmitBatch(context.Background(), role, h.deviceID, raw, req)
	return err
}

func TestProcessorSaleGroupAtomicAndStock(t *testing.T) {
	h := newHarness(t)
	productID := uuid.NewString()
	saleID := uuid.NewString()
	itemID := uuid.NewString()
	invID := uuid.NewString()
	adjustID := uuid.NewString()

	out := h.submit(t, "owner",
		map[string]any{
			"id": productID, "event_type": "PRODUCT_CREATED",
			"name": "Helmet", "price_mmk": 10000, "cost_price_mmk": 6000,
			"unit": "pcs", "low_stock_threshold": 5, "is_active": true,
		},
		map[string]any{
			"id": adjustID, "event_type": "INVENTORY_ADJUSTED",
			"product_id": productID, "quantity_delta": 10, "note": "Opening stock",
		},
	)
	if len(out.Accepted) != 2 || len(out.Rejected) != 0 {
		t.Fatalf("seed: %+v", out)
	}

	out = h.submit(t, "owner",
		map[string]any{
			"id": saleID, "event_type": "SALE_CREATED", "reference_id": saleID,
			"sale_number": "S-00001", "payment_method": "cash",
			"total_amount_mmk": 10000, "discount_amount_mmk": 0,
			"sale_items": []map[string]any{{
				"id": itemID, "product_id": productID,
				"product_name_snapshot": "Helmet", "price_snapshot_mmk": 10000,
				"quantity": 1, "subtotal_mmk": 10000,
			}},
		},
		map[string]any{
			"id": invID, "event_type": "INVENTORY_SOLD", "reference_id": saleID,
			"product_id": productID, "quantity_delta": -1,
		},
	)
	if len(out.Accepted) != 2 {
		t.Fatalf("sale group accepted=%v rejected=%v", out.Accepted, out.Rejected)
	}

	stock, err := h.inv.Stock(context.Background(), mustTx(t, h.db), productID)
	if err != nil {
		t.Fatalf("stock: %v", err)
	}
	if stock != 9 {
		t.Fatalf("stock=%d want 9", stock)
	}

	sale, err := h.sales.Get(context.Background(), saleID)
	if err != nil || sale == nil {
		t.Fatalf("sale: %v %#v", err, sale)
	}
	if sale.ServerReceivedAtMs == nil {
		t.Fatal("server_received_at missing on sale")
	}
}

func TestProcessorGroupRollbackOnFKFailure(t *testing.T) {
	h := newHarness(t)
	saleID := uuid.NewString()
	missingProduct := uuid.NewString()
	err := h.submitErr(t, "owner",
		map[string]any{
			"id": saleID, "event_type": "SALE_CREATED", "reference_id": saleID,
			"sale_number": "S-00002", "payment_method": "cash",
			"total_amount_mmk": 1000, "discount_amount_mmk": 0,
			"sale_items": []map[string]any{{
				"id": uuid.NewString(), "product_id": missingProduct,
				"product_name_snapshot": "Ghost", "price_snapshot_mmk": 1000,
				"quantity": 1, "subtotal_mmk": 1000,
			}},
		},
		map[string]any{
			"id": uuid.NewString(), "event_type": "INVENTORY_SOLD", "reference_id": saleID,
			"product_id": missingProduct, "quantity_delta": -1,
		},
	)
	if err == nil {
		t.Fatal("expected transient failure for missing product")
	}
	sale, _ := h.sales.Get(context.Background(), saleID)
	if sale != nil {
		t.Fatal("sale row must not survive a rolled-back group")
	}
}

func TestProcessorRejects(t *testing.T) {
	h := newHarness(t)
	catID := uuid.NewString()
	productID := uuid.NewString()

	h.submit(t, "owner",
		map[string]any{"id": catID, "event_type": "CATEGORY_CREATED", "name": "Helmets", "sort_order": 1},
		map[string]any{
			"id": productID, "event_type": "PRODUCT_CREATED",
			"category_id": catID, "name": "Full Face", "price_mmk": 1,
		},
	)

	out := h.submit(t, "owner",
		map[string]any{"id": catID, "event_type": "CATEGORY_DELETED"},
	)
	if len(out.Rejected) != 1 || out.Rejected[0].Reason != "CATEGORY_HAS_PRODUCTS" {
		t.Fatalf("category delete: %+v", out.Rejected)
	}
	n := 0
	_ = h.db.Get(&n, `SELECT COUNT(*) FROM categories WHERE id=$1 AND deleted_at IS NULL`, catID)
	if n != 1 {
		t.Fatal("category should still be present")
	}

	out = h.submit(t, "owner",
		map[string]any{
			"id": uuid.NewString(), "event_type": "INVENTORY_ADJUSTED",
			"product_id": productID, "quantity_delta": 1,
		},
	)
	if len(out.Rejected) != 1 || out.Rejected[0].Reason != "EVENT_VALIDATION_FAILED" {
		t.Fatalf("missing note: %+v", out.Rejected)
	}

	out = h.submit(t, "staff",
		map[string]any{"id": uuid.NewString(), "event_type": "PRODUCT_CREATED", "name": "Nope", "price_mmk": 1},
	)
	if len(out.Rejected) != 1 || out.Rejected[0].Reason != "ROLE_NOT_PERMITTED" {
		t.Fatalf("staff product: %+v", out.Rejected)
	}
}

func TestProcessorVoidWindow(t *testing.T) {
	h := newHarness(t)
	productID := uuid.NewString()
	saleID := uuid.NewString()
	h.submit(t, "owner",
		map[string]any{"id": productID, "event_type": "PRODUCT_CREATED", "name": "Cap", "price_mmk": 500},
		map[string]any{
			"id": uuid.NewString(), "event_type": "INVENTORY_ADJUSTED",
			"product_id": productID, "quantity_delta": 5, "note": "Open",
		},
	)
	h.submit(t, "owner",
		map[string]any{
			"id": saleID, "event_type": "SALE_CREATED", "reference_id": saleID,
			"sale_number": "S-00003", "payment_method": "cash",
			"total_amount_mmk": 500, "discount_amount_mmk": 0,
			"sale_items": []map[string]any{{
				"id": uuid.NewString(), "product_id": productID,
				"product_name_snapshot": "Cap", "price_snapshot_mmk": 500,
				"quantity": 1, "subtotal_mmk": 500,
			}},
		},
		map[string]any{
			"id": uuid.NewString(), "event_type": "INVENTORY_SOLD", "reference_id": saleID,
			"product_id": productID, "quantity_delta": -1,
		},
	)

	_, err := h.db.Exec(`UPDATE sales SET server_received_at = NOW() - INTERVAL '2 days' WHERE id=$1`, saleID)
	if err != nil {
		t.Fatalf("backdate: %v", err)
	}

	voidID := uuid.NewString()
	out := h.submit(t, "owner",
		map[string]any{
			"id": voidID, "event_type": "SALE_VOIDED", "reference_id": saleID,
			"void_reason": "wrong item",
		},
		map[string]any{
			"id": uuid.NewString(), "event_type": "INVENTORY_VOIDED", "reference_id": saleID,
			"product_id": productID, "quantity_delta": 1,
		},
	)
	if len(out.Rejected) != 2 || out.Rejected[0].Reason != "VOID_WINDOW_CLOSED" {
		t.Fatalf("void window: %+v", out.Rejected)
	}
	sale, _ := h.sales.Get(context.Background(), saleID)
	if sale == nil || sale.Status != "completed" {
		t.Fatalf("sale status after rejected void: %#v", sale)
	}
}

func TestProcessorIdempotentResubmit(t *testing.T) {
	h := newHarness(t)
	productID := uuid.NewString()
	ev := map[string]any{"id": productID, "event_type": "PRODUCT_CREATED", "name": "Oil", "price_mmk": 2000}
	first := h.submit(t, "owner", ev)
	second := h.submit(t, "owner", ev)
	if len(first.Accepted) != 1 || len(second.Accepted) != 1 {
		t.Fatalf("idempotent accepted first=%v second=%v", first.Accepted, second.Accepted)
	}
	var n int
	if err := h.db.Get(&n, `SELECT COUNT(*) FROM products WHERE id=$1`, productID); err != nil || n != 1 {
		t.Fatalf("product count=%d err=%v", n, err)
	}
}

func TestProcessorNegativeStockCorrection(t *testing.T) {
	h := newHarness(t)
	productID := uuid.NewString()
	h.submit(t, "owner",
		map[string]any{"id": productID, "event_type": "PRODUCT_CREATED", "name": "Bolt", "price_mmk": 100, "low_stock_threshold": 5},
	)
	out := h.submit(t, "owner",
		map[string]any{
			"id": uuid.NewString(), "event_type": "INVENTORY_SOLD",
			"product_id": productID, "quantity_delta": -2,
		},
	)
	if len(out.StockCorrections) != 1 || !out.StockCorrections[0].StockNegative || out.StockCorrections[0].ComputedStock != -2 {
		t.Fatalf("stock_corrections: %+v", out.StockCorrections)
	}
}

func mustTx(t *testing.T, database *sqlx.DB) *sqlx.Tx {
	t.Helper()
	tx, err := database.Beginx()
	if err != nil {
		t.Fatalf("begin: %v", err)
	}
	t.Cleanup(func() { _ = tx.Rollback() })
	return tx
}
