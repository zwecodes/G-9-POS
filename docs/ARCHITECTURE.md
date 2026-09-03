# G9POS System Architecture

**Version:** 1.1  
**Status:** Draft  
**Last updated:** 2026-09-03  
**Author:** Architecture Team

**Changelog since 1.0:** Consistency pass; no architectural changes. (1) Added the missing `categories` feature and backend package to §5 and §6 — `API-SPEC.md` §5 defines `CATEGORY_CREATED`/`UPDATED`/`DELETED` events and `DATA-MODEL.md` §3.3 defines the table, but neither structure listed anywhere for them to live. (2) Added permanent-event-rejection handling to the §6 request flow and the §8 summary table, reflecting `API-SPEC.md` §6.1 and `SYNC-PROTOCOL.md` §4.4. (3) Rewrote §13, which still listed `api-spec.md` as "Next" long after it reached v1.3, and corrected every document filename to match the actual uppercase files.

**Scope note:** §5, §6, §8, §9 and §11 of this document are *summaries*. Where this document and a domain specification disagree, the specification wins — `API-SPEC.md` for endpoints and events, `DATA-MODEL.md` for schema, `SYNC-PROTOCOL.md` for sync and conflict behaviour, `HARDWARE-INTEGRATION.md` for hardware. The two sections that are authoritative here and nowhere else are §3 (device roles and the active-POS rule) and §10 (what the remote dashboard may and may not do).

---

## 1. Overview

G9POS is an offline-first POS and inventory management system for a single small motorcycle accessories shop in Pin Laung, Myanmar. The architecture is designed around three non-negotiable constraints:

1. **Power is unreliable** — the system must work on battery with no electricity
2. **Internet is unreliable** — every core operation must work with no connectivity
3. **The operator is non-technical** — the UI and failure modes must be self-evident

The backend exists to synchronize data between devices and provide a remote dashboard — it is never in the critical path of a sale.

---

## 2. System Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        PIN LAUNG SHOP                        │
│                                                             │
│  ┌─────────────────────┐    Bluetooth    ┌───────────────┐  │
│  │   Android Tablet    │◄──────────────►│ BT Scanner    │  │
│  │   (Primary POS)     │                └───────────────┘  │
│  │                     │    Bluetooth    ┌───────────────┐  │
│  │  Flutter + Drift    │◄──────────────►│ Receipt       │  │
│  │  SQLite (local DB)  │                │ Printer       │  │
│  │  Sync Queue         │                └───────────────┘  │
│  └──────────┬──────────┘                                   │
│             │ HTTP REST (when online)                       │
│             │ queued + retried when offline                 │
│  ┌──────────┴──────────┐                                   │
│  │   Android Phone     │                                   │
│  │   (Hot Standby)     │                                   │
│  │                     │                                   │
│  │  Flutter + Drift    │                                   │
│  │  SQLite (local DB)  │                                   │
│  │  Background Sync    │                                   │
│  └──────────┬──────────┘                                   │
│             │ HTTP REST (background sync)                   │
└─────────────┼───────────────────────────────────────────────┘
              │
              │ Internet (unreliable — all sync is queued)
              │
┌─────────────▼───────────────────────────────────────────────┐
│                      CLOUD BACKEND                           │
│                                                             │
│  ┌─────────────────┐     ┌─────────────────────────────┐   │
│  │   Go (Gin)      │     │        PostgreSQL            │   │
│  │   REST API      │     │                             │   │
│  │   WebSocket     │     │  products, sales, inventory  │   │
│  │   JWT Auth      │     │  events, users, devices      │   │
│  └────────┬────────┘     └─────────────────────────────┘   │
│           │ Docker + Nginx                                   │
│           │ DigitalOcean / Hetzner                          │
└───────────┼─────────────────────────────────────────────────┘
            │
            │ HTTPS + WebSocket
            │
┌───────────▼─────────────────────────────────────────────────┐
│                    REMOTE DASHBOARD                          │
│                                                             │
│   iPhone  │  Windows Laptop  │  Browser (any device)        │
│                                                             │
│   Flutter Web / Responsive Web App                          │
│   Read-only monitoring + reports                            │
│   Live updates via WebSocket (when shop is online)          │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Device Roles

