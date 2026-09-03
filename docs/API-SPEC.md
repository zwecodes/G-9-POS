# G9POS API Specification

**Version:** 1.4
**Status:** Resolved — no open questions
**Last updated:** 2026-09-03
**Author:** Architecture Team

**Changelog since 1.3:** No contract changes. §1.4's conformance note, written in 1.3 against an unreadable `CODING-STANDARDS.md`, is now stated against its actual v1.1 text: §5.8's `APIResponse{Success, Data, Error string}` struct is the flat `{success, data, error}` form §1.4 rules out, and diverges on four counts (spurious `success` flag, `error` as a string rather than an object, no `error.code`, no `meta`). The note now also flags that the `response.*` helpers built on that struct and the §5.3/§5.4 handler examples calling them are affected, and that a flat string `error` has nowhere to carry `retry_after` (§2.1) or `blocking_product_count` (§5). §1.4 itself is unchanged and remains binding.

**Changelog since 1.2:** Consistency pass — no new product decisions. (1) Added §6.1, the server-side contract for permanently rejected events: which conditions are permanent, the new `rejected[]` response array, and the `reason` codes. Up to 1.2 this document defined two permanent rejections (`CATEGORY_DELETED`, `SALE_VOIDED`) without saying how the device learns of them or what it should do, and `SYNC-PROTOCOL.md` §2.3 was dropping them silently. The device-side half is in `SYNC-PROTOCOL.md` §4.4. (2) Removed `POST /v1/sync/device/activate` (§3.2, §9) — it contradicted §1.1, was never actually specified in `SYNC-PROTOCOL.md` §5.3 as an endpoint, and cannot work during a no-internet failover; `DEVICE_ACTIVATED` is now registered in §5 as the queue event it always was. (3) Marked §1.4 binding, so a lower-authority document cannot restate the envelope in an incompatible shape. (4) Fixed stale cross-references: §1.5 pointed at §13 for rate limits (correct section is §12) and §6 pointed at §12.2 for WebSocket events (correct section is §11.2). (5) Retired §14, whose two follow-ups were completed in `SYNC-PROTOCOL.md` 1.1 and `DATA-MODEL.md` 1.1. (6) Corrected document filenames throughout to match the actual uppercase files, and refreshed §16.

**Changelog since 1.1:** Resolved all 7 open questions from §15: added a separate `dashboard_viewer` role/login path instead of reusing the owner role; added account lockout on top of IP rate limiting; added remote device revocation as the safety valve for lost staff devices; blocked category deletion while active products reference it; declared `sale_number` a non-unique display label (UUID `id` remains the real key); specified WebSocket reconnect backoff; gated reports/expenses by the active PIN user, not the device JWT.

**Changelog since 1.0:** Removed the parallel direct-REST-write path for products/categories/sales/void/expenses/suppliers/supplier-orders — the sync queue is now the *only* write path for the POS app, matching the offline-first principle in `SYNC-PROTOCOL.md` §1. Fixed the same-day void rule to use a fixed shop timezone instead of a rolling 24h window. Added event-group batching (by `reference_id`) so a sale and its inventory events can never be split across sync batches or applied non-atomically. Made supplier-order receipt device-originated instead of server-originated.

---

## 1. Overview

This document defines every REST endpoint and WebSocket event exposed by the G9POS Go backend, for two consumer types:

- **The Flutter POS app** (tablet + phone) — writes shop data exclusively through the sync queue (§9); reads its own local SQLite for everything else and never depends on REST reads to function offline.
- **The remote dashboard** (iPhone / Windows / browser) — read-only, plus live updates over WebSocket. It has no write endpoints at all, matching `ARCHITECTURE.md` §10 ("you observe and advise, you don't intervene").

### 1.1 The one write path

Per `SYNC-PROTOCOL.md` §1: *"Every write goes to local SQLite first, server second."* This is not a POS-app implementation detail — it's an API contract. **There is no REST endpoint anywhere in this spec that creates or mutates a product, category, sale, void, expense, supplier, or supplier order directly.** Every one of those is an event type submitted through `POST /v1/sync/events` (§9), exactly like `INVENTORY_SOLD` already is. This was not true in v1.0 of this doc — v1.0 accidentally introduced a second write path with no real caller, which would have meant maintaining two code paths (REST handler + sync handler) that had to stay behaviorally identical forever, for endpoints nothing in the system actually calls. Removed.

