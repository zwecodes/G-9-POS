# G9POS Data Model

**Version:** 1.2
**Status:** Draft
**Last updated:** 2026-09-03
**Author:** Architecture Team

**Changelog since 1.1:** Three schema inconsistencies resolved. (1) Removed `AND deleted_at IS NULL` from the §3.5 computed-stock query — `inventory_events` is append-only and has never had a `deleted_at` column, so the filter referenced a field that does not exist and contradicted the identical query in `SYNC-PROTOCOL.md` §3.4. (2) Added `server_received_at` to `sales` (§3.6, PostgreSQL only) — the same-shop-day void rule in this document and in `API-SPEC.md` §5 both evaluate against it, but the column was never declared. (3) Added §1.2 (column conventions and exemptions), which states explicitly which tables omit the standard sync columns and why, so that a blanket "every synced table has `created_at`/`updated_at`/`deleted_at`/`device_id`" rule cannot be asserted against append-only and nested-payload tables. Added §9 for two decisions this pass surfaced but could not settle from existing documentation.

**Changelog since 1.0:** Added §1.1 (Shop timezone) documenting that all date-bounded fields (`expense_date`, `order_date`, report groupings, the sale-void same-day rule) resolve against a fixed server-side timezone constant defined in `API-SPEC.md` §1.7 — not device-local time. This was previously undocumented and could have been misread as "each device's own date," which would have broken the same-day void rule across devices with clock drift.

---

## 1. Overview

This document defines the complete data model for G9POS — covering both the SQLite schema (Flutter/Drift, on-device) and the PostgreSQL schema (Go backend, server-side). Where the two differ, the difference is explicitly noted.

### 1.1 Shop timezone (added in 1.1)

Every column of type `TEXT` storing an ISO date (`YYYY-MM-DD` — e.g. `expenses.expense_date`, `supplier_orders.order_date`) and every business rule that depends on "today" or "same calendar day" (sale void window, daily report boundaries) is evaluated against a single fixed constant, `SHOP_TIMEZONE = Asia/Yangon (UTC+6:30)`, defined in backend config and specified in `API-SPEC.md` §1.7. This is **not** derived from any device's local clock, and not passed per-request. Device clocks (`created_at` on synced rows) remain Unix ms and are used for ordering/LWW as described in §4 of `SYNC-PROTOCOL.md` — they are a separate concern from which *calendar day* an event belongs to for business-rule purposes.

### 1.2 Column conventions and exemptions (added in 1.2)

The default shape for a device-originated business record is four sync columns: `created_at`, `updated_at`, `deleted_at`, `device_id`. Three classes of table deliberately depart from that default. Any coding standard, scaffold, or migration that asserts *"every synced table has all four"* is wrong — it must carve out the exemptions below, because the omissions are load-bearing, not oversights.

| Class | Tables | Omits | Why |
|---|---|---|---|
| Append-only event log | `inventory_events` (§3.5) | `updated_at`, `deleted_at` | Rows are immutable once written. There is no update path and no soft delete: a mistake is corrected by *appending* a compensating event, never by editing or hiding an existing one (`SYNC-PROTOCOL.md` §4.1). Adding `deleted_at` here would make stock silently mutable and defeat the event log. |
| Nested payload children | `sale_items` (§3.7), `supplier_order_items` (§3.11) | `updated_at`, `deleted_at`, `device_id` | These never sync as independent events. They travel inside their parent's event payload — per `API-SPEC.md` §5, `SALE_CREATED` "carries the sale + its `sale_items` in one event payload" and `SUPPLIER_ORDER_CREATED` "carries nested order items in the payload (no separate item-creation events)". The parent row carries the sync columns for the whole unit. |
| Not device-originated | `devices` (§3.2, server only), `sync_queue` (§3.12, SQLite only), `users` (§3.1) | varies — see §3 | `devices` is the server-side registry and `sync_queue` is local outbound state; neither is replicated between devices (§4). `users` has no `device_id` and there is no `USER_*` event type in `API-SPEC.md` §5, so user records are not created by the sync queue — how they *are* provisioned is an open decision (§9). |

