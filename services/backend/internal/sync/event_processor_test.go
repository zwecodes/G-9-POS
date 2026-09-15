package sync

import "testing"

func TestGroupEventsStandaloneAndGrouped(t *testing.T) {
	ref := "sale-1"
	events := []Event{
		{ID: "a", EventType: "PRODUCT_CREATED"},
		{ID: "b", EventType: "SALE_CREATED", ReferenceID: &ref},
		{ID: "c", EventType: "INVENTORY_SOLD", ReferenceID: &ref},
		{ID: "d", EventType: "EXPENSE_CREATED"},
	}
	groups := groupEvents(events)
	if len(groups) != 3 {
		t.Fatalf("got %d groups, want 3", len(groups))
	}
	if len(groups[0]) != 1 || groups[0][0].ID != "a" {
		t.Fatalf("first group: %+v", groups[0])
	}
	if len(groups[1]) != 2 || groups[1][0].ID != "b" || groups[1][1].ID != "c" {
		t.Fatalf("sale group: %+v", groups[1])
	}
	if len(groups[2]) != 1 || groups[2][0].ID != "d" {
		t.Fatalf("last group: %+v", groups[2])
	}
}

func TestRoleAllows(t *testing.T) {
	if roleAllows("dashboard_viewer", "SALE_CREATED") {
		t.Fatal("dashboard must not submit shop events")
	}
	if !roleAllows("staff", "SALE_CREATED") || !roleAllows("staff", "EXPENSE_CREATED") || !roleAllows("staff", "INVENTORY_SOLD") {
		t.Fatal("staff should be allowed sale, expense create, inventory sold")
	}
	if roleAllows("staff", "SALE_VOIDED") || roleAllows("staff", "PRODUCT_UPDATED") {
		t.Fatal("staff must not void or edit products")
	}
	if !roleAllows("owner", "SALE_VOIDED") {
		t.Fatal("owner may void")
	}
}