The only things that remain genuine REST writes are: **auth** (login/refresh/logout — inherently synchronous, requires a server round-trip by definition) and **device rename** (cosmetic metadata, not a synced business record).

### 1.2 Base URL & versioning

```
https://api.g9pos.com/v1/...
```

Path-based versioning (`/v1`). A breaking change requires `/v2` — a shop's tablet may run an old build for months, so `/v1` never silently changes shape.

### 1.3 Auth header

All endpoints except `POST /v1/auth/login` require `Authorization: Bearer <access_token>`. Missing/expired → `401`, handled by the offline-auth flow in `ARCHITECTURE.md` §7 (never surfaced as a login prompt while offline).

### 1.4 Standard response envelope

Success:
```json
{ "data": { ... }, "meta": { "request_id": "req_01J2..." } }
```

List responses add cursor pagination to `meta.page`: `{ "cursor", "next_cursor", "has_more", "limit" }`.

Error:
```json
{ "error": { "code": "VALIDATION_ERROR", "message": "string", "field": "string" }, "meta": { "request_id": "..." } }
```

**This shape is binding (stated explicitly in 1.3).** It is the canonical wire contract for every endpoint in this specification, and there is exactly one of it. Three properties are load-bearing and cannot be dropped by an implementation or a code sample:

- **`meta.request_id` on every response**, success or error. It is the only way to correlate a failure the owner reports with a line in the server log.
- **`error.code` is a machine-readable enum**, not a prose string. The whole table in §1.5 depends on it, and so do fields like `ACCOUNT_LOCKED`'s `retry_after` (§2.1) and `CATEGORY_DELETED`'s `blocking_product_count` (§5). A flat `error: "some message"` string cannot carry any of it.
- **Success and error are distinguished by which key is present** (`data` vs `error`), not by a separate boolean flag.

Any lower-authority document, helper struct, or scaffolding example that describes a different envelope — for example a flat `{ success, data, error }` object — is wrong and must be corrected to match this section rather than the reverse. Per the project's documentation hierarchy, a summary or standards document does not get to redefine a contract owned by this specification.

**Confirmed conflict with `CODING-STANDARDS.md` §5.8 (v1.1).** That section's `APIResponse` struct is exactly the flat form ruled out above, and it does not conform on four counts:

| `CODING-STANDARDS.md` §5.8 | This section requires |
|---|---|
| A `Success bool` field, serialized as `success` | No `success` flag — presence of `data` vs `error` is the signal |
| `Error` is a `string` | `error` is an **object** carrying `code`, `message`, `field` |
| No `code` field anywhere | `error.code` is a machine-readable enum from §1.5 |
| No `meta` field anywhere | `meta.request_id` on **every** response |

§5.8 is the lower-authority document and is the one that must change; this section does not move. The fix is not limited to the struct — the `response.OK` / `response.BadRequest` / `response.Unauthorized` / `response.InternalError` helpers built on it, and the `internal/products` handler examples in §5.3 and §5.4 that call them, all serialize the wrong shape and must be reworked together. As written, code scaffolded from §5.8 would satisfy no endpoint in this specification, and would break the `retry_after` (§2.1) and `blocking_product_count` (§5) fields outright, since a flat string `error` has nowhere to put them.

### 1.5 Error codes

| Code | HTTP status | Meaning |
|------|-------------|---------|
| `VALIDATION_ERROR` | 400 | Request body failed validation |
| `UNAUTHORIZED` | 401 | Missing/invalid/expired token |
| `FORBIDDEN` | 403 | Valid token, insufficient role |
| `NOT_FOUND` | 404 | Resource doesn't exist or is soft-deleted |
| `CONFLICT` | 409 | LWW conflict, or a business rule rejected an event (e.g. void outside the allowed day). For events submitted via the sync queue this is a **per-event** outcome reported in the response body, not the batch's HTTP status — see §6.1 |
| `PAYLOAD_TOO_LARGE` | 413 | Batch exceeds 5MB |
| `RATE_LIMITED` | 429 | Too many requests, see §12 |
| `INTERNAL_ERROR` | 500 | Unhandled server error |

### 1.6 Role enforcement

Every endpoint lists which role(s) may call it: **owner**, **staff**, or **dashboard**. Role is read from JWT claims server-side, never trusted from the client body (`ARCHITECTURE.md` §11). For event types submitted via the sync queue, role is enforced the same way — the sync handler checks the submitting user's role before applying an owner-only event type (e.g. a void submitted by a staff JWT is rejected with `409 CONFLICT`, not silently applied).

### 1.7 Shop timezone — fixed constant

