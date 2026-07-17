# G9POS Sync Protocol

**Version:** 1.1
**Status:** Draft
**Last updated:** 2026-07-18
**Author:** Architecture Team

**Changelog since 1.0:** Added §2.5 (event-group batching) to reflect the atomicity rule defined in `API-SPEC.md` §6 — a sale/void/supplier-receipt and its related inventory events are now grouped by `reference_id` and never split across a sync batch or a retry. This document previously described plain 50-event batching with no grouping concept; that was a real gap where a sale event and its own stock-deduction events could land in different HTTP requests.

---

## 1. Overview & Design Philosophy

MotoPOS operates in an environment where internet connectivity and electricity are unreliable. The sync protocol is designed around one core principle:

> **The POS must always work. Sync is a background concern, not a dependency.**

All sales, inventory changes, and data entry happen locally on the device first. The backend is the eventual source of truth, not the operational dependency.

### Core rules

1. Never block a sale or stock update waiting for network.
2. Every write goes to local SQLite first, server second.
3. Inventory stock is never stored as a raw number — only as a log of events.
4. Conflicts are resolved by the server, not the device.
5. Any authenticated device must be able to operate fully offline indefinitely.

---

## 2. Sync Architecture

### 2.1 Queue-based sync

Every data change the device makes is written to a local **sync queue** in SQLite before being sent to the server. The queue is flushed over HTTP REST whenever connectivity is detected.

```
[User action]
     │
     ▼
[Write to local SQLite]   ← always succeeds immediately
     │
     ▼
[Append to sync_queue]    ← serialized, idempotent event
     │
     ▼
[Return success to UI]    ← user sees instant feedback
     │
     ▼ (async, background)
[Flush queue to server]   ← retried until confirmed
     │
     ▼
[Server applies, responds]
     │
     ▼
[Mark queue item as synced]
```

### 2.2 Sync queue table (SQLite)

```sql
CREATE TABLE sync_queue (
  id            TEXT PRIMARY KEY,        -- UUID v4, idempotency key
  event_type    TEXT NOT NULL,           -- e.g. INVENTORY_SOLD, PRODUCT_UPDATED
  payload       TEXT NOT NULL,           -- JSON blob
  device_id     TEXT NOT NULL,
  reference_id  TEXT,                    -- groups related events (see §2.5); NULL for standalone events
  created_at    INTEGER NOT NULL,        -- Unix timestamp (ms)
  synced_at     INTEGER,                 -- NULL until confirmed by server
  retry_count   INTEGER DEFAULT 0,
  last_error    TEXT
);
```

### 2.3 Retry logic

| Attempt | Delay before retry |
|---------|-------------------|
| 1st     | immediate          |
| 2nd     | 5 seconds          |
| 3rd     | 30 seconds         |
| 4th+    | 5 minutes          |

Items are never deleted from the queue until the server returns HTTP 200 or 409 (conflict resolved). On app restart, all unsynced items are re-queued automatically.

**Note:** retries are applied per **group** (§2.5), not per individual event, when `reference_id` is set. If a group fails, every event in that group retries together on the same schedule — a partial retry (some events in a group succeeding, others not) is not possible by design.

### 2.4 Connectivity detection

Flutter uses `connectivity_plus` to detect network state. On connectivity change from offline → online, the queue flusher is triggered immediately. The flusher also runs on a 60-second polling interval as a fallback.

### 2.5 Event-group batching (added in 1.1)

*Full rationale in `API-SPEC.md` §6 — summarized here so the flusher can be implemented from this document alone.*

Some events are causally linked: a sale and the `INVENTORY_SOLD` events it generates for each line item; a void and its `INVENTORY_VOIDED` reversal events; a supplier order receipt and its `INVENTORY_RESTOCKED` events. These share one `reference_id`.

**Batching rule:** when the flusher builds a batch of events to send in `POST /v1/sync/events`, it treats every set of events sharing a `reference_id` as a single indivisible unit.

- A group is never split across two batches. If adding a full group to the current batch would exceed 50 events or the 5MB payload limit (§10), that batch is sent as-is and the group starts the next batch instead.
- Standalone events (no `reference_id` — e.g. a `PRODUCT_UPDATED`) are batched normally, filling in around whole groups.
- Server-side, each group is applied inside a single database transaction — see `API-SPEC.md` §6 for the server-side contract. This document only governs how the device builds and retries batches.

This exists because without it, a sale event and its stock-deduction events could land in different HTTP requests, creating a window where a sale is recorded server-side with no matching stock movement — see `API-SPEC.md` §6 for the full failure scenario this closes.

