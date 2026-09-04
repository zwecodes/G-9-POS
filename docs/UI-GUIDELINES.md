# UI-GUIDELINES.md

**Version:** 1.2  
**Status:** Complete  
**Last updated:** 2026-09-04  
**Author:** Architecture Team

**Changelog since 1.1:** §2 secondary-user sentence matches `ARCHITECTURE.md` §10: dashboard shop-data access stays read-only; administrative UI is staff create, device revoke, and CSV catalog import. Void copy and deferred-rejection notice are unchanged.

**Changelog since 1.0:** Records the honest-optimistic-void decision (`SYNC-PROTOCOL.md` §11.2). §5.5 no longer promises that stock will definitely be returned or that a void cannot be undone. Confirmation before voiding is unchanged. `CANCELLED` is the history rendering of `sales.status = voided` and is absent after a rejected void restores `completed`. §6 adds the deferred-rejection notice on the existing sync status screen — never a popup or modal, never blocking a sale. No pending badge and no new UI state.

---

## 1. The One Rule That Overrides Everything

> **The shop owner must be able to complete a sale in under 10 seconds without reading anything.**

Every UI decision in G9POS is measured against this. If a screen requires reading, explanation, or more than 3 taps to complete a common task — redesign it.

---

## 2. Who Is the User

**Primary user:** A middle-aged woman running a motorcycle accessories shop alone in a small Myanmar town. She is not tech-savvy. She may be serving a customer and handling cash simultaneously. She cannot afford to be confused by the app even for 5 seconds.

**Secondary user:** The remote owner (Zwe) in Thailand — tech-savvy, using iPhone or laptop browser. Shop-data access is read-only. Administrative UI is limited to staff account creation, device revocation, and CSV catalog import (`ARCHITECTURE.md` §10).

Design for the primary user first, always. The secondary user can handle complexity.

---

## 3. Design Tokens

All values below must be defined as Flutter `ThemeData` constants. Cursor must never hardcode a color, font size, or spacing value inline — always reference the theme.

### 3.1 Colors

```dart
// core/theme/app_colors.dart

class AppColors {
  // Primary — used for main actions, active states, key numbers
  static const primary = Color(0xFF1B4FFF);       // strong blue
  static const primaryLight = Color(0xFFEEF2FF);  // pale blue for backgrounds

  // Surface
  static const background = Color(0xFFF5F5F5);    // light grey page bg
  static const surface = Color(0xFFFFFFFF);        // card/panel bg
  static const surfaceVariant = Color(0xFFF0F0F0); // subtle divider bg

  // Text
  static const textPrimary = Color(0xFF111111);    // headings, amounts
  static const textSecondary = Color(0xFF666666);  // labels, captions
  static const textMuted = Color(0xFF999999);      // placeholder, disabled

  // Semantic
  static const success = Color(0xFF16A34A);        // sale complete, in stock
  static const warning = Color(0xFFF59E0B);        // low stock, stale sync
  static const error = Color(0xFFDC2626);          // void, delete, negative stock
  static const info = Color(0xFF0EA5E9);           // sync status, info banners

  // Cash/money — always shown in primary or success, never muted
  static const amount = Color(0xFF111111);         // sale totals
  static const amountLarge = Color(0xFF1B4FFF);    // checkout total (large)
}
```

### 3.2 Typography

```dart
// core/theme/app_text_styles.dart
// Base font: Inter (Google Fonts) — clean, readable at all sizes on Android

class AppTextStyles {
  // POS-critical: amounts, totals — must be readable across the counter
  static const saleTotal = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    color: AppColors.amountLarge,
  );

  // Product names in cart
  static const cartItemName = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const cartItemPrice = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // Section headers
  static const sectionHeader = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.textMuted,
  );

  // Body text
  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Captions, timestamps, secondary info
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // Button labels
  static const buttonPrimary = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
}
```

### 3.3 Spacing

```dart
// core/theme/app_spacing.dart
// 4px base grid — all spacing is a multiple of 4

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}
```

### 3.4 Border Radius

```dart
class AppRadius {
  static const sm = BorderRadius.all(Radius.circular(8));
  static const md = BorderRadius.all(Radius.circular(12));
  static const lg = BorderRadius.all(Radius.circular(16));
  static const xl = BorderRadius.all(Radius.circular(24));
  static const full = BorderRadius.all(Radius.circular(999)); // pill buttons
}
```

---

## 4. Touch Targets

**Minimum tap target: 48×48px — no exceptions.**

On a tablet operated by one person under time pressure, small tap targets cause errors. Errors during a sale destroy trust.

