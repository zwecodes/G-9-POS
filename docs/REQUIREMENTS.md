# REQUIREMENTS.md

**Version:** 1.5
**Status:** Complete
**Last updated:** 2026-09-04
**Author:** Architecture Team

**Changelog since 1.4:** `sales.server_received_at` SQLite mirror is resolved (`DATA-MODEL.md` §8). Void-gating UI remains post-launch. No other scope change.

**Changelog since 1.3:** No new product features. Aligns this document with the API/data-model contracts: staff expenses remain in scope (the API now matches); catalog import is named as the third dashboard administrative write; staff create and first-owner setup point at `API-SPEC.md` §2.5–§2.6.

---

## 1. Purpose

This document defines what G9POS v1 actually is — what is in scope, what is explicitly out of scope, and what "ready to ship" means. It does not duplicate technical decisions (those live in the other docs). It exists to prevent scope creep and to give a clear finish line.

---

## 2. Context

G9POS is being built for one specific shop: a motorcycle accessories shop in Pin Laung, Myanmar, operated by one owner who is not tech-savvy. The builder (Zwe) is based in Thailand and cannot be physically present at launch. Power and internet are unreliable. The system must work the day it is handed over, without Zwe being in the room.

That constraint shapes every scope decision below.

---

## 3. Users at Launch

| Role | Count | Description |
|------|-------|-------------|
| Owner | 1 | Full access — sales, products, inventory, reports, settings |
| Staff | 1 | Restricted — sales and expenses only, no reports, no product edits, no void |
| Remote admin/viewer | 1 (Zwe) | Shop monitoring from Thailand — reports, live sales, stock levels. Read-only for shop data. Administrative writes: staff account creation, device revocation, and CSV catalog import only. |

Maximum 2 active shop accounts at launch (owner + 1 staff). The system must support this from day one — not as a post-launch addition — because the owner may need to leave the shop in the hands of staff before v2 is ready.

---

## 4. Devices at Launch

| Device | Role | Required at launch |
|--------|------|--------------------|
| Android tablet | Primary POS | Yes |
| Android phone | Hot standby / failover | Yes — must be set up and paired before handover |
| iPhone / laptop / browser | Remote dashboard (Zwe) | Yes — Zwe needs visibility from day one |
| Bluetooth barcode scanner | Product lookup | Yes — 500 products cannot be searched by name reliably |
| Bluetooth receipt printer | Receipts | Optional for v1 — sales never depend on printer availability. If purchased before launch, must pass printer tests before go-live. |
| Label printer (NIIMBOT) | Product labels | No — post-launch |

The standby phone is not optional. Given remote setup and unreliable power, having only one device is too risky. Both tablet and phone must be set up, paired, and tested before the system goes live.

---

## 5. V1 Feature Scope

### 5.1 In scope — must work at launch

**Authentication**
- Owner login (username + password)
- Staff PIN unlock on device
- Offline auth — full operation with no internet after first login
- Remote dashboard login (Zwe)
- Device revocation from dashboard

**Product catalogue**
- Add, edit, deactivate products (name, price, cost price, category, barcode, photo, unit, low-stock threshold)
- Category management
- Barcode lookup via scanner
- Manual barcode entry fallback when scanner unavailable
- **CSV bulk import — launch blocker.** ~500 products cannot be entered manually. The admin dashboard uploads a CSV via `POST /v1/catalog/import` (`API-SPEC.md` §10.2). The server applies normal `PRODUCT_CREATED` / `CATEGORY_CREATED` / `INVENTORY_ADJUSTED` events; POS devices receive the catalog through pull. Atomic: the whole file commits or nothing does.
- Soft delete only — no hard deletes

**Inventory**
- Stock computed from append-only event log
- Low stock alerts (badge on product, list in inventory screen)
- Manual stock adjustment (owner only)
- Negative stock flagged and visible — never hidden
- Stock visible on remote dashboard

**Sales / POS**
- Sale screen: product grid, barcode scan to cart, manual search, cart management
- Checkout: cash only, complete sale in ≤ 3 taps
- Sale completion always succeeds — never blocked by printer or network
- Sale history with full line item detail
- Sale void: owner only, same shop day only (Asia/Yangon UTC+6:30), with confirmation
- Optimistic void with honest confirmation copy (Design 1 / §11.2)
- Sale number format: S-00001 continuous