**New in 1.1.** Every rule in this system that depends on "today" or "same day" (void window, daily summary, expense dates) now resolves against a single fixed server-side constant: `SHOP_TIMEZONE = Asia/Yangon (UTC+6:30)`. This is not per-device, not inferred from the device clock, and not passed in requests. It lives in backend config. At single-shop scale, hardcoding it is correct and removes an entire category of "whose clock do we trust" bugs; if G9POS ever supports multiple shops, this becomes a per-shop field at that point — not before.

### 1.8 Dashboard identity — resolved

**Resolved in 1.2.** The dashboard does **not** reuse the owner's `role: owner` token. `POST /v1/auth/login` accepts an optional `login_context: "dashboard"` field; when set, the server still validates the same username/password but issues a token with `role: dashboard_viewer` instead of `role: owner`. Every write-capable endpoint and every mutating event type in §5 rejects `dashboard_viewer` outright, even if a `dashboard_viewer` token is replayed against a POS-only path — this is enforced the same way as any other role check (§1.6), not by the client hiding buttons. This means a stolen iPhone/laptop/browser dashboard session can only ever read data, never act as the owner, which was the actual gap in v1.0/v1.1.

---

## 2. Authentication

*(Unchanged from v1.0 — the only genuine synchronous-write endpoints in the system.)*

### 2.1 `POST /v1/auth/login`

No auth required, requires internet. Request: `{ username, password, device_id, device_name, device_type, login_context? }`. Response: `{ access_token, refresh_token, expires_at, user }`. `device_id` is client-generated on first install. `login_context: "dashboard"` issues a `dashboard_viewer` token instead of the account's normal role (§1.8).

**Account lockout — resolved in 1.2.** In addition to the existing 5 requests/minute/IP limit (§12), the account itself locks after 5 consecutive failed attempts, for 15 minutes, regardless of source IP. Locked-out attempts return `401` with `error.code: ACCOUNT_LOCKED` and a `retry_after` field. There is deliberately no self-service "forgot password" flow — for a single-owner account, recovery is a manual, verified process (contact support), which is appropriate at this scale and avoids building an entire reset-token/email-delivery subsystem nothing else in the architecture needs yet.

### 2.2 `POST /v1/auth/refresh`

*Specified in `SYNC-PROTOCOL.md` §9.* Owner/staff.

### 2.3 `POST /v1/auth/logout`

Owner/staff. Revokes the refresh token server-side (denylist by token ID). Does not touch local SQLite — a logout never deletes shop data from the device.

### 2.4 Staff PIN

Remains **on-device only** (not a server endpoint) per the original design — the PIN itself is never validated by, or known to, the server.

**Remote revocation — resolved in 1.2.** The actual risk isn't the PIN in isolation, it's a *lost device*. So instead of making PIN validation server-side (which would break offline staff login entirely), the owner gets a remote safety valve: `POST /v1/devices/{id}/revoke` (owner only, dashboard or POS). This invalidates that device's refresh token server-side immediately. The device itself keeps working offline until it next attempts to sync or refresh — at that point it's rejected and forced back to the login screen, which requires the owner's credentials, not the staff PIN, to re-authenticate. This doesn't revoke the PIN, but it kills the lost device's ability to do anything once it touches the network again, which is the actual threat being mitigated.

---

## 3. Devices

### 3.1 `GET /v1/devices`

Owner, dashboard. Lists all devices ever registered.

### 3.2 Setting the active POS — not an endpoint

**Corrected in 1.3.** Versions up to 1.2 listed `POST /v1/sync/device/activate` here. That endpoint is removed: marking a device as the active POS is the **`DEVICE_ACTIVATED` queue event** (§5), submitted through `POST /v1/sync/events` like every other write.

Three independent reasons, all of which already existed in the surrounding design:

1. **It contradicted §1.1.** That section permits exactly two non-event writes — auth and device rename. A third REST write for device activation was never covered by that carve-out.
2. **It could not do the job.** `SYNC-PROTOCOL.md` §5.2 requires failover to complete with "no internet required at any step." A synchronous REST call cannot satisfy that; a queued event can, which is why §5.3 of that document describes activation as an event that flushes when connectivity returns.
3. **It was never actually specified.** The old entry pointed at `SYNC-PROTOCOL.md` §5.3 for its definition, but that section defines an event and no endpoint — the reference was dangling.

The dashboard is still notified live: §11.2's `device.activated` fires when the `DEVICE_ACTIVATED` event is applied.