---

## 3. Inventory Event Log

Inventory stock is **never synced as a raw number**. Instead, every change to stock is recorded as an immutable event. The server computes current stock as the sum of all events.

### 3.1 Why event log?

If two devices both go offline and each sell one unit of the same item, syncing "stock = 47" from both would silently corrupt data — one write would overwrite the other. Syncing events `SOLD 1 unit` and `SOLD 1 unit` is unambiguous: stock decreases by 2. The server applies both correctly regardless of sync order.

### 3.2 Event types

| Event type            | Description                          |
|-----------------------|--------------------------------------|
| `INVENTORY_SOLD`      | Units sold in a transaction          |
| `INVENTORY_RESTOCKED` | Units added (from supplier delivery) |
| `INVENTORY_ADJUSTED`  | Manual correction by owner           |
| `INVENTORY_RETURNED`  | Units returned by customer           |
| `INVENTORY_DAMAGED`   | Units removed due to damage/loss     |

### 3.3 Event payload format

```json
{
  "id": "evt_01J2KX8MNPQ3RSTU4VWXY5Z6A",
  "event_type": "INVENTORY_SOLD",
  "device_id": "device_tablet_primary",
  "product_id": "prod_abc123",
  "quantity_delta": -2,
  "reference_id": "sale_789xyz",
  "note": null,
  "created_at": 1720512345678,
  "operator_id": "user_owner"
}
```

- `quantity_delta` is always signed: negative for reductions, positive for additions.
- `reference_id` links the event to the sale, restock, or manual adjustment that caused it, and is also the batching/grouping key described in §2.5.
- `id` is the idempotency key — if the same event is submitted twice, the server ignores the duplicate.

### 3.4 Stock computation (server-side)

```sql
SELECT
  product_id,
  SUM(quantity_delta) AS current_stock
FROM inventory_events
WHERE product_id = $1
GROUP BY product_id;
```

The device caches a `computed_stock` locally for display purposes, recomputed after each sync.

---

## 4. Conflict Resolution Rules

### 4.1 Inventory events — no conflict possible

Because inventory uses an append-only event log, two devices making concurrent offline changes cannot conflict. Both event streams are appended to the server log in timestamp order. Stock is always correct.

**Edge case — stock goes negative:** This can happen if two devices each sell the last unit offline. The events are both valid and both applied. The server flags the product as `stock_negative = true` and includes it in the next sync response, so the device can alert the owner. The events are not rolled back — the sale already happened.

### 4.2 Other fields — Last-Write-Wins (LWW)

For non-inventory data (product names, prices, supplier details, expense records), the rule is:

> **The event with the later `created_at` timestamp wins. Server is the tiebreaker.**

If two devices submit conflicting updates with identical timestamps (extremely rare), the server keeps the version it received first and discards the second, returning a `409 Conflict` response with the winning version so the device can update its local copy.

### 4.3 LWW payload format

```json
{
  "id": "upd_01J2KX9ABCDEFGHIJKLMN0PQR",
  "event_type": "PRODUCT_UPDATED",
  "device_id": "device_phone_standby",
  "entity_type": "product",
  "entity_id": "prod_abc123",
  "fields": {
    "name": "Yamaha Oil Filter YZ250",
    "price_mmk": 8500,
    "barcode": "8850999012345"
  },
  "created_at": 1720512400000
}
```

---

## 5. Device Failover: Tablet → Phone

The shop runs one primary device (tablet) and one hot-standby device (phone). If the tablet is unavailable, the phone becomes the POS immediately — no reconfiguration, no waiting for a sync.

### 5.1 What makes failover instant

- The phone runs the same Flutter app, permanently installed.
- The phone is always logged in (JWT cached locally — see Section 6).
- The phone syncs in the background whenever it has connectivity, so its local SQLite is never more than a few hours stale.
- Because inventory uses event logs, the phone's local stock figures are independently valid even if they haven't received the last few transactions from the tablet.

### 5.2 Failover procedure (from the owner's perspective)

1. Pick up the phone.
2. Open MotoPOS — it loads immediately from local data.
3. Tap "Set as active device" in the settings menu (one tap).
4. Continue selling.

No internet required at any step.

### 5.3 What "Set as active device" does technically

- Sets `is_active_pos = true` in local preferences.
- Begins generating new sale and event IDs using the phone's `device_id` (`device_phone_standby`).
- Starts the sync queue flusher as a foreground service.
- Sends a `DEVICE_ACTIVATED` event to the server queue (flushed when connectivity returns), so the server and dashboard know which device is currently the active POS.