```dart
// Every tappable element must be at least 48x48
// Use SizedBox or padding to enforce this even on small icons

// ✅ Correct
IconButton(
  iconSize: 24,
  padding: EdgeInsets.all(AppSpacing.md), // 16+24+16 = 56px total
  onPressed: () {},
  icon: Icon(Icons.remove),
)

// ❌ Wrong — too small, user misses it under pressure
GestureDetector(
  onTap: () {},
  child: Icon(Icons.remove, size: 16),
)
```

**Key action buttons (Complete Sale, Confirm Void, Save Product):**
- Minimum height: 56px
- Full width or minimum width: 200px
- Never placed where a thumb might accidentally hit them

---

## 5. Screen-by-Screen Guidelines

### 5.1 POS Sale Screen (most important screen in the app)

This screen is open all day. It must feel instant and never require scrolling to see the total.

**Layout (tablet landscape):**
```
┌─────────────────────┬──────────────────────┐
│                     │                      │
│   PRODUCT GRID      │      CART            │
│   (left 60%)        │      (right 40%)     │
│                     │                      │
│  [Product] [Product]│  Item 1    x2  8,500 │
│  [Product] [Product]│  Item 2    x1  4,500 │
│  [Product] [Product]│                      │
│                     │  ─────────────────── │
│  [Search bar top]   │  TOTAL   13,000 MMK  │
│                     │                      │
│                     │  [COMPLETE SALE]     │
└─────────────────────┴──────────────────────┘
```

**Rules:**
- Total amount is always visible — never below the fold
- "COMPLETE SALE" button: full width of cart panel, 64px tall, primary blue, white bold text
- Product grid: minimum 2 columns on phone, 3-4 columns on tablet
- Product card: photo top, name below (max 2 lines), price bottom — minimum 80×100px
- Cart item row: name left, quantity control center (− N +), price right
- Quantity (− / +) buttons: minimum 40×40px each, high contrast
- No hamburger menus on this screen — everything visible at a glance
- Search bar always visible at top of product grid, not hidden behind a tap

**What must NOT be on this screen:**
- Settings
- Reports
- Anything that could be accidentally tapped during a sale

### 5.2 Product Grid / Search

- Search triggers on every keystroke — no "Search" button to tap
- Results filter in real time as the owner types
- If barcode scanner fires, search field auto-populates and product is added to cart immediately
- Empty state: "No products found — try a different name" with a clear icon
- Low stock badge: small red dot on product card corner (not a popup, not blocking)

### 5.3 Cart