### 3.3 `PATCH /v1/devices/{id}`

Owner. Rename only: `{ "name": "string" }`. This is the one non-auth REST write that survives — it's device metadata, not a business record, and doesn't need offline availability (renaming a device from Thailand requires connectivity anyway).

### 3.4 `POST /v1/devices/{id}/revoke`

**New in 1.2.** Owner only. Immediately invalidates the target device's refresh token server-side (denylist by token ID, same mechanism as logout, §2.3). The device is not contacted — it simply fails its next `/v1/auth/refresh` or sync call and falls back to the login screen. This is the resolution to §15 item 3 (lost staff device) — see §2.4.

---

## 4. Reads: Categories, Products, Sales, Expenses, Suppliers

**All writes to these entities are events (§9), not REST calls.** The endpoints below are `GET`-only — used by the dashboard for monitoring, and by the POS app only in edge cases like first-run pull (`DATA-MODEL.md` §7) where a fast, filterable read is more convenient than replaying the sync-pull stream. The Flutter app's day-to-day reads come from local SQLite, not these endpoints.

### 4.1 `GET /v1/categories`

Owner, staff, dashboard. `include_deleted` (owner/dashboard only).

### 4.2 `GET /v1/products`

Owner, staff, dashboard. Filters: `category_id`, `is_active`, `low_stock_only`, `q`. Includes `computed_stock` joined in.

### 4.3 `GET /v1/products/{id}`

Owner, staff, dashboard.

### 4.4 `GET /v1/products/{id}/inventory-events`

Owner, dashboard only. Paginated audit trail — the "who sold what, when" screen.

### 4.5 `GET /v1/sales`

Owner, staff (own sales only, filtered server-side on `operator_id`), dashboard. Filters: `date_from`, `date_to`, `status`, `product_id`, `operator_id` (owner/dashboard only). Date filters resolve against `SHOP_TIMEZONE` (§1.7).

### 4.6 `GET /v1/sales/{id}`

Owner, staff (own only), dashboard. Includes nested `sale_items`.

### 4.7 `GET /v1/expenses`

Owner, dashboard only — not staff. Filters: `date_from`, `date_to`, `category`.

### 4.8 `GET /v1/suppliers`, `GET /v1/supplier-orders`

Owner, dashboard. Standard filtered reads.

---

## 5. Event types submitted via the sync queue

**New in 1.1.** This replaces §4–§8 of the v1.0 draft (the direct write endpoints). All of these are `event_type` values inside the existing `POST /v1/sync/events` envelope from `SYNC-PROTOCOL.md` §9 — not new endpoints. Documented here so the full set of event types lives in one place alongside the REST spec, rather than being scattered.

