package sync

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jmoiron/sqlx"

	"github.com/zwecodes/g9pos/backend/internal/categories"
	"github.com/zwecodes/g9pos/backend/internal/devices"
	"github.com/zwecodes/g9pos/backend/internal/expenses"
	"github.com/zwecodes/g9pos/backend/internal/inventory"
	"github.com/zwecodes/g9pos/backend/internal/products"
	"github.com/zwecodes/g9pos/backend/internal/sales"
	"github.com/zwecodes/g9pos/backend/internal/suppliers"
)

type Processor struct {
	categories *categories.Service
	products   *products.Service
	inventory  *inventory.Service
	sales      *sales.Service
	expenses   *expenses.Service
	suppliers  *suppliers.Service
	devices    *devices.Service
}

func NewProcessor(
	categories *categories.Service,
	products *products.Service,
	inventory *inventory.Service,
	sales *sales.Service,
	expenses *expenses.Service,
	suppliers *suppliers.Service,
	devices *devices.Service,
) *Processor {
	return &Processor{
		categories: categories,
		products:   products,
		inventory:  inventory,
		sales:      sales,
		expenses:   expenses,
		suppliers:  suppliers,
		devices:    devices,
	}
}

func (p *Processor) Apply(ctx context.Context, tx *sqlx.Tx, ev Event, receivedAt time.Time) error {
	switch ev.EventType {
	case "CATEGORY_CREATED", "CATEGORY_UPDATED", "CATEGORY_DELETED":
		return p.categories.HandleEvent(ctx, tx, ev)

	case "PRODUCT_CREATED", "PRODUCT_UPDATED", "PRODUCT_DELETED":
		return p.products.HandleEvent(ctx, tx, ev)

	case "INVENTORY_SOLD", "INVENTORY_VOIDED", "INVENTORY_RESTOCKED",
		"INVENTORY_ADJUSTED", "INVENTORY_DAMAGED", "INVENTORY_RETURNED":
		return p.inventory.HandleEvent(ctx, tx, ev, receivedAt)

	case "SALE_CREATED", "SALE_VOIDED":
		return p.sales.HandleEvent(ctx, tx, ev, receivedAt)

	case "EXPENSE_CREATED", "EXPENSE_UPDATED", "EXPENSE_DELETED":
		return p.expenses.HandleEvent(ctx, tx, ev)

	case "SUPPLIER_CREATED", "SUPPLIER_UPDATED", "SUPPLIER_DELETED",
		"SUPPLIER_ORDER_CREATED", "SUPPLIER_ORDER_UPDATED", "SUPPLIER_ORDER_RECEIVED":
		return p.suppliers.HandleEvent(ctx, tx, ev)

	case "DEVICE_ACTIVATED":
		return p.devices.HandleEvent(ctx, tx, ev)

	default:
		return fmt.Errorf("unknown event type: %s", ev.EventType)
	}
}

func roleAllows(role, eventType string) bool {
	if role == "dashboard_viewer" {
		return false
	}
	if role == "owner" {
		return true
	}
	switch eventType {
	case "SALE_CREATED", "EXPENSE_CREATED", "INVENTORY_SOLD":
		return true
	default:
		return false
	}
}

func groupEvents(events []Event) [][]Event {
	seen := map[string]int{}
	var groups [][]Event
	for _, ev := range events {
		if ev.ReferenceID == nil || *ev.ReferenceID == "" {
			groups = append(groups, []Event{ev})
			continue
		}
		k := *ev.ReferenceID
		if i, ok := seen[k]; ok {
			groups[i] = append(groups[i], ev)
			continue
		}
		seen[k] = len(groups)
		groups = append(groups, []Event{ev})
	}
	return groups
}

func eventProductID(ev Event) string {
	var p struct {
		ProductID string `json:"product_id"`
	}
	_ = json.Unmarshal(ev.Raw, &p)
	if p.ProductID != "" {
		return p.ProductID
	}
	if isInventoryType(ev.EventType) {
		return ev.ID
	}
	return ""
}

func isInventoryType(t string) bool {
	switch t {
	case "INVENTORY_SOLD", "INVENTORY_VOIDED", "INVENTORY_RESTOCKED",
		"INVENTORY_ADJUSTED", "INVENTORY_DAMAGED", "INVENTORY_RETURNED":
		return true
	default:
		return false
	}
}