| Device | Role | Can sell? | Can edit data? | Can view reports? |
|--------|------|-----------|---------------|------------------|
| Android Tablet | Primary POS | ✓ | ✓ (owner only) | ✓ |
| Android Phone | Hot standby POS | ✓ (when activated) | ✓ (owner only) | ✓ |
| iPhone (Thailand) | Remote dashboard | ✗ | ✗ | ✓ |
| Windows Laptop | Remote dashboard | ✗ | ✗ | ✓ |
| Browser | Remote dashboard | ✗ | ✗ | ✓ |

### Active device rule

Only one device is the **active POS** at any time. This is tracked via the `is_active_pos` flag in the `devices` table. Switching is a deliberate owner action ("Set as active device"), not automatic. Both devices can sync in the background simultaneously — the flag only controls which one the dashboard treats as the live register.

---

## 4. Hardware Setup

| Hardware | Model | Connection | Protocol |
|----------|-------|-----------|----------|
| Barcode Scanner | Netum NT-1228BL or Eyoyo EY-015 | Bluetooth | HID (types like a keyboard) |
| Receipt Printer | GOOJPRT PT-210 or Xprinter XP-P300 | Bluetooth | ESC/POS |
| Label Printer | NIIMBOT B21 (post-launch) | Bluetooth | NIIMBOT SDK |
| POS Tablet | Samsung Tab A8/A9 or Redmi Pad | — | Android 10+ |
| Standby Phone | Any Android | — | Android 10+ |

### Bluetooth hardware abstraction

All hardware is accessed through a Flutter hardware abstraction layer (HAL). Each device type (scanner, receipt printer, label printer) has a defined interface. Concrete implementations are swappable — if the shop changes printer brand, only the implementation changes, not the business logic.

```
HardwareInterface
  └── ScannerInterface
        └── BluetoothHIDScanner (Netum, Eyoyo)
  └── ReceiptPrinterInterface
        └── EscPosBluetoothPrinter (GOOJPRT, Xprinter)
  └── LabelPrinterInterface
        └── NiimbotPrinter (post-launch)
```

### Hardware failure handling

| Failure | App behaviour |
|---------|--------------|
| Scanner disconnects | Manual barcode entry field appears automatically |
| Printer disconnects | Sale completes, receipt queued — owner can reprint from sale history |
| Printer out of paper | Sale completes, error shown, reprint option offered |
| No hardware at all | App works fully without any Bluetooth device |

---

## 5. Flutter App Architecture

```
apps/mobile/
  lib/
    core/
      database/        ← Drift schema + DAOs
      sync/            ← sync queue, flusher, conflict handler
      auth/            ← JWT cache, offline auth
      hardware/        ← scanner, printer HAL
    features/
      auth/            ← login, PIN screen
      pos/             ← sale screen, cart, checkout
      products/        ← product list, add/edit
      categories/      ← category list, add/edit
      inventory/       ← stock levels, adjustments
      sales/           ← sales history, void
      expenses/        ← add/view expenses
      suppliers/       ← supplier list, orders
      reports/         ← daily summary, profit
      settings/        ← device management, sync status
    shared/
      widgets/         ← reusable UI components
      theme/           ← colours, typography
      utils/
```

### State management

Riverpod is used throughout. Each feature has its own providers. UI never talks to the database directly — always through a repository layer that handles both local SQLite reads and sync queue writes.

```
UI Widget
  └── Riverpod Provider
        └── Repository
              ├── Drift DAO (local SQLite read/write)
              └── Sync Queue (append on write)
```

### Navigation

GoRouter handles all navigation. Deep links are not needed at launch. Route guards check auth state from a Riverpod provider — if no valid JWT is cached and device is offline, the PIN screen is shown instead of the login screen.

---

## 6. Go Backend Architecture