**Expenses**
- Add daily expenses (predefined categories + optional note)
- View expense history by date
- Staff can add expenses

**Sync**
- Offline-first: all operations work with no internet indefinitely
- Background sync every 2 hours when connectivity available
- Sync status indicator in app header
- Staleness warnings at 4 hours / 24 hours (non-blocking)
- Event group atomicity — sale and inventory events commit together
- Rejected event handling per G1 (rejected_at)
- Void rejection notice on sync status screen (never a modal)

**Remote dashboard**
- Live sales feed (when shop is online)
- Today's revenue, profit (if cost prices set), sale count
- Stock levels with low-stock highlighted
- Full sales history and expense history
- Sync status per device — Zwe can see when each device last synced
- Staff activity — every sale tagged with operator
- Administrative operations permitted: staff account creation, device revocation, and CSV catalog import — no remote writes to sales, live prices, inventory adjustments, or expenses

**Hardware**
- Bluetooth HID barcode scanner (Netum NT-1228BL or equivalent)
- Manual entry fallback when scanner disconnected
- Receipt printer: **optional at launch** — sale always completes without it; reprint from history when printer is available
- Hardware status indicators (non-blocking)

**First-run setup (critical — remote handover)**
- Guided setup flow the owner can complete alone without calling Zwe
- Mandatory checklist: tablet paired to scanner ✓, tablet paired to printer ✓ (if purchased), phone paired to scanner ✓, phone paired to printer ✓ (if purchased)
- Product catalogue import via CSV (owner or Zwe uploads from the admin dashboard via `POST /v1/catalog/import` before handover)
- First owner account provisioned by `POST /v1/setup` before API goes public
- The initial owner provisioning is completed during deployment/bootstrap before public API exposure; the in-shop guided setup begins after that provisioning and requires no developer presence.
- Both devices logged in and synced before shop opens

**Settings**
- Device name and active POS toggle
- Hardware test buttons (scanner, printer)
- Sync status and manual sync trigger
- Staff account management (owner JWT on the device; remote create via dashboard `POST /v1/users`). Update / disable / PIN reset remain post-launch.
- Change own PIN (staff PIN reset by owner is post-launch)

### 5.2 Out of scope for v1 — explicitly deferred

| Feature | Why deferred |
|---------|-------------|
| Card / e-wallet payments | Cash only — complexity not justified for one small shop |
| Customer accounts / loyalty | No customer database needed at this scale |
| Returns / exchanges | Post-launch — touches inventory, sales, and receipts simultaneously |
| Supplier order management | Post-launch — owner manages manually for now |
| Label printer (NIIMBOT) | Post-launch — HAL stub ready |
| Camera barcode scanning | Post-launch — HAL stub ready |
| Cash drawer | Never — single trusted operator, no benefit |
| Multi-branch / multi-shop | Not applicable |
| Accounting software export | Post-launch |
| Automated reorder alerts | Post-launch |
| iOS POS app | Dashboard only on iOS — POS is Android |
| Microservices | Single Go monolith is correct at this scale |
| Void gating by shop-day on device | Post-launch — honest copy handles v1 (`SYNC-PROTOCOL.md` §11.2). `sales.server_received_at` is mirrored into SQLite; using it to hide the void action is deferred |
| Staff update / disable / staff PIN reset | Post-launch — owner manages manually for now |
| Offline dashboard | Dashboard requires internet — this is acceptable |

---

## 6. Launch Blockers

These must all be true before G9POS goes live in the shop. No exceptions.