The soft-delete principle below applies to every table that **has** a `deleted_at` column. It is not a claim that every table has one.

### Design principles

- Every table that participates in sync as its own event carries a `device_id` and `created_at` field — see §1.2 for the exemptions.
- Inventory stock is never stored as a raw number — only computed from the `inventory_events` log.
- Records in tables that carry a `deleted_at` column are never hard-deleted — they are soft-deleted so sync can propagate deletions correctly. Append-only tables have no delete path at all (§1.2).
- All IDs are UUIDs generated on the device, not auto-increment integers — this ensures IDs are globally unique across devices without needing a server round-trip.

---

## 2. Entity Overview

```
users
  └── devices (one user, multiple devices)

categories
  └── products
        └── inventory_events   (stock changes — append only)
        └── sale_items         (what was sold)

sales
  └── sale_items
  └── sale_voided_events       (if sale is cancelled)

expenses
suppliers
  └── supplier_orders
        └── supplier_order_items

sync_queue                     (local SQLite only)
device_registry                (server only)
```

---

## 3. Tables

---

### 3.1 `users`

Stores authenticated users. For launch, this will be one owner account.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | Primary key |
| `name` | TEXT | Display name |
| `pin` | TEXT | Hashed 4-digit PIN for quick re-auth on device |
| `role` | TEXT | `owner` or `staff` |
| `created_at` | INTEGER | Unix ms |
| `updated_at` | INTEGER | Unix ms |
| `deleted_at` | INTEGER | Soft delete |

**SQLite only:** `jwt_access_token`, `jwt_refresh_token`, `jwt_expires_at` — stored in `flutter_secure_storage`, not in Drift table.

**Note:** the dashboard's `dashboard_viewer` role (`API-SPEC.md` §1.8) is a JWT claim issued at login time, not a stored value in this `role` column — the underlying `users.role` stays `owner`/`staff` regardless of which context a token was issued for.

---

### 3.2 `devices`

Tracks every device that has ever logged in. Server-side only — the device itself knows its own ID from local preferences.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | Primary key — set once on first install, never changes |
| `user_id` | UUID | FK → users |
| `name` | TEXT | Human label e.g. "Shop Tablet", "Owner Phone" |
| `type` | TEXT | `tablet`, `phone`, `browser`, `windows` |
| `is_active_pos` | BOOLEAN | Only one device should be `true` at a time |
| `last_seen_at` | INTEGER | Unix ms — updated on every sync |
| `last_sync_at` | INTEGER | Unix ms |
| `app_version` | TEXT | Flutter app version string |
| `created_at` | INTEGER | Unix ms |
| `revoked_at` | INTEGER | Unix ms — nullable. Set by `POST /v1/devices/{id}/revoke` (`API-SPEC.md` §3.4). A non-null value invalidates the device's refresh token immediately on next use, regardless of natural expiry. (Added 1.1.) |

---

### 3.3 `categories`

Simple product groupings (e.g. "Oils", "Helmets", "Chains").

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | Primary key |
| `name` | TEXT | |
| `sort_order` | INTEGER | Display order in UI |
| `created_at` | INTEGER | Unix ms |
| `updated_at` | INTEGER | Unix ms |
| `deleted_at` | INTEGER | Soft delete |
| `device_id` | UUID | Device that created this record |

**Deletion rule (added 1.1):** per `API-SPEC.md` §5, a `CATEGORY_DELETED` event is rejected server-side if any product with `deleted_at IS NULL` still has this category's `id` as its `category_id`. This is enforced at the application layer (sync handler), not a DB-level foreign key constraint, since SQLite/Drift on-device needs to allow the same soft-delete write locally before it's had a chance to sync and be validated.

---

### 3.4 `products`