- Swipe left on a cart item to remove it — standard gesture, no confirmation needed for removal (it's easy to re-add)
- Tapping quantity number opens a number pad to type quantity directly — faster than tapping + many times for bulk items
- Zero-quantity items are removed from cart automatically
- Cart is never cleared without explicit owner action

### 5.4 Checkout / Payment Screen

```
┌────────────────────────────────┐
│  ← Back                        │
│                                │
│  TOTAL                         │
│  13,000 MMK          (40px)    │
│                                │
│  Payment: CASH       (only)    │
│                                │
│  [  COMPLETE SALE  ]           │
│   full width, 64px tall        │
└────────────────────────────────┘
```

- One screen, no tabs, no steps — the simpler the better
- "Complete Sale" is the only primary action
- After completing: full-screen green confirmation for 1.5 seconds, then auto-return to POS screen
- Confirmation shows: sale number, total, "Receipt printed" or "No printer connected"

### 5.5 Sale Void Screen

- Access: Sales History → tap sale → Void button (not prominently placed — owner must mean to find it)
- Void button: red, clearly labeled "Cancel This Sale"
- Confirmation dialog before voiding — plain language (required; see also §13):
  - Title: "Cancel this sale?"
  - Body: "If the shop still allows cancelling this sale today, stock will be put back. If not, the sale will stay completed."
  - Buttons: "Yes, Cancel Sale" (red) / "Keep It" (grey)
- Do **not** say stock will definitely be returned. Do **not** say "This cannot be undone." The server can refuse a void after the shop-day (`SYNC-PROTOCOL.md` §4.4, `VOID_WINDOW_CLOSED`).
- After confirm: brief confirmation. The sale shows a "CANCELLED" badge in history while `sales.status = voided`.
- If the server later rejects the void, `status` is restored to `completed` (`SYNC-PROTOCOL.md` §4.4). The `CANCELLED` badge is then absent — it is not a stored field, only the rendering of `status = voided`. The owner is told on the sync status screen (§6), not by a popup.

### 5.6 Product Add/Edit Screen

- One column, scrollable form — no tabs
- Fields in order: Photo (optional), Name*, Category, Barcode (tap to scan), Price*, Cost Price (optional, with nudge), Unit, Low Stock Threshold
- Required fields marked with * in label — not a red asterisk that looks like an error
- "Save" button: always visible at bottom (sticky footer), never requires scrolling to reach
- Barcode field: tapping opens camera OR scanner fires into it automatically
- Cost price field shows: "Add cost price to see profit in reports" as placeholder text

### 5.7 Inventory / Stock Screen

- List view, not grid — stock management is a reading task, not a browsing task
- Each row: product name, current stock level (large), low stock indicator
- Color coding: green (healthy), amber (at or near threshold), red (zero or negative)
- Negative stock shown as "-2" in red — never hidden or softened
- Manual adjustment: tap product → "+ Add Stock" / "- Remove Stock" → number pad → confirm
- Filter tabs at top: All / Low Stock / Out of Stock

### 5.8 Sales History Screen

- List, newest first
- Each row: sale number, time, item count, total amount, staff name
- Voided sales shown with "CANCELLED" badge — not hidden. The badge is shown when `sales.status = voided`. It is not shown when a rejected optimistic void has restored `status = completed` (`SYNC-PROTOCOL.md` §4.4 / §11.2). No pending badge and no extra status.
- Tap any sale: full detail with line items and "Reprint Receipt" button
- Filter: by date (default today), by staff (if multiple users)

### 5.9 Daily Summary / Reports Screen

```
┌────────────────────────────────┐
│  Today  |  This Week  |  Custom│  (tab bar)
├────────────────────────────────┤
│                                │
│  REVENUE          248,500 MMK  │  (large)
│  Profit           112,000 MMK  │  (large, only if cost prices set)
│  Sales                     17  │
│  Items sold                43  │
│                                │
│  ─── Top Products ───          │
│  1. Yamaha Oil Filter  x12     │
│  2. Chain Lube 400ml   x8      │
│                                │
│  ─── Expenses ───              │
│  Electricity          5,000    │
│  Transport            3,000    │
└────────────────────────────────┘
```

- Numbers are the hero — large, bold, high contrast
- No pie charts, no bar charts at launch — plain numbers are faster to read
- "Incomplete — add cost prices to see profit" shown instead of profit if cost prices missing

### 5.10 Settings Screen

- Simple list, no nested settings more than 1 level deep
- Hardware section: scanner status, printer status, test buttons
- Sync section: last synced time, sync now button, pending items count
- Device section: device name, active POS toggle
- Account section: change PIN, sign out

---

## 6. Sync Status Indicator

Shown in the app header on every screen — subtle, never blocking.

```
[🟢 sync icon]  = synced within last 2 hours — no text, just icon
[🟡 sync icon]  = 2–4 hours since sync — no text
[🟠 "4h ago"]   = 4–24 hours — shows time text next to icon
[🔴 "1d ago"]   = over 24 hours — shows time text, tapping opens sync screen
```

**Rules:**
- Never a popup or modal — just the header icon
- Tapping the icon always opens the sync status screen (shows pending count, last sync time, sync now button)
- Never block a sale regardless of sync status
- Icon is always in the top-right of the header, consistent across all screens

**Deferred rejection notices (added in 1.1).** When the server permanently refuses a change the device already applied — a void rejected with `VOID_WINDOW_CLOSED` is the case this exists for (`SYNC-PROTOCOL.md` §4.4 / §11.2) — the owner is told here, on this screen, not by a popup or modal and not during a sale.

- One sentence, plain language, names the affected record. Example: "Sale S-00142 could not be cancelled. The shop day had ended."
- Listed on the sync status screen with the existing pending count and last-sync information.
- Never a popup or modal (same rule as the header icon above).
- Never interrupts or blocks an active sale.

---

## 7. Offline Mode Indicator

```
┌──────────────────────────────────────────┐
│  ⚡ Offline — sales are saving locally   │  (slim banner, 36px tall)
└──────────────────────────────────────────┘
```

- Shown below the header when device has no internet
- Amber background (`AppColors.warning`), dark text
- No action button — just information
- Disappears automatically when connectivity returns
- **Never blocks any action** — the owner can sell, add products, do everything offline

---

## 8. Error and Empty States

### Errors
- Plain language only — no error codes, no technical terms
- One sentence maximum: what went wrong, what to do
- Example: "Couldn't print receipt — tap here to try again"
- Never: "Error 503: SPP socket timeout"

### Empty states
Every list screen must have a helpful empty state:

| Screen | Empty state message |
|--------|-------------------|
| Cart | "Scan a product or search above to start a sale" |
| Sales history | "No sales today yet" |
| Products | "No products yet — add your first product" |
| Low stock | "All products are well stocked" |
| Expenses | "No expenses recorded today" |

Empty states include a simple icon and one optional action button where relevant.

---

## 9. Forms and Input

- Label above the field — never placeholder-only (placeholder disappears when typing)
- Error message below the field in red — appears only after the user tries to save
- Number inputs (price, quantity, stock) always use a numeric keyboard — never a full keyboard
- Myanmar Kyat amounts: formatted with commas — `13,000 MMK` not `13000`
- No decimal places anywhere — MMK has no subdivision in everyday use
- Date inputs: use a date picker, never free text

---

## 10. Navigation Structure

```
Bottom navigation bar (4 items — always visible):
  [🛒 POS]  [📦 Products]  [📊 Reports]  [⚙️ Settings]

Within each section — top app bar with back arrow for sub-screens.
No drawer menu. No hamburger. No hidden navigation.
```

- Active tab: filled icon, primary color label
- Inactive tab: outlined icon, muted color label
- POS tab is always the first/leftmost — it's home
- Badge on POS tab if cart has items: small count badge

---

## 11. Tablet vs Phone Layout

The app must be responsive — tablet is primary POS, phone is hot standby.

| Screen | Phone layout | Tablet layout |
|--------|-------------|--------------|
| POS sale | Product grid full width, cart as bottom sheet | Split: products left 60%, cart right 40% |
| Product list | Single column | 2–3 column grid |
| Forms | Single column, full width | Single column, max 600px centered |
| Reports | Full width | Max 800px centered |
| Settings | Full width list | Max 600px centered |

Breakpoint: `600px` width = phone layout. Above = tablet layout. Use `LayoutBuilder` in Flutter.

---

## 12. Loading States

- Full-screen loading spinner: only on first app launch / first data load
- Skeleton loaders: for product grid and sales history list
- Inline spinner: for individual actions (saving, printing)
- Never block the entire UI for a background operation

```dart
// Use shimmer effect for list/grid loading states
// Package: shimmer (pub.dev)
// Skeleton shape must match the real item shape exactly
```

---

## 13. Confirmation Patterns

| Action | Confirmation needed? | Type |
|--------|---------------------|------|
| Add to cart | No | Instant |
| Remove from cart | No | Instant (swipe) |
| Complete sale | No | Instant (button tap) |
| Void a sale | Yes | Modal dialog |
| Delete a product | Yes | Modal dialog |
| Mark order received | Yes | Modal dialog |
| Sign out | Yes | Modal dialog |
| Change price | No | Save button confirms |

Confirmation dialogs: maximum 2 buttons. Destructive action always on the right, always red or clearly labelled. Cancel always on the left.

---

## 14. Receipt Print Feedback

After sale completion:

```
┌──────────────────────────────────────┐
│                                      │
│         ✅ Sale Complete             │
│                                      │
│    S-00142  ·  13,000 MMK            │
│                                      │
│    🖨️ Receipt printed                │
│    — or —                            │
│    🖨️ No printer — reprint anytime   │
│                                      │
└──────────────────────────────────────┘
```

- Full screen green overlay for 1.5 seconds
- Auto-dismisses and returns to POS screen — owner does not tap to dismiss
- If owner taps during the 1.5s: dismiss immediately and return to POS

---

## 15. What Cursor Must Never Do

These are hard rules. If Cursor violates them, reject and prompt again.

- ❌ Never use a `SnackBar` for errors — use inline error messages under the field
- ❌ Never use `showDialog` for non-destructive feedback — use the sale completion overlay
- ❌ Never hardcode colors inline — always `AppColors.*`
- ❌ Never hardcode font sizes inline — always `AppTextStyles.*`
- ❌ Never hardcode spacing values inline — always `AppSpacing.*`
- ❌ Never put a loading spinner that blocks a sale action
- ❌ Never show a raw exception or stack trace to the user
- ❌ Never use red for anything except destructive actions and errors
- ❌ Never require more than 3 taps for any common daily action
- ❌ Never use a bottom sheet for the main cart on tablet — use the split layout
- ❌ Never use a drawer/hamburger menu — use bottom navigation only

---

## 16. Cursor Prompt Template for UI Screens

When asking Cursor to build a screen, always include:

```
@UI-UX-GUIDELINES.md @DATA-MODEL.md

Build the [screen name] screen for G9POS.

Layout: [phone: full width single column / tablet: split layout]
Primary user: non-technical shop owner, operates alone
Primary action: [what the main thing this screen does is]

Requirements:
- Follow AppColors, AppTextStyles, AppSpacing — never hardcode values
- Minimum tap target 48x48px on all interactive elements
- [screen-specific requirement 1]
- [screen-specific requirement 2]

Do not add features not listed above.
Do not use SnackBar for errors.
Do not use a drawer or hamburger menu.
```