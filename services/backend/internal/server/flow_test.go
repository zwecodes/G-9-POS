package server

import (
	"bytes"
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/zwecodes/g9pos/backend/internal/testpg"
	"github.com/zwecodes/g9pos/backend/pkg/timezone"
)

type envelope struct {
	Data json.RawMessage `json:"data"`
	Meta map[string]any  `json:"meta"`
}

func TestSetupLoginSyncPull(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db := testpg.Open(t)
	ts := httptest.NewServer(New(db, "test-secret", Options{RelaxLimits: true}))
	t.Cleanup(ts.Close)

	deviceA := uuid.NewString()
	deviceB := uuid.NewString()

	setup := postJSON(t, ts.URL+"/v1/setup", "", map[string]any{
		"username": "owner", "password": "secret12", "name": "Owner", "pin": "1234",
	})
	if setup.StatusCode != 200 {
		t.Fatalf("setup %d %s", setup.StatusCode, setup.Body)
	}

	loginA := decodeData(t, postJSON(t, ts.URL+"/v1/auth/login", "", map[string]any{
		"username": "owner", "password": "secret12",
		"device_id": deviceA, "device_name": "Tablet", "device_type": "tablet",
	}))
	tokenA := loginA["access_token"].(string)
	user := loginA["user"].(map[string]any)
	ownerID := user["id"].(string)

	catID := uuid.NewString()
	productID := uuid.NewString()
	saleID := uuid.NewString()
	item1 := uuid.NewString()
	item2 := uuid.NewString()

	syncBody := map[string]any{
		"device_id": deviceA,
		"events": []map[string]any{
			{
				"id": catID, "event_type": "CATEGORY_CREATED",
				"device_id": deviceA, "operator_id": ownerID,
				"created_at": time.Now().UnixMilli(), "name": "Helmets", "sort_order": 1,
			},
			{
				"id": productID, "event_type": "PRODUCT_CREATED",
				"device_id": deviceA, "operator_id": ownerID,
				"created_at": time.Now().UnixMilli(),
				"category_id": catID, "name": "Full Face", "price_mmk": 25000,
				"cost_price_mmk": 15000, "unit": "pcs", "low_stock_threshold": 5,
			},
			{
				"id": uuid.NewString(), "event_type": "INVENTORY_ADJUSTED",
				"device_id": deviceA, "operator_id": ownerID,
				"created_at": time.Now().UnixMilli(),
				"product_id": productID, "quantity_delta": 10, "note": "Opening stock",
			},
			{
				"id": saleID, "event_type": "SALE_CREATED", "reference_id": saleID,
				"device_id": deviceA, "operator_id": ownerID,
				"created_at": time.Now().UnixMilli(),
				"sale_number": "S-00001", "payment_method": "cash",
				"total_amount_mmk": 50000, "discount_amount_mmk": 0,
				"sale_items": []map[string]any{
					{
						"id": item1, "product_id": productID,
						"product_name_snapshot": "Full Face", "price_snapshot_mmk": 25000,
						"quantity": 1, "subtotal_mmk": 25000,
					},
					{
						"id": item2, "product_id": productID,
						"product_name_snapshot": "Full Face", "price_snapshot_mmk": 25000,
						"quantity": 1, "subtotal_mmk": 25000,
					},
				},
			},
			{
				"id": uuid.NewString(), "event_type": "INVENTORY_SOLD", "reference_id": saleID,
				"device_id": deviceA, "operator_id": ownerID,
				"created_at": time.Now().UnixMilli(),
				"product_id": productID, "quantity_delta": -2,
			},
		},
	}
	syncResp := postJSON(t, ts.URL+"/v1/sync/events", tokenA, syncBody)
	if syncResp.StatusCode != 200 {
		t.Fatalf("sync %d %s", syncResp.StatusCode, syncResp.Body)
	}
	var batch struct {
		Accepted []string `json:"accepted"`
		Rejected []any    `json:"rejected"`
	}
	unmarshalData(t, syncResp.Body, &batch)
	if len(batch.Accepted) != 5 {
		t.Fatalf("accepted=%v rejected=%v body=%s", batch.Accepted, batch.Rejected, syncResp.Body)
	}

	prodResp := getJSON(t, ts.URL+"/v1/products", tokenA)
	if prodResp.StatusCode != 200 {
		t.Fatalf("products %d %s", prodResp.StatusCode, prodResp.Body)
	}
	var products []map[string]any
	unmarshalData(t, prodResp.Body, &products)
	if len(products) != 1 {
		t.Fatalf("products: %s", prodResp.Body)
	}
	if _, isObj := products[0]["barcode"].(map[string]any); isObj {
		t.Fatalf("barcode should be string or null, got object: %s", prodResp.Body)
	}
	if products[0]["barcode"] != nil {
		t.Fatalf("empty barcode should be null: %v", products[0]["barcode"])
	}
	if products[0]["computed_stock"].(float64) != 8 {
		t.Fatalf("computed_stock=%v want 8", products[0]["computed_stock"])
	}

	loginB := decodeData(t, postJSON(t, ts.URL+"/v1/auth/login", "", map[string]any{
		"username": "owner", "password": "secret12",
		"device_id": deviceB, "device_name": "Phone", "device_type": "phone",
	}))
	tokenB := loginB["access_token"].(string)
	pull := getJSON(t, ts.URL+"/v1/sync/pull?last_sync_at=0&device_id="+deviceB, tokenB)
	if pull.StatusCode != 200 {
		t.Fatalf("pull %d %s", pull.StatusCode, pull.Body)
	}
	var payload map[string]any
	unmarshalData(t, pull.Body, &payload)
	prods, _ := payload["products"].([]any)
	if len(prods) == 0 {
		t.Fatalf("device B pull missing products: %s", pull.Body)
	}

	today := timezone.ShopDateString(time.Now())
	rangeResp := getJSON(t, ts.URL+"/v1/reports/range?date_from="+today+"&date_to="+today+"&group_by=day", tokenA)
	if rangeResp.StatusCode != 200 {
		t.Fatalf("range %d %s", rangeResp.StatusCode, rangeResp.Body)
	}
	var points []map[string]any
	unmarshalData(t, rangeResp.Body, &points)
	if len(points) != 1 {
		t.Fatalf("range points: %s", rangeResp.Body)
	}
	if points[0]["revenue_mmk"].(float64) != 50000 {
		t.Fatalf("range revenue multiplied by line items? got %v body=%s", points[0]["revenue_mmk"], rangeResp.Body)
	}

	importResp := postCSV(t, ts.URL+"/v1/catalog/import", tokenA,
		"name,price_mmk,barcode,category,initial_stock\nChain,8000,CH-1,Parts,3\n")
	if importResp.StatusCode != 200 {
		t.Fatalf("import %d %s", importResp.StatusCode, importResp.Body)
	}
	var imported map[string]any
	unmarshalData(t, importResp.Body, &imported)
	if imported["products_created"].(float64) != 1 || imported["categories_created"].(float64) != 1 {
		t.Fatalf("import data: %s", importResp.Body)
	}
}