Core product catalogue. Stock level is NOT stored here — it is computed from `inventory_events`.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | Primary key |
| `category_id` | UUID | FK → categories, nullable |
| `name` | TEXT | |
| `barcode` | TEXT | Nullable — not all products have barcodes |
| `price_mmk` | INTEGER | Price in Myanmar Kyat, stored as integer (no decimals) |
| `cost_price_mmk` | INTEGER | Purchase cost — for profit reports, nullable |
| `unit` | TEXT | e.g. "pcs", "litre", "pair" |
| `low_stock_threshold` | INTEGER | Alert owner when computed stock hits this level |
| `image_path` | TEXT | Local file path on device, nullable |
| `is_active` | BOOLEAN | Hidden products don't appear in POS search |
| `stock_negative` | BOOLEAN | Server sets true when computed stock goes below 0 |
| `created_at` | INTEGER | Unix ms |
| `updated_at` | INTEGER | Unix ms |
| `deleted_at` | INTEGER | Soft delete |
| `device_id` | UUID | Device that last modified this record (LWW) |

**Note:** `price_mmk` and `cost_price_mmk` are integers (no decimals) because Myanmar Kyat has no subdivision in everyday use.

---

### 3.5 `inventory_events`

Append-only log of every stock change. Never update or delete rows in this table.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | Primary key — idempotency key for sync |
| `product_id` | UUID | FK → products |
| `event_type` | TEXT | See event types below |
| `quantity_delta` | INTEGER | Signed: negative = stock reduction, positive = addition |
| `reference_id` | UUID | FK to the sale, order, or adjustment that caused this. Also the sync batching/grouping key — see `SYNC-PROTOCOL.md` §2.5 |
| `reference_type` | TEXT | `sale`, `sale_void`, `restock`, `adjustment`, `damage`, `return` |
| `note` | TEXT | Optional owner note (e.g. "damaged in flood"). **Required** (application-layer validation, not a NOT NULL constraint) for `adjustment` and `damage` reference types — see `API-SPEC.md` §5 |
| `operator_id` | UUID | FK → users |
| `device_id` | UUID | Device that generated this event |
| `created_at` | INTEGER | Unix ms — device clock |
| `server_received_at` | INTEGER | Unix ms — server clock (PostgreSQL only) |
| `synced_at` | INTEGER | Unix ms — when this device confirmed sync (SQLite only) |

**Event types:**

| Value | Description |
|-------|-------------|
| `INVENTORY_SOLD` | Units sold in a sale |
| `INVENTORY_VOIDED` | Units returned due to sale void |
| `INVENTORY_RESTOCKED` | Units added from supplier |
| `INVENTORY_ADJUSTED` | Manual correction by owner |
| `INVENTORY_DAMAGED` | Units removed due to damage/loss |
| `INVENTORY_RETURNED` | Units returned by customer (non-void) |

**Computed stock query (server):**
```sql
SELECT SUM(quantity_delta)
FROM inventory_events
WHERE product_id = $1;
```

**No `deleted_at` filter (corrected in 1.2):** this table has no `deleted_at` column and must never gain one — see §1.2. Versions of this document up to 1.1 included `AND deleted_at IS NULL` here, which referenced a field that does not exist and disagreed with the same query in `SYNC-PROTOCOL.md` §3.4. Every row ever written counts toward stock, permanently. A row entered in error is corrected by appending an `INVENTORY_ADJUSTED` event, not by removing or hiding the original.

---

### 3.6 `sales`

One row per completed sale transaction.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | Primary key |
| `sale_number` | TEXT | Human-readable e.g. "S-00142" — generated on device. **Display-only, not guaranteed unique across devices** — see `API-SPEC.md` §5. `id` is the real key for all lookups, receipts, and references. |
| `operator_id` | UUID | FK → users |
| `device_id` | UUID | Device where sale was made |
| `payment_method` | TEXT | `cash` (only at launch) |
| `total_amount_mmk` | INTEGER | Sum of all line items |
| `discount_amount_mmk` | INTEGER | Cart-level discount, default 0 |
| `note` | TEXT | Optional |
| `status` | TEXT | `completed` or `voided` |
| `voided_at` | INTEGER | Unix ms — null if not voided |
| `voided_by` | UUID | FK → users — null if not voided |
| `void_reason` | TEXT | Required if voided |
| `created_at` | INTEGER | Unix ms — device clock |
| `server_received_at` | INTEGER | Unix ms — server clock. **PostgreSQL only.** Stamped when the sale's `SALE_CREATED` event group commits (`API-SPEC.md` §6). This is the anchor for the same-shop-day void window. (Added 1.2.) |
| `synced_at` | INTEGER | Unix ms (SQLite only) |