| Event type | Role | Notes |
|---|---|---|
| `CATEGORY_CREATED` / `CATEGORY_UPDATED` / `CATEGORY_DELETED` | Owner | LWW. Delete is soft (`deleted_at`). **Resolved in 1.2:** `CATEGORY_DELETED` is rejected with `CONFLICT` if any non-deleted product still references the category — returned in `rejected[]` as `CATEGORY_HAS_PRODUCTS` with `detail.blocking_product_count` (§6.1). The owner must reassign or deactivate those products first — a few seconds of friction that prevents orphaned `category_id` references from showing up confusingly in reports later. |
| `PRODUCT_CREATED` / `PRODUCT_UPDATED` / `PRODUCT_DELETED` | Owner | LWW per `SYNC-PROTOCOL.md` §4. `id` is client-generated. |
| `INVENTORY_ADJUSTED` / `INVENTORY_DAMAGED` | Owner | `note` field **required** — an unexplained stock change becomes a mystery weeks later. A missing `note` is a permanent rejection, `EVENT_VALIDATION_FAILED` (§6.1). |
| `SALE_CREATED` | Owner, staff | Carries the sale + its `sale_items` in one event payload. Always submitted as part of a **group** with its inventory events — see §6. **`sale_number` collision handling resolved in 1.2:** `sale_number` (e.g. `S-00142`) is a client-generated, display-only label with **no uniqueness guarantee**. The UUID `id` is the real primary key everywhere it matters (line items, receipts, void references, sync idempotency). If the tablet and phone each generate `S-00142` while both offline, it is cosmetically confusing on a printed receipt but never a data-integrity issue — nothing in the system looks up a sale by `sale_number`. A device-prefixed or server-issued sequence was considered and rejected as unnecessary complexity for a cosmetic concern at this scale. |
| `SALE_VOIDED` | Owner only | Rejected with `CONFLICT` if outside the same shop-day as the original sale's `server_received_at` (`DATA-MODEL.md` §3.6, §1.7) — returned in `rejected[]` as `VOID_WINDOW_CLOSED` (§6.1), and the device reverts its local void (`SYNC-PROTOCOL.md` §4.4). Generates the group's `INVENTORY_VOIDED` events. Role checked server-side even though the app UI hides the void action from staff — never trust the client. |
| `EXPENSE_CREATED` / `EXPENSE_UPDATED` / `EXPENSE_DELETED` | Owner | LWW, soft delete. |
| `SUPPLIER_CREATED` / `SUPPLIER_UPDATED` / `SUPPLIER_DELETED` | Owner | LWW, soft delete. |
| `SUPPLIER_ORDER_CREATED` / `SUPPLIER_ORDER_UPDATED` | Owner | Carries nested order items in the payload (no separate item-creation events). |
| `SUPPLIER_ORDER_RECEIVED` | Owner | **Device-originated**, not server-originated — see §7. Submitted as a group with its `INVENTORY_RESTOCKED` events. |
| `INVENTORY_SOLD` / `INVENTORY_VOIDED` / `INVENTORY_RESTOCKED` | (system-generated by app logic) | Already specified in `SYNC-PROTOCOL.md` §3.2. Always submitted grouped with the sale/void/receipt event that caused them (§6). |
| `DEVICE_ACTIVATED` | Owner | **Registered here in 1.3** — previously described only in `SYNC-PROTOCOL.md` §5.3 and mistakenly also exposed as a REST endpoint (see §3.2). Marks the submitting device as the active POS. Standalone event: `reference_id` is NULL. Queued offline and flushed on reconnect, so failover never needs connectivity. Drives §11.2's `device.activated` push. |

---

## 6. Atomic event groups

**New in 1.1 — fixes a real gap in v1.0.**

**Problem:** A sale generates one `SALE_CREATED` event plus one `INVENTORY_SOLD` event per line item. Batches are capped at 50 events (`SYNC-PROTOCOL.md` §10). A device recovering from a long offline period sends multiple sequential batches. If a sale event and its own inventory events land in *different* batches, and the device loses connectivity or crashes between those two requests, the server briefly has a recorded sale with no matching stock deduction — and a WebSocket `sale.created` push could fire before stock has actually moved, momentarily misreporting `stock.low` / `stock.negative` on the dashboard.

**Fix:**

1. Every event carries the `reference_id` field already defined in `DATA-MODEL.md` §3.5. A **group** is the set of all events sharing one `reference_id` (one sale + its inventory events; one void + its reversal events; one supplier receipt + its restock events).
2. The queue flusher **never splits a group across a batch boundary**. If adding a full group would exceed 50 events or the 5MB payload limit, that group is deferred whole to the next batch. This rule is mirrored in `SYNC-PROTOCOL.md` §2.5, which governs the device-side flusher.
3. Server-side, `POST /v1/sync/events` applies each group inside a single PostgreSQL transaction: the sale (or void, or receipt) and all of its inventory events commit together or not at all. A partial-group failure rolls back the whole group and returns it as unaccepted, to be **retried** by the device like any other transient failure — this is distinct from a permanent business-rule rejection, which is never retried (§6.1).
4. The WebSocket `sale.created` event (§11.2) fires only after the group's transaction commits — never after just the sale row is inserted.

This closes the "sale exists but stock hasn't moved" window completely, rather than relying on idempotent retries to self-heal it eventually.

### 6.1 Permanently rejected events

**New in 1.3.** Versions 1.1 and 1.2 introduced business rules that the server enforces and the device cannot evaluate offline (`CATEGORY_DELETED` blocked by products; `SALE_VOIDED` outside the shop-day; owner-only events submitted under a staff PIN, §1.6). What was missing was the other half of the contract: how the device *learns* the event was refused, and how it distinguishes "refused forever" from "try again later". Without that distinction, a device that had already applied the change locally would either retry forever or drop it silently and stay permanently diverged from the server.

This section defines the **server side** of that contract. The device-side reconciliation — what it reverts and how it tells the owner — is specified in `SYNC-PROTOCOL.md` §4.4 and is not repeated here. Note that the device side is not fully settled: reverting a local write to the append-only `inventory_events` log is an open decision (`SYNC-PROTOCOL.md` §11.1), which affects three of the four reason codes below. Nothing in *this* section depends on how that is resolved — the server's behaviour and the wire format are unaffected either way.