```
services/backend/
  cmd/
    server/           ← main entrypoint
  internal/
    auth/             ← JWT issue, refresh, validate
    sync/             ← event ingestion, conflict resolution, rejection
    categories/       ← category events
    products/         ← product CRUD
    inventory/        ← event log, stock computation
    sales/            ← sale records, void logic
    expenses/         ← expense records
    suppliers/        ← supplier + order management
    reports/          ← aggregation queries
    dashboard/        ← WebSocket hub, live push
    devices/          ← device registry, active POS tracking
  pkg/
    db/               ← PostgreSQL connection, migrations
    middleware/        ← JWT validation, logging, rate limit
    websocket/        ← WebSocket connection manager
```

### Request flow (sync event)

```
Flutter App
  │
  ▼
POST /v1/sync/events
  │
  ▼
JWT Middleware (validate token — reject if invalid)
  │
  ▼
Sync Handler
  ├── Idempotency check (event ID already exists? → return 200, skip)
  ├── Apply inventory events (append to event log)
  ├── Apply LWW updates (compare timestamps, keep latest)
  ├── Detect conflicts (return in response)
  ├── Reject business-rule violations (return in `rejected[]` — API-SPEC.md §6.1)
  └── Detect negative stock (flag product)
  │
  ▼
WebSocket Hub (push update to any connected dashboard clients)
  │
  ▼
Response → device marks queue items as synced
```

### WebSocket (dashboard only)

WebSocket is used exclusively for the remote dashboard — it pushes live sale and stock updates to connected iPhone/browser/laptop clients when the shop device is online. It is never used by the POS app itself. If WebSocket connection drops, the dashboard falls back to polling (`GET /v1/sync/pull` every 30 seconds).

---

## 7. Authentication Flow

### First login (requires internet)

```
Owner enters username + password
  │
  ▼
POST /v1/auth/login
  │
  ▼
Server validates, returns:
  - access_token (15 min)
  - refresh_token (30 days)
  │
  ▼
App stores both in flutter_secure_storage
App stores device_id, user_id, user_role locally
  │
  ▼
App is ready — subsequent launches work offline
```

### Subsequent launches (offline-capable)

```
App starts
  │
  ├── Valid access token in secure storage?
  │     └── Yes → load app immediately, no network needed
  │
  ├── Access token expired, refresh token valid?
  │     ├── Online → POST /v1/auth/refresh → new access token
  │     └── Offline → use cached identity, set pending_refresh flag
  │                   load app normally from local SQLite
  │
  └── No tokens (first install or logged out)
        └── Show login screen — internet required
```

### Staff PIN

Staff log in with a 4-digit PIN on the device after the owner has authenticated the device once. The PIN is a local shortcut — it does not generate a new JWT. Staff operate under the device's existing JWT but with a `staff` role flag that restricts what they can see and do.

---

## 8. Sync Architecture Summary

*(Full detail in `SYNC-PROTOCOL.md` — summarised here for reference)*

| Concern | Decision |
|---------|----------|
| Inventory changes | Append-only event log — never sync raw stock numbers |
| Everything else | Last-Write-Wins by `created_at` timestamp, server is tiebreaker |
| Transport | HTTP REST — sync queue flushed when connectivity detected |
| Real-time push | WebSocket for dashboard only, never for POS |
| Offline operation | Full functionality from local SQLite indefinitely |
| Conflict on stock | Applied as-is, negative stock flagged, owner alerted |
| Conflict on LWW | Later timestamp wins, server notifies losing device |
| Permanent rejection | Server returns the event in `rejected[]`; device reverts its local optimistic write and tells the owner — never retried, no compensating event (`API-SPEC.md` §6.1, `SYNC-PROTOCOL.md` §4.4) |
| Clock skew | Server uses `server_received_at` as tiebreaker if delta < 5s |
| Idempotency | Every event has a UUID — server ignores duplicates |
| Failover | Phone pre-authenticated, background synced, one-tap activation via the `DEVICE_ACTIVATED` queue event — no connectivity required |

---

## 9. Infrastructure

```
DigitalOcean / Hetzner VPS
  │
  └── Docker Compose
        ├── nginx (reverse proxy, SSL termination)
        ├── go-api (G9POS backend)
        └── postgresql (persistent volume)
```

### Nginx responsibilities