**Rules:**
- `status` starts as `completed`. Only the owner can set it to `voided`.
- Voiding is only allowed on the same **shop-calendar day** as `server_received_at` (not device `created_at`) — see §1.1 and `API-SPEC.md` §1.7.
- Voiding a sale automatically generates `INVENTORY_VOIDED` events for all line items, submitted together as one atomic group per `SYNC-PROTOCOL.md` §2.5.

**Why `server_received_at` is server-side only (added in 1.2):** the void window is deliberately anchored to the server clock in a fixed shop timezone, because device clocks drift (`SYNC-PROTOCOL.md` §8, "Clock skew between devices") and §4 of this document states the device never resolves "which shop-day" locally. The consequence is explicit: **the device cannot pre-compute whether a void is still inside the window.** It submits the `SALE_VOIDED` group optimistically, and the server is the sole enforcer (`API-SPEC.md` §5). If the window has closed, the group is permanently rejected and the device reverts its local void per `SYNC-PROTOCOL.md` §4.4. Whether the app should additionally *hide* the void action once a sale is no longer same-day — which would need this value mirrored to SQLite — is an open decision (§9), not settled by this version.

---

### 3.7 `sale_items`

Line items within a sale. One row per product per sale.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | Primary key |
| `sale_id` | UUID | FK → sales |
| `product_id` | UUID | FK → products |
| `product_name_snapshot` | TEXT | Name at time of sale — products can be renamed later |
| `price_snapshot_mmk` | INTEGER | Price at time of sale |
| `quantity` | INTEGER | Units sold |
| `subtotal_mmk` | INTEGER | `price_snapshot_mmk × quantity` |
| `created_at` | INTEGER | Unix ms |

**Note:** `product_name_snapshot` and `price_snapshot_mmk` are intentional — if a product is renamed or repriced later, historical receipts must still show the original values.

---

### 3.8 `expenses`

Daily shop expenses (fuel, rent, utility bills, etc.).

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | Primary key |
| `category` | TEXT | e.g. "Rent", "Electricity", "Transport" |
| `amount_mmk` | INTEGER | |
| `note` | TEXT | |
| `expense_date` | TEXT | ISO date string `YYYY-MM-DD`, resolved against `SHOP_TIMEZONE` — see §1.1 |
| `operator_id` | UUID | FK → users |
| `device_id` | UUID | |
| `created_at` | INTEGER | Unix ms |
| `updated_at` | INTEGER | Unix ms |
| `deleted_at` | INTEGER | Soft delete |
| `synced_at` | INTEGER | Unix ms (SQLite only) |

Not readable by staff — owner and dashboard (`dashboard_viewer` role included) only, per `API-SPEC.md` §4.7.

---

### 3.9 `suppliers`

Businesses the shop buys stock from.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | Primary key |
| `name` | TEXT | |
| `phone` | TEXT | Nullable |
| `address` | TEXT | Nullable |
| `note` | TEXT | Nullable |
| `created_at` | INTEGER | Unix ms |
| `updated_at` | INTEGER | Unix ms |
| `deleted_at` | INTEGER | Soft delete |
| `device_id` | UUID | |

---

### 3.10 `supplier_orders`