### 5.4 When the tablet comes back

- Tablet syncs its pending queue to the server.
- Server merges all events from both device timelines.
- Tablet receives the phone's transactions in the sync response and applies them to local SQLite.
- Owner taps "Set as active device" on the tablet to switch back.
- Phone resumes standby/background sync mode.

No data is lost. No manual reconciliation needed.

---

## 6. Offline JWT Caching Strategy

### 6.1 How it works

On successful login, the server issues:
- A **short-lived access token** (15 minutes, used for API calls)
- A **long-lived refresh token** (30 days, used to get new access tokens)

Both are stored in Flutter's `flutter_secure_storage` (AES-encrypted on Android).

### 6.2 Offline authentication flow

```
App starts
    │
    ├─ Has valid access token in secure storage?
    │      └─ Yes → load app, no network needed
    │
    ├─ Access token expired, has refresh token?
    │      ├─ Online → call /auth/refresh → get new access token → load app
    │      └─ Offline → use cached user identity, skip token refresh
    │             └─ Mark pending_token_refresh = true
    │             └─ Load app from local SQLite normally
    │
    └─ No refresh token (logged out or first install)
           └─ Show login screen (requires network)
```

### 6.3 Security trade-off

Allowing an expired access token to operate offline is a deliberate decision for this context. The shop is operated by one known person. The risk of token abuse in a single-operator shop is negligible compared to the risk of the shop being unable to operate during a power/internet outage.

Refresh tokens are rotated on every use when online. If a refresh token is older than 30 days and the device has never been online in that period, the owner must log in again once connectivity returns.

**Remote revocation:** the owner can force this state early from the dashboard via `POST /v1/devices/{id}/revoke` (see `API-SPEC.md` §3.4) — this invalidates the device's refresh token server-side immediately, without waiting for natural 30-day expiry. Used when a device is lost or stolen.

### 6.4 Token storage

```
flutter_secure_storage keys:
  motopos_access_token      → JWT string
  motopos_refresh_token     → JWT string
  motopos_user_id           → string
  motopos_user_role         → string (owner | staff)
  motopos_device_id         → string (set once on first install, never changes)
  motopos_token_expires_at  → Unix timestamp (ms)
```

---

## 7. Sync Scenarios

### Scenario A — Normal operation (online shop)

1. Sale is recorded → `INVENTORY_SOLD` event written to SQLite + sync queue.
2. Within seconds, queue flusher sends event to server.
3. Server applies event, returns `200 OK` with updated computed stock.
4. Device marks queue item synced, updates local cached stock.

### Scenario B — Offline sale, later sync

1. Internet is down. Sale is recorded → event written to SQLite + sync queue.
2. Queue flusher detects no connectivity. Event stays in queue.
3. Power and internet return. Queue flusher wakes up.
4. All queued events sent to server in chronological order, grouped per §2.5.
5. Server applies all events, returns updated state.
6. Device updates local cache. Dashboard shows current state.

### Scenario C — Tablet fails mid-day, phone takes over

1. Tablet battery dies at 2pm. It has 3 unsynced sales in its queue.
2. Owner switches to phone. Phone's last sync was at 1:45pm — missing those 3 sales.
3. Owner sells normally on phone. All new sales go into phone's queue.
4. Tablet is charged at 6pm. App starts, immediately flushes its 3-sale queue to server.
5. Phone syncs, receives tablet's 3 sales in sync response, applies to local SQLite.
6. Both devices now have complete records. Reports are accurate.

### Scenario D — Conflict on product price update

1. Owner updates product price on tablet (offline): `price = 8500 MMK, created_at = T1`.
2. Owner also updates price on phone (offline): `price = 9000 MMK, created_at = T2` where T2 > T1.
3. Both sync when online. Server receives both.
4. Server applies T2 (later timestamp wins): price = 9000 MMK.
5. Tablet receives `409` with winning version, updates local copy to 9000 MMK.

### Scenario E — First-run / new device setup

1. New device installs app.
2. Owner logs in (requires internet for initial auth).
3. Server issues JWT pair. Device stores tokens.
4. Full data pull: server sends all products, current computed stock levels, recent sales history (last 90 days).
5. Device is now ready for offline use.

### Scenario F — Sale with many line items, large offline backlog (added in 1.1)