**Technical**
- [ ] Owner can complete a sale in under 10 seconds on the tablet
- [ ] Sale completes correctly with no internet connection
- [ ] Each POS device works independently offline — tablet and phone each operate with no internet and no connection to each other. When connectivity is available, each syncs through the central server per SYNC-PROTOCOL.md.
- [ ] Phone failover tested — tablet powered off, phone picks up without data loss
- [ ] Remote dashboard shows live sales from Zwe's device in Thailand
- [ ] Sync status visible on dashboard — Zwe can see if shop goes dark
- [ ] CSV import completed — all ~500 products loaded before shop opens
- [ ] Stock levels correct after CSV import
- [ ] Barcode scanner working on tablet
- [ ] Barcode scanner working on phone (standby)
- [ ] Staff account created and tested — restricted access confirmed
- [ ] Sale void tested — same-day works, next-day correctly rejected
- [ ] Low stock alerts working
- [ ] Offline auth tested — app opens and operates with airplane mode on
- [ ] Sync tested — offline sales sync correctly when connection returns
- [ ] Permanently rejected sync event tested — local state reverts correctly, rejected inventory events no longer affect stock, no compensating event created, owner sees deferred notice on sync status screen

**Operational**
- [ ] Owner has been shown how to: make a sale, add a product, check stock, add an expense, switch to the phone if tablet fails
- [ ] Zwe has confirmed the dashboard shows correct data from Thailand
- [ ] Both devices fully charged and plugged in at shop counter
- [ ] Wi-Fi router at shop is working (for background sync)
- [ ] Backend server deployed and running
- [ ] First owner account provisioned securely (before API goes public)

**Hardware (when printer is purchased)**
- [ ] Receipt prints correctly on tablet
- [ ] Receipt prints correctly on phone
- [ ] Reprint from history works

---

## 7. Definition of "Done" for V1

G9POS v1 is done when:

1. The owner can open the shop, make sales all day, and close without Zwe's help
2. Zwe can see shop activity from Thailand as promptly as the sync and WebSocket architecture permits — live when the shop is online, within 2 hours otherwise via background sync
3. If the tablet fails, the phone takes over in under 60 seconds with no data loss
4. If the internet fails, the shop keeps operating and syncs when it returns
5. If the power fails, the tablet's battery keeps the shop running

6. After successful synchronization, accepted local changes and server state converge — no duplicated sales, no duplicated inventory movements, no permanent phantom stock effects.

Everything else is post-launch.

---

## 8. Recommended Build Order

Based on the constraints above, the recommended implementation sequence. These are planning phases, not hard deadlines — ship when each phase is solid, not by a date.

```
Phase 1 — Foundation
  Go backend scaffold (project structure, DB, migrations, JWT auth)
  Flutter app scaffold (Riverpod, GoRouter, Drift schema)
  Sync engine (sync queue, flusher, POST /v1/sync/events)
  Auth feature end-to-end (login, offline JWT, PIN screen)

Phase 2 — Core POS
  Products feature (CRUD, categories, barcode)
  CSV bulk import (admin dashboard — launch blocker)
  Inventory feature (event log, stock computation, low-stock)
  POS sale screen (cart, checkout, INVENTORY_SOLD events)
  Sale void (same-day, owner only, INVENTORY_VOIDED events)

Phase 3 — Supporting features + remote
  Expenses feature
  Sales history + reprint
  Remote dashboard (Flutter web)
  WebSocket live updates
  Reports (daily summary, profit)
  Staff accounts + PIN

Phase 4 — Hardware + polish + handover
  Barcode scanner integration
  Receipt printer integration (if hardware purchased)
  First-run setup flow + guided checklist
  Offline indicators, staleness warnings
  Device management (failover, revoke)
  End-to-end testing against all launch blockers
  CSV import of real product catalogue
  Remote handover to shop
```

---

## 9. Known Gaps (Post-Launch Backlog)

Items identified during documentation that are real but deferred:

| Item | Doc reference |
|------|--------------|
| Void gating by shop-day on device | UI-GUIDELINES §5.5; REQUIREMENTS §5.2 |
| Staff update / disable / PIN change endpoints | API-SPEC §2.6 |
| sales.server_received_at local void gating UI | UI-GUIDELINES §5.5 |
| Camera barcode scanning | HARDWARE-INTEGRATION §7 |
| Label printer (NIIMBOT B21) | HARDWARE-INTEGRATION §6 |
| Supplier order management | ARCHITECTURE §12 |
| Returns / exchanges | ARCHITECTURE §12 |

These are not forgotten — they are explicitly deferred. Address them after the shop is running and stable.