Records of stock purchased from a supplier.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | Primary key |
| `supplier_id` | UUID | FK → suppliers, nullable |
| `order_date` | TEXT | ISO date `YYYY-MM-DD`, resolved against `SHOP_TIMEZONE` — see §1.1 |
| `total_cost_mmk` | INTEGER | |
| `note` | TEXT | |
| `status` | TEXT | `pending`, `received` |
| `received_at` | INTEGER | Unix ms — when stock was physically received |
| `operator_id` | UUID | FK → users |
| `device_id` | UUID | |
| `created_at` | INTEGER | Unix ms |
| `updated_at` | INTEGER | Unix ms |
| `synced_at` | INTEGER | Unix ms (SQLite only) |

**Note:** When `status` changes to `received`, the **device** generates the corresponding `INVENTORY_RESTOCKED` events for all order items and submits them together with the status change as one atomic group (per `SYNC-PROTOCOL.md` §2.5). This is device-originated, not server-originated — see `API-SPEC.md` §7 for why that distinction matters.

---

### 3.11 `supplier_order_items`

Line items within a supplier order.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | Primary key |
| `order_id` | UUID | FK → supplier_orders |
| `product_id` | UUID | FK → products |
| `quantity` | INTEGER | |
| `cost_per_unit_mmk` | INTEGER | |
| `subtotal_mmk` | INTEGER | |
| `created_at` | INTEGER | Unix ms |

---

### 3.12 `sync_queue`

**SQLite only.** Holds all local changes waiting to be sent to the server.

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID | Primary key — same as the event/record ID being synced |
| `event_type` | TEXT | Matches event types from `API-SPEC.md` §5 |
| `payload` | TEXT | JSON blob |
| `device_id` | UUID | |
| `reference_id` | UUID | Nullable, and **NULL for standalone events** — see `SYNC-PROTOCOL.md` §2.5. Groups related events for atomic batching. (Added 1.1.) |
| `created_at` | INTEGER | Unix ms |
| `synced_at` | INTEGER | Unix ms — null until confirmed |
| `retry_count` | INTEGER | Default 0 |
| `last_error` | TEXT | Last server error message if any |

---

## 4. SQLite vs PostgreSQL Differences

| Concern | SQLite (Flutter/Drift) | PostgreSQL (Go backend) |
|---------|----------------------|------------------------|
| ID type | TEXT (UUID string) | UUID native type |
| Timestamps | INTEGER (Unix ms) | TIMESTAMPTZ |
| Booleans | INTEGER (0/1) | BOOLEAN |
| Extra columns | `synced_at` on most tables | `server_received_at` on `inventory_events` (§3.5) and `sales` (§3.6) |
| sync_queue | Present | Not present |
| device_registry | Not present | Present |
| Stock computation | Cached locally, recomputed after sync | Always computed from events |
| Date/day resolution | N/A — device only stores Unix ms, never computes "which shop-day" locally | `SHOP_TIMEZONE` constant applied server-side for all day-boundary logic (§1.1) |

---

## 5. Indexes

### SQLite (critical for POS performance)

```sql
-- Fast barcode lookup
CREATE INDEX idx_products_barcode ON products(barcode);

-- Fast sale history
CREATE INDEX idx_sales_created_at ON sales(created_at);
CREATE INDEX idx_sale_items_sale_id ON sale_items(sale_id);

-- Sync queue flush order
CREATE INDEX idx_sync_queue_synced_at ON sync_queue(synced_at);

-- Sync queue grouping (added 1.1)
CREATE INDEX idx_sync_queue_reference_id ON sync_queue(reference_id);

-- Inventory event lookup per product
CREATE INDEX idx_inventory_events_product_id ON inventory_events(product_id);
```

### PostgreSQL (additional)

```sql
-- Server-side conflict resolution
CREATE INDEX idx_inventory_events_server_received ON inventory_events(server_received_at);

-- Dashboard queries
CREATE INDEX idx_sales_device_id ON sales(device_id);
CREATE INDEX idx_sales_status ON sales(status);

-- Event-group lookups within a sync batch (added 1.1)
CREATE INDEX idx_inventory_events_reference_id ON inventory_events(reference_id);
```

---

## 6. Computed Values (never stored)