type httpResult struct {
	StatusCode int
	Body       []byte
}

func postJSON(t *testing.T, url, token string, body any) httpResult {
	t.Helper()
	raw, err := json.Marshal(body)
	if err != nil {
		t.Fatal(err)
	}
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(raw))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	return httpResult{StatusCode: res.StatusCode, Body: b}
}

func getJSON(t *testing.T, url, token string) httpResult {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		t.Fatal(err)
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	return httpResult{StatusCode: res.StatusCode, Body: b}
}

func postCSV(t *testing.T, url, token, csv string) httpResult {
	t.Helper()
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	fw, err := w.CreateFormFile("file", "catalog.csv")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := io.WriteString(fw, csv); err != nil {
		t.Fatal(err)
	}
	_ = w.Close()
	req, err := http.NewRequest(http.MethodPost, url, &buf)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", w.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+token)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	return httpResult{StatusCode: res.StatusCode, Body: b}
}

func decodeData(t *testing.T, res httpResult) map[string]any {
	t.Helper()
	if res.StatusCode != 200 {
		t.Fatalf("http %d %s", res.StatusCode, res.Body)
	}
	var out map[string]any
	unmarshalData(t, res.Body, &out)
	return out
}

func unmarshalData(t *testing.T, body []byte, dest any) {
	t.Helper()
	var env envelope
	if err := json.Unmarshal(body, &env); err != nil {
		t.Fatalf("envelope: %v body=%s", err, body)
	}
	if len(env.Data) == 0 {
		t.Fatalf("missing data: %s", body)
	}
	if err := json.Unmarshal(env.Data, dest); err != nil {
		t.Fatalf("data: %v body=%s", err, body)
	}
}