- SSL/TLS termination (Let's Encrypt)
- Route `/api/` → Go backend
- Route `/ws/` → WebSocket endpoint
- Rate limiting on auth endpoints

### PostgreSQL

- Single instance at launch — no replication needed for one shop
- Daily automated backups to DigitalOcean Spaces or S3-compatible storage
- If server goes down: shop continues operating offline, syncs when server returns

### Deployment

- Go backend built as a Docker image, deployed via Docker Compose
- Schema migrations run automatically on startup (using `golang-migrate`)
- Zero-downtime deploys are not required at launch — brief maintenance windows are acceptable for a single shop

---

## 10. Remote Monitoring — What You Can See From Thailand

As the remote owner (accessing from iPhone or laptop in Thailand):

| Feature | Detail |
|---------|--------|
| Live sales feed | Each sale appears within seconds of completion (when shop is online) |
| Today's revenue | Running total, updates live |
| Today's profit | If cost prices are filled in |
| Stock levels | All products, with low-stock highlighted |
| Stock alerts | Push notification when a product hits low-stock threshold |
| Sales history | Full history, searchable, filterable by date/product/staff |
| Expense records | All expenses entered at the shop |
| Active device | Which device is currently the POS, last seen time |
| Sync status | When each device last synced — if tablet goes dark for hours, you'll know |
| Staff activity | Every sale tagged with who made it |

What you **cannot** do remotely (intentional):

- Void or edit sales
- Change prices or products
- Approve or reject anything

The shop operates autonomously. You observe and advise — you don't intervene in real-time operations from far away. This keeps the system simple and prevents accidental remote changes during a busy shop day.

---

## 11. Security Considerations

| Concern | Mitigation |
|---------|-----------|
| JWT theft on device | Tokens in `flutter_secure_storage` (AES encrypted) |
| Offline JWT abuse | Acceptable risk for single-operator shop — 30-day refresh token expiry |
| API access without auth | All endpoints require valid JWT except `/auth/login` |
| Staff privilege escalation | Role checked server-side on every request, not just client-side |
| Data in transit | HTTPS everywhere, no plain HTTP |
| Database exposure | PostgreSQL not exposed publicly — only Go API is internet-facing |
| Server backup | Daily automated backups — recovery point objective: 24 hours |

---

## 12. What Is NOT in Scope for Launch

To keep the first version shippable and reliable, these are explicitly deferred:

| Feature | Why deferred |
|---------|-------------|
| Multi-branch / multi-shop | Single shop only |
| Card / e-wallet payments | Cash only at launch |
| Customer loyalty / accounts | No customer database at launch |
| Label printer integration | Post-launch (NIIMBOT) |
| Automated reorder alerts | Post-launch |
| Accounting software export | Post-launch |
| iOS POS app | Dashboard only on iOS — POS is Android |
| Microservices | Single Go monolith is correct at this scale |

---

## 13. Next Documentation

Filenames below are the actual on-disk names. Earlier versions of this table used lowercase, hyphenated names that did not match any file in `docs/`.

| Document | Status | Purpose |
|----------|--------|---------|
| `SYNC-PROTOCOL.md` | ✅ Done — v1.2 | Sync design, failover, conflict resolution, rejection reconciliation |
| `DATA-MODEL.md` | ✅ Done — v1.2, 2 open decisions in its §9 | Database schema for SQLite and PostgreSQL |
| `API-SPEC.md` | ✅ Done — v1.3 | All REST endpoints, sync event types, WebSocket events |
| `ARCHITECTURE.md` | ✅ Done — v1.1 | This document |
| `HARDWARE-INTEGRATION.md` | 🔲 Not written | Scanner, printer protocols and Flutter integration. §4 of this document is the only current source and is a summary. |
| `UI-GUIDELINES.md` | 🔲 Not written | Design rules for non-technical users |
| `CODING-STANDARDS.md` | 🔲 Not written | Repo layout, layering, naming, testing. Must conform to `API-SPEC.md` §1.4 and `DATA-MODEL.md` §1.2 when authored. |
| `REQUIREMENTS.md` | 🔲 Not written | Formal in-scope / out-of-scope for v1 |
| `DEPLOYMENT.md` | 🔲 Not written | §9 of this document is the only current source and is a summary. |
| `SECURITY.md` | 🔲 Not written | §11 of this document is the only current source and is a summary. |