1. Device has been offline for a week; queue has 600+ events including a 12-item sale.
2. Owner's tablet reconnects. Flusher begins batching per §2.5.
3. The 12-item sale's `SALE_CREATED` event + 12 `INVENTORY_SOLD` events (13 events total, one `reference_id`) are kept together as one group.
4. If the current batch already has 40 other unrelated events queued, the flusher does not split the group to fill the batch to 50 — it sends the batch at 40 and starts the sale group fresh in the next batch.
5. Server applies the entire group in one transaction. Either all 13 events commit, or none do.
6. No window exists where the sale is recorded but stock hasn't moved.

---

## 8. Error Handling & Edge Cases

### Negative stock

- Applied as-is. Not blocked.
- Server sets `stock_negative = true` on the product.
- Next sync response includes the flag.
- App shows a warning badge on that product in the inventory list.
- Owner decides whether to adjust (manual `INVENTORY_ADJUSTED` event).

### Duplicate event submission

- Every event has a UUID `id` field (idempotency key).
- Server checks `id` before inserting. If duplicate: returns `200 OK` with existing result, ignores the new payload.
- Safe to retry any event any number of times.

### Queue grows too large (extended offline period)

- No hard limit on queue size (SQLite can handle thousands of events).
- If queue exceeds 500 items, app shows a subtle "X items pending sync" indicator in the header.
- On sync, events are sent in batches of 50 to avoid large request payloads, respecting group boundaries per §2.5.

### Clock skew between devices

- Device clocks in Myanmar may drift, especially if device has been offline.
- Server records `server_received_at` in addition to `created_at` from the device.
- For LWW conflict resolution, `created_at` (device clock) is used as the primary sort key.
- If `created_at` delta between two conflicting events is < 5 seconds, server uses `server_received_at` as tiebreaker to handle clock skew cases.
- For "same calendar day" business rules (e.g. sale void window), the system does not use device clock at all — see `API-SPEC.md` §1.7 for the fixed-shop-timezone rule.

### Server is unreachable for 30+ days (extreme case)

- Local JWT refresh token expires.
- Owner must log in once when connectivity returns.
- All queued events are preserved in SQLite — they do not expire.
- After re-authentication, normal sync resumes and all events flush.

---

## 9. API Endpoints (Sync-related)

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/v1/sync/events` | Submit a batch of queued events |
| `GET`  | `/v1/sync/pull`   | Pull changes from server since last sync |
| `POST` | `/v1/auth/refresh` | Refresh access token |
| `POST` | `/v1/sync/device/activate` | Mark a device as the active POS |

Full request/response contracts, error codes, and role rules for these endpoints are specified in `API-SPEC.md` §9 — this table is a pointer, not the source of truth for wire format.

### POST /v1/sync/events

Request:
```json
{
  "device_id": "device_tablet_primary",
  "events": [
    { "id": "evt_...", "event_type": "INVENTORY_SOLD", ... },
    { "id": "evt_...", "event_type": "PRODUCT_UPDATED", ... }
  ]
}
```

Response:
```json
{
  "accepted": ["evt_001", "evt_002"],
  "conflicts": [
    {
      "id": "evt_003",
      "resolution": "server_version_wins",
      "winning_payload": { ... }
    }
  ],
  "stock_corrections": [
    { "product_id": "prod_abc", "computed_stock": -1, "stock_negative": true }
  ]
}
```

### GET /v1/sync/pull

Request params:
- `last_sync_at` — Unix timestamp of last successful pull
- `device_id`

Response: all server-side changes since `last_sync_at` that this device hasn't originated.

---

## 10. Resolved Decisions

| Decision | Resolution |
|----------|-----------|
| Maximum staleness for standby phone | 4 hours. Background sync runs every 2 hours when connectivity available. Orange warning shown if last sync exceeds 4 hours |
| Staff JWT offline grace period | Same as owner — no difference. Role restrictions are enforced via the local `role` flag, not token expiry |
| `SALE_VOIDED` event at launch | Yes — included at launch as `INVENTORY_VOIDED` event type. Same-day only, owner only. Same-day boundary now fixed to shop timezone, not device clock — see `API-SPEC.md` §1.7 |
| Batch size limit for `/v1/sync/events` | 50 events per request, 5MB max payload. Server returns `413 Payload Too Large` if exceeded. Queue flusher sends multiple sequential batches if queue exceeds 50 items, respecting event-group boundaries per §2.5 (added in 1.1) |
| Event-group batching | Added in 1.1 — see §2.5. Groups (by `reference_id`) are never split across batches or retried partially |
| Lost/stolen device | Owner can remotely revoke via `API-SPEC.md` §3.4, invalidating the refresh token before natural 30-day expiry (added in 1.1) |