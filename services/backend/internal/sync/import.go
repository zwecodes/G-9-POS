package sync

import (
	"context"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
)

type ImportResult struct {
	ProductsCreated        int `json:"products_created"`
	CategoriesCreated      int `json:"categories_created"`
	InventoryEventsCreated int `json:"inventory_events_created"`
}

type ImportRowError struct {
	Row     int    `json:"row"`
	Field   string `json:"field"`
	Message string `json:"message"`
}

type ImportError struct {
	Details []ImportRowError
}

func (e *ImportError) Error() string { return "csv import failed" }

type parsedRow struct {
	row          int
	name         string
	price        int
	cost         *int
	barcode      string
	category     string
	unit         string
	lowStock     int
	initialStock int
}

func (s *Service) ImportCatalog(ctx context.Context, r io.Reader, deviceID, operatorID string) (ImportResult, error) {
	records, err := csv.NewReader(r).ReadAll()
	if err != nil {
		return ImportResult{}, &ImportError{Details: []ImportRowError{{
			Row: 0, Field: "file", Message: "This file could not be read.",
		}}}
	}
	if len(records) == 0 {
		return ImportResult{}, &ImportError{Details: []ImportRowError{{
			Row: 0, Field: "file", Message: "The CSV needs a header row.",
		}}}
	}

	header := map[string]int{}
	for i, colName := range records[0] {
		header[strings.ToLower(strings.TrimSpace(colName))] = i
	}
	var headerErrs []ImportRowError
	if _, ok := header["name"]; !ok {
		headerErrs = append(headerErrs, ImportRowError{Row: 0, Field: "name", Message: "The CSV is missing the name column."})
	}
	if _, ok := header["price_mmk"]; !ok {
		headerErrs = append(headerErrs, ImportRowError{Row: 0, Field: "price_mmk", Message: "The CSV is missing the price_mmk column."})
	}
	if len(headerErrs) > 0 {
		return ImportResult{}, &ImportError{Details: headerErrs}
	}

	data := records[1:]
	if len(data) > 1000 {
		return ImportResult{}, &ImportError{Details: []ImportRowError{{
			Row: 0, Field: "file", Message: "The CSV has too many rows. Maximum is 1000.",
		}}}
	}

	var details []ImportRowError
	seenBarcode := map[string]int{}
	parsed := make([]parsedRow, 0, len(data))

	for i, rec := range data {
		rowN := i + 1
		name := strings.TrimSpace(csvCol(rec, header, "name"))
		if name == "" {
			details = append(details, ImportRowError{Row: rowN, Field: "name", Message: "Product name is required."})
			continue
		}
		price, err := parseNonNegInt(csvCol(rec, header, "price_mmk"))
		if err != nil {
			details = append(details, ImportRowError{Row: rowN, Field: "price_mmk", Message: "Price must be a whole number of 0 or more."})
			continue
		}
		var cost *int
		if raw := strings.TrimSpace(csvCol(rec, header, "cost_price_mmk")); raw != "" {
			v, err := parseNonNegInt(raw)
			if err != nil {
				details = append(details, ImportRowError{Row: rowN, Field: "cost_price_mmk", Message: "Cost must be a whole number of 0 or more."})
				continue
			}
			cost = &v
		}
		barcode := strings.TrimSpace(csvCol(rec, header, "barcode"))
		if barcode != "" {
			if prev, ok := seenBarcode[barcode]; ok {
				details = append(details, ImportRowError{Row: rowN, Field: "barcode", Message: fmt.Sprintf("Barcode is duplicated with row %d.", prev)})
				continue
			}
			seenBarcode[barcode] = rowN
		}
		low := 5
		if raw := strings.TrimSpace(csvCol(rec, header, "low_stock_threshold")); raw != "" {
			v, err := parseNonNegInt(raw)
			if err != nil {
				details = append(details, ImportRowError{Row: rowN, Field: "low_stock_threshold", Message: "Low-stock threshold must be a whole number of 0 or more."})
				continue
			}
			low = v
		}
		stock := 0
		if raw := strings.TrimSpace(csvCol(rec, header, "initial_stock")); raw != "" {
			v, err := parseNonNegInt(raw)
			if err != nil {
				details = append(details, ImportRowError{Row: rowN, Field: "initial_stock", Message: "Initial stock must be a whole number of 0 or more."})
				continue
			}
			stock = v
		}
		unit := strings.TrimSpace(csvCol(rec, header, "unit"))
		if unit == "" {
			unit = "pcs"
		}
		parsed = append(parsed, parsedRow{
			row: rowN, name: name, price: price, cost: cost, barcode: barcode,
			category: strings.TrimSpace(csvCol(rec, header, "category")),
			unit: unit, lowStock: low, initialStock: stock,
		})
	}
	if len(details) > 0 {
		return ImportResult{}, &ImportError{Details: details}
	}

	tx, err := s.repo.BeginTx(ctx)
	if err != nil {
		return ImportResult{}, fmt.Errorf("sync.ImportCatalog begin: %w", err)
	}
	defer tx.Rollback()

	for _, row := range parsed {
		if row.barcode == "" {
			continue
		}
		existing, err := s.products.FindActiveByBarcodeTx(ctx, tx, row.barcode)
		if err != nil {
			return ImportResult{}, err
		}
		if existing != nil {
			details = append(details, ImportRowError{Row: row.row, Field: "barcode", Message: "A product with this barcode already exists."})
		}
	}
	if len(details) > 0 {
		return ImportResult{}, &ImportError{Details: details}
	}

	now := time.Now().UTC()
	nowMs := now.UnixMilli()
	catIDs := map[string]string{}
	var result ImportResult
	productIDs := map[string]struct{}{}

	for _, row := range parsed {
		var categoryID *string
		if row.category != "" {
			id, ok := catIDs[row.category]
			if !ok {
				existing, err := s.categories.FindByNameTx(ctx, tx, row.category)
				if err != nil {
					return ImportResult{}, err
				}
				if existing != nil {
					id = existing.ID
				} else {
					id = uuid.NewString()
					ev, err := catalogEvent(map[string]any{
						"id": id, "event_type": "CATEGORY_CREATED",
						"device_id": deviceID, "operator_id": operatorID,
						"created_at": nowMs, "name": row.category, "sort_order": 0,
					})
					if err != nil {
						return ImportResult{}, err
					}
					if err := s.processor.Apply(ctx, tx, ev, now); err != nil {
						return ImportResult{}, err
					}
					result.CategoriesCreated++
				}
				catIDs[row.category] = id
			}
			copied := id
			categoryID = &copied
		}

		productID := uuid.NewString()
		payload := map[string]any{
			"id": productID, "event_type": "PRODUCT_CREATED",
			"device_id": deviceID, "operator_id": operatorID,
			"created_at": nowMs, "name": row.name, "price_mmk": row.price,
			"unit": row.unit, "low_stock_threshold": row.lowStock, "is_active": true,
		}
		if categoryID != nil {
			payload["category_id"] = *categoryID
		}
		if row.barcode != "" {
			payload["barcode"] = row.barcode
		}
		if row.cost != nil {
			payload["cost_price_mmk"] = *row.cost
		}
		ev, err := catalogEvent(payload)
		if err != nil {
			return ImportResult{}, err
		}
		if err := s.processor.Apply(ctx, tx, ev, now); err != nil {
			return ImportResult{}, err
		}
		result.ProductsCreated++

		if row.initialStock > 0 {
			invID := uuid.NewString()
			invEv, err := catalogEvent(map[string]any{
				"id": invID, "event_type": "INVENTORY_ADJUSTED",
				"device_id": deviceID, "operator_id": operatorID,
				"created_at": nowMs, "product_id": productID,
				"quantity_delta": row.initialStock, "note": "CSV catalog import",
				"reference_type": "adjustment",
			})
			if err != nil {
				return ImportResult{}, err
			}
			if err := s.processor.Apply(ctx, tx, invEv, now); err != nil {
				return ImportResult{}, err
			}
			result.InventoryEventsCreated++
			productIDs[productID] = struct{}{}
		}
	}

	_, alerts, err := s.stockAfter(ctx, tx, productIDs)
	if err != nil {
		return ImportResult{}, err
	}
	if err := tx.Commit(); err != nil {
		return ImportResult{}, fmt.Errorf("sync.ImportCatalog commit: %w", err)
	}
	if s.hub != nil {
		for _, a := range alerts {
			s.hub.Broadcast(a.event, a.payload)
		}
	}
	return result, nil
}

func catalogEvent(payload map[string]any) (Event, error) {
	raw, err := json.Marshal(payload)
	if err != nil {
		return Event{}, err
	}
	return Unmarshal(raw)
}

func csvCol(rec []string, header map[string]int, name string) string {
	i, ok := header[name]
	if !ok || i < 0 || i >= len(rec) {
		return ""
	}
	return rec[i]
}

func parseNonNegInt(s string) (int, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0, fmt.Errorf("empty")
	}
	n, err := strconv.Atoi(s)
	if err != nil || n < 0 {
		return 0, fmt.Errorf("invalid")
	}
	return n, nil
}