#### Transient vs permanent

`POST /v1/sync/events` returns **HTTP 200 whenever the batch was processed at all**, with per-event outcomes in the response body. This has to be so: a 50-event batch may contain 49 acceptances and one rejection, and a single HTTP status cannot express that. Accordingly:

- **A non-200 status means the whole batch failed** and nothing in it was applied — `401` (§1.3), `413` (§1.5), `429` (§12), `500`. The device keeps every event queued and retries on its normal schedule.
- **The `CONFLICT` / `409` code in §1.5 describes a per-event outcome, not the batch's HTTP status.** It appears as a `reason` inside the body. A batch is not failed just because one event in it was rejected.

#### Response array

Permanently rejected events are returned in a `rejected[]` array, alongside the existing `accepted[]`, `conflicts[]`, and `stock_corrections[]` (`SYNC-PROTOCOL.md` §9):

```json
"rejected": [
  {
    "id": "evt_004",
    "reference_id": "sale_789xyz",
    "reason": "VOID_WINDOW_CLOSED",
    "message": "This sale can no longer be cancelled.",
    "detail": { }
  }
]
```

`rejected[]` is deliberately **not** merged into `conflicts[]`. A conflict carries a `winning_payload` for the device to adopt (`SYNC-PROTOCOL.md` §4.2); a rejection has no winning version, because the server applied nothing — the device must undo its own write instead. Collapsing the two would force the device to inspect `resolution` values to work out which of two opposite actions to take.

- `message` is plain language and safe to show the owner directly, per §1.4's error conventions and the project's "never show a raw exception" rule.
- `reference_id` is present when the rejected event belongs to a group. **The whole group is rejected together** — §6 already applies each group in one transaction, so a group is accepted or rejected as a unit, never partially.
- `detail` carries reason-specific fields and is `{}` when there are none.

#### Reason codes

| `reason` | Raised by | `detail` | Why retrying cannot help |
|---|---|---|---|
| `CATEGORY_HAS_PRODUCTS` | `CATEGORY_DELETED` (§5) | `{ "blocking_product_count": n }` | Products still reference the category. Nothing changes until the owner reassigns them, which is a new action, not a retry. |
| `VOID_WINDOW_CLOSED` | `SALE_VOIDED` (§5) | `{ }` | The shop-day boundary (§1.7) has passed and only moves further away with time. |
| `ROLE_NOT_PERMITTED` | Any owner-only event under a `staff` PIN (§1.6), or any mutating event under a `dashboard_viewer` token (§1.8) | `{ }` | The submitter's role will not change by resending. |
| `EVENT_VALIDATION_FAILED` | `INVENTORY_ADJUSTED` / `INVENTORY_DAMAGED` missing the required `note` (§5) | `{ "field": "note" }` | The payload is already in the queue as written; resending sends the same invalid payload. |

This list is closed: **a server may only reject an event permanently for a reason listed here.** Any new permanent-rejection rule must add its code to this table in the same change that implements it, so the device always has a defined revert path (`SYNC-PROTOCOL.md` §4.4 — subject to §11.1 for reasons that touch inventory). Anything else that goes wrong is transient by definition and must be retried, not rejected.

---

## 7. Supplier order receipt — device-originated, not server-originated

**New in 1.1 — fixes the attribution gap in v1.0.**

v1.0 had the *server* generate `INVENTORY_RESTOCKED` events when a supplier order's status flipped to `received` via a REST `PATCH`. That broke the "device always originates events" invariant everywhere else in the system, left `device_id`/`operator_id` on those events ambiguous, and needed an awkward reconciliation path back down to the originating device via `/v1/sync/pull`.