These are always calculated at query time, never stored as columns:

| Value | How computed |
|-------|-------------|
| Current stock | `SUM(quantity_delta)` from `inventory_events` per product |
| Sale total | `SUM(subtotal_mmk)` from `sale_items` per sale |
| Daily revenue | `SUM(total_amount_mmk)` from `sales` where `status = completed` and date matches (shop-day, §1.1) |
| Daily profit | Daily revenue − `SUM(cost_price_mmk × quantity)` from `sale_items` joined to products |
| Low stock products | Products where computed stock ≤ `low_stock_threshold` |

---

## 7. First-Run Data Pull (new or replacement device)

On first install and login, the server sends:

1. All `products` (active and inactive)
2. All `categories`
3. All `suppliers`
4. `inventory_events` from the last **90 days**
5. `sales` and `sale_items` from the last **90 days**
6. `expenses` from the last **90 days**

Delivered in chunks of 200 rows per request. Download order: products and categories first (so the POS is usable), then history. If download is interrupted, it resumes from the last confirmed chunk on next app open.

---

## 8. Resolved Decisions

| Decision | Resolution |
|----------|-----------|
| Expense categories | Predefined dropdown: Rent, Electricity, Water, Transport, Food, Supplier Payment, Other — with optional free-text note |
| Supplier order approval | No approval step at launch — owner creates and receives in one action |
| Cost price | Optional but app nudges owner to fill it in. Profit reports show "incomplete" for products missing cost price |
| Sale numbers | Continuous, never reset. Format: `S-00001` incrementing forever. Display-only, not a uniqueness guarantee — see §3.6 (added 1.1) |
| Shop timezone | Fixed constant, `Asia/Yangon`, server-side config — not per-device (added 1.1) |
| Category deletion | Blocked while active products reference it — see §3.3 (added 1.1) |
| Lost device recovery | `devices.revoked_at`, set remotely by the owner — see §3.2 (added 1.1) |
| `inventory_events` soft delete | None — the table is append-only and has no `deleted_at`. Corrections are appended, never applied in place. See §1.2 and §3.5 (added 1.2) |
| Void-window anchor | `sales.server_received_at`, PostgreSQL only. Server is the sole enforcer; the device submits optimistically and reverts on rejection. See §3.6 (added 1.2) |
| Standard sync columns | Four by default (`created_at`, `updated_at`, `deleted_at`, `device_id`), with three documented exemption classes — see §1.2 (added 1.2) |

---

## 9. Open Decisions (added in 1.2)

These surfaced while resolving the 1.2 inconsistencies. Neither is answerable from existing documentation, so both are recorded here rather than guessed at. **Each needs a product decision before the affected code is written.**

| # | Open decision | What is already fixed | What is undecided | Who decides |
|---|---|---|---|---|
| 1 | Should `sales.server_received_at` be mirrored into SQLite? | The column exists server-side and the server is the sole enforcer of the void window (§3.6). Correctness does not depend on this decision. | Purely a UX question: without a local copy, the app must show the void action on *every* sale and let some attempts fail and roll back (`SYNC-PROTOCOL.md` §4.4). With a local copy it could grey the action out once the shop-day has passed. The second is friendlier for a non-technical operator but adds a field to the sync-pull payload and a local shop-day computation that §4 currently forbids. | Product owner, with `UI-GUIDELINES.md` — needed before the sales-history screen is built. |
| 2 | How is a `users` row created? | `users` (§3.1) is documented as a table, and `role` (`owner`/`staff`) is used throughout `API-SPEC.md`. | There is no `USER_CREATED`/`USER_UPDATED` event type in `API-SPEC.md` §5, and `API-SPEC.md` §1.1 forbids adding a REST write for business records. So staff accounts currently have no creation path at all. §3.1 notes launch is "one owner account", which defers but does not answer the question. | Product owner — decide whether staff accounts are in v1 scope at all. If yes, `API-SPEC.md` must define the mechanism; if no, the `staff` role should be marked post-launch. |