**Fix:** Marking an order received is a device-originated action like everything else — the owner may do this offline when a delivery truck arrives with no signal. The **device** (which already has the order's line items locally) computes the resulting `INVENTORY_RESTOCKED` events itself and submits `SUPPLIER_ORDER_RECEIVED` + its restock events as one atomic group (§6), with real `device_id` and `operator_id` values throughout. Nothing needs to flow back down to the originating device — it already applied the change locally before syncing, exactly like a sale.

---

## 8. Reports

Owner + dashboard only, not staff. All date-bounded reports resolve against `SHOP_TIMEZONE` (§1.7).

### 8.1 `GET /v1/reports/daily-summary`

`date` param (default: today in `SHOP_TIMEZONE`). Revenue, profit (if cost prices present), transaction count, top products, `incomplete_profit` flag.

### 8.2 `GET /v1/reports/range`

`date_from`, `date_to`, `group_by` (`day`/`week`/`month`). Time series for dashboard charts.

### 8.3 `GET /v1/reports/low-stock`

Products where `computed_stock <= low_stock_threshold`.

### 8.4 `GET /v1/reports/staff-activity`

Owner, dashboard only. Sales count/value by `operator_id`.

**Staff-operated device gating — resolved in 1.2.** All of §8 (reports) and §4.7 (expenses) is gated by the **active PIN user**, not the device's underlying JWT role. A tablet may hold an owner-scoped JWT, but if a staff PIN is currently active on it, the app hides reports and expenses entirely — the server also enforces this by requiring the current `operator_id` (set by the active PIN) to carry `role: owner` on these endpoints, not just the device token. This matches intent (owner-only data) rather than the technicality (device happens to hold an owner-scoped token) — a staff member minding the shop can't open the owner's report screen just because they're on the primary tablet.

---

## 9. Sync (reference)

| Method | Path | Spec location |
|---|---|---|
| `POST` | `/v1/sync/events` | `SYNC-PROTOCOL.md` §9, extended by §6/§6.1/§7 of this doc (grouping, atomicity, rejection) |
| `GET` | `/v1/sync/pull` | `SYNC-PROTOCOL.md` §9 |

`POST /v1/sync/device/activate` was removed in 1.3 — see §3.2.

**Cross-doc dependency — resolved.** The group-batching rule from §6 was carried into `SYNC-PROTOCOL.md` §2.5 in that document's version 1.1, and its §2.3 and §10 now both reference it. An engineer implementing the flusher from `SYNC-PROTOCOL.md` alone will no longer miss it.

---

## 10. Dashboard overview

### 10.1 `GET /v1/dashboard/overview`

Owner, dashboard. Combined response: today's revenue, active device, sync status per device, low-stock count — one call instead of four, deliberately, given a possibly weak connection on the shop's end.

---

## 11. WebSocket

*Dashboard only, per `ARCHITECTURE.md` §6.*

### 11.1 Connection

`wss://api.g9pos.com/ws?token=<access_token>` — query param, not header, since browser WebSocket clients can't set custom handshake headers. Invalid/expired token → refused before upgrade.

### 11.2 Events (server → client)

| Event | Payload | Fires when |
|---|---|---|
| `sale.created` | `{ sale }` | A sale's event group commits (§6) — never before |
| `sale.voided` | `{ sale_id, void_reason }` | A void's event group commits |
| `stock.low` | `{ product_id, computed_stock, threshold }` | A committed event group pushes a product at/below threshold |
| `stock.negative` | `{ product_id, computed_stock }` | A committed event group pushes a product below zero |
| `device.sync_status` | `{ device_id, last_sync_at }` | Any device completes a sync |
| `device.activated` | `{ device_id }` | `DEVICE_ACTIVATED` event received |

### 11.3 Fallback

Poll `GET /v1/sync/pull` every 30 seconds if the socket drops.

**Reconnect backoff — resolved in 1.2.** Standard exponential backoff on the dashboard client: 1s → 2s → 4s → 8s, capped at 30s, reset to 1s on a successful reconnect. Applies per client; harmless at the documented cap of 3 concurrent WebSocket connections/user (§12).

### 11.4 No client → server events

Receive-only from the dashboard. No write path exists here, consistent with §1.1 — flagged so nobody adds a shortcut WS write handler later.

---

## 12. Rate Limiting

| Scope | Limit |
|---|---|
| `/v1/auth/login` | 5 req/min/IP |
| `/v1/sync/events` | 60 req/min/device |
| All other authenticated endpoints | 300 req/min/user |
| WebSocket connections | 3 concurrent/user |

Enforced at Nginx per `ARCHITECTURE.md` §9.

---

## 13. Resolved Decisions

| Decision | Resolution |
|---|---|
| Write path | Sync queue only. No direct REST write endpoints for any business entity — auth and device-rename are the sole exceptions. |
| Same-day void | Fixed `SHOP_TIMEZONE` (Asia/Yangon) constant, calendar-day boundary against `server_received_at` — not a rolling 24h window. |
| Sale/inventory atomicity | Grouped by `reference_id`, never split across a sync batch, applied in one DB transaction per group. |
| Supplier order receipt | Device-originated event group, not server-originated. |
| Pagination | Cursor-based on all list endpoints. |
| Response envelope | `{ data, meta }` / `{ error, meta }`, always includes `request_id`. |
| API versioning | Path-based (`/v1`), breaking changes get a new version. |
| Staff visibility | Own sales only; no access to expenses or reports at all — enforced by active PIN user, not device JWT. |
| WebSocket auth/direction | Query-param token; server → dashboard only, no client writes. |
| Dashboard identity | Separate `dashboard_viewer` role/token via `login_context: "dashboard"` on the same login endpoint — never the owner role. |
| Login lockout | 5 failed attempts locks the account 15 minutes, on top of 5/min/IP. No self-service password reset. |
| Lost staff device | Owner can remotely revoke a device's refresh token (`POST /v1/devices/{id}/revoke`); PIN itself stays on-device. |
| Category deletion | Blocked (`CONFLICT`) while any active product still references the category. |
| Sale number uniqueness | `sale_number` is a display-only label with no uniqueness guarantee; UUID `id` is the real key. |
| WebSocket reconnect | Exponential backoff, 1s→30s cap, reset on success. |
| Reports/expenses gating | Gated by active PIN user's role, not the device's underlying JWT. |
| Response envelope authority | §1.4 is binding. No lower-authority document or helper may define an alternative shape (added 1.3). |
| Permanent rejection contract | `rejected[]` array with a closed set of `reason` codes; batch still returns 200; device reverts its local write per `SYNC-PROTOCOL.md` §4.4 — see §6.1 (added 1.3). |
| Batch HTTP status | `POST /v1/sync/events` returns 200 whenever the batch was processed; per-event outcomes live in the body. Non-200 means the entire batch failed and is retried (added 1.3). |
| Device activation | `DEVICE_ACTIVATED` queue event, not a REST endpoint — see §3.2 (added 1.3). |

---

## 14. Follow-up needed in other docs — none outstanding

**Cleared in 1.3.** Both items previously listed here are done:

- `SYNC-PROTOCOL.md` §2.3/§10 now describe event-group batching — carried into §2.5 of that document in its version 1.1.
- `DATA-MODEL.md` now documents the `SHOP_TIMEZONE` constant and the fields that resolve against it — added as §1.1 in its version 1.1.

This pass introduced one new cross-document dependency, which is already satisfied: §6.1 (server-side rejection contract) is paired with `SYNC-PROTOCOL.md` §4.4 (device-side revert). Neither is complete without the other, so a change to the `reason` codes in §6.1 requires reviewing §4.4's revert table.

---

## 15. Open Questions — none remaining

All 7 items originally listed here (dashboard identity, login lockout, staff PIN revocation, category deletion orphans, offline sale-number collisions, WebSocket reconnect backoff, staff-device report gating) are resolved as of 1.2. Each resolution is documented inline at its relevant section (§1.8, §2.1, §2.4/§3.4, §5, §5, §11.3, §8.4 respectively) and summarized in §13.

---

## 16. Next Documentation

| Document | Status | Purpose |
|---|---|---|
| `SYNC-PROTOCOL.md` | ✅ Done — v1.4, 2 open decisions in its §11 | Sync design, failover, conflict resolution, rejection reconciliation (§4.4) |
| `DATA-MODEL.md` | ✅ Done — v1.4, 3 open decisions in its §9 | Database schema for SQLite and PostgreSQL |
| `ARCHITECTURE.md` | ✅ Done — v1.2 | System architecture |
| `API-SPEC.md` | ✅ Done — v1.4, 0 open questions | This document |
| `HARDWARE-INTEGRATION.md` | ✅ Complete — v1.0 | Scanner, printer protocols and Flutter integration |
| `UI-GUIDELINES.md` | 🟡 Written at v1.0 — 3 gaps | Design rules for non-technical users. See `SYNC-PROTOCOL.md` §11.2. |
| `CODING-STANDARDS.md` | 🟡 Written at v1.1 — **§5.8 does not conform to §1.4** | Repo layout, layering, naming, testing. See the conformance table in §1.4. |
| `REQUIREMENTS.md` | 🔲 Not written | Formal in-scope / out-of-scope for v1 |

**What 🟡 means in this table.** `CODING-STANDARDS.md` (v1.1) and `UI-GUIDELINES.md` (v1.0) are written in full at those versions, but reconciliation against them is still outstanding — where a row above names conformance fixes or gaps, those items are open, and for `CODING-STANDARDS.md` the §1.4 conformance table is that list. Treat 🟡 as "written, reconciliation outstanding", not as a completion mark.