# CODING-STANDARDS.md

**Version:** 1.2
**Status:** Complete
**Last updated:** 2026-09-04
**Author:** Architecture Team

**Changelog since 1.1:** Extended §4.4 for the G1 resolution in `SYNC-PROTOCOL.md` §11.1. The SQLite copy of `inventory_events` now carries a local-only `rejectedAt` marker for rows whose event or group the server permanently rejected, so §4.4 gains a Drift example and three rules: every stock computation must filter `rejectedAt.isNull()`; `rejectedAt` may only be set while `syncedAt` is null, enforced in the DAO *and* by a `CHECK` constraint rather than a Dart `assert()`, which release builds strip; and setting it is the only write permitted to an existing row in that table. Marking has two identification paths — by event `id` for standalone events, by `referenceId` for groups — both still gated on `syncedAt.isNull()`. §1 rule 2 (never hard-delete) is unchanged and gains no exception — nothing is deleted.

**Changelog since 1.0:** Fixed §5.1 — added the missing `internal/categories/` package (categories had no service to route to). Fixed §5.5 — the sync event processor example was missing `CATEGORY_*`, `SALE_VOIDED`, and `SUPPLIER_*`/`SUPPLIER_ORDER_*` cases; as written it would have silently fallen through to "unknown event type" for real event types defined in `API-SPEC.md` §5. This matters because this exact snippet is meant to be the pattern Cursor copies when scaffolding the real event processor.

---

## 1. The Non-Negotiable Rules

These are checked on every PR. Violation = rejection, no exceptions.

1. **All writes go through `POST /v1/sync/events` only.** No direct REST write endpoints for products, sales, void, expenses, suppliers, or orders. Ever.
2. **Never hard-delete.** Every delete is a soft delete via `deleted_at`. The sync protocol depends on this.
3. **Never store raw stock numbers.** Stock is always computed from `inventory_events`. Never cache it in a column on `products`.
4. **Never hardcode colors, font sizes, or spacing.** Always `AppColors.*`, `AppTextStyles.*`, `AppSpacing.*`.
5. **Never block a sale.** No hardware call, no network call, no validation can prevent a sale from completing.
6. **Never show a raw exception to the user.** Every error is caught, logged, and shown as plain language.
7. **`SHOP_TIMEZONE = Asia/Yangon (UTC+6:30)`** governs all date/day logic. Never use device-local time for business logic.
8. **Event groups are never split across sync batches.** Group by `reference_id` — a sale and its inventory events commit together or not at all.

---

## 2. Repository Structure

```
G-9-POS/
├── .cursorrules                  ← Cursor reads this automatically
├── .github/
│   └── workflows/               ← CI (lint, test)
├── apps/
│   ├── mobile/                  ← Flutter POS app (Android tablet + phone)
│   └── admin/                   ← Flutter Web dashboard (remote monitoring)
├── services/
│   └── backend/                 ← Go API
├── infrastructure/
│   ├── docker-compose.yml
│   └── nginx/
├── docs/                        ← All markdown documentation
└── design-refs/                 ← Mobbin/reference screenshots (not committed to git)
```

---

## 3. Git Standards

### Branch naming
```
main                    ← always deployable, protected
feature/products-crud   ← new feature
fix/sync-queue-retry    ← bug fix
docs/update-api-spec    ← documentation only
chore/update-deps       ← dependency updates
```

### Commit messages — Conventional Commits
```
feat(pos): add barcode scan to cart flow
fix(sync): prevent event group split across batches
docs(api): resolve open questions in API-SPEC
chore(deps): upgrade drift to 2.x
refactor(auth): extract JWT cache to separate service
test(inventory): add event log computation tests
```

Format: `type(scope): lowercase description`
- Present tense ("add" not "added")
- No period at the end
- Scope is the feature name: `pos`, `sync`, `auth`, `products`, `categories`, `inventory`, `sales`, `expenses`, `suppliers`, `reports`, `hardware`, `dashboard`

### PR rules
- One feature per PR — never bundle unrelated changes
- PR must have a description: what changed and why
- No PR merges with failing tests or lint errors
- Self-review before merging even when working solo — read your own diff

### Commit before every Cursor session
```bash
# Before opening Cursor Composer for a new feature:
git add -A && git commit -m "chore: checkpoint before [feature] work"
```
If Cursor goes wrong: `git checkout .` and start over with a better prompt.

---

## 4. Flutter Standards

### 4.1 Project structure

```
apps/mobile/lib/
├── core/
│   ├── database/
│   │   ├── app_database.dart       ← Drift database class
│   │   ├── daos/                   ← one DAO file per table
│   │   └── tables/                 ← one table file per entity
│   ├── sync/
│   │   ├── sync_queue_dao.dart
│   │   ├── sync_flusher.dart       ← background sync service
│   │   ├── sync_event.dart         ← event type definitions
│   │   └── sync_conflict_handler.dart
│   ├── auth/
│   │   ├── auth_service.dart       ← JWT cache, offline auth
│   │   └── pin_service.dart
│   ├── hardware/
│   │   ├── interfaces/
│   │   ├── implementations/
│   │   ├── hardware_provider.dart
│   │   └── hardware_constants.dart
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   ├── app_spacing.dart
│   │   └── app_theme.dart
│   └── utils/
│       ├── currency_formatter.dart ← MMK formatting
│       ├── date_utils.dart         ← always uses SHOP_TIMEZONE
│       └── uuid_generator.dart
├── features/
│   ├── auth/
│   │   ├── providers/
│   │   ├── screens/
│   │   └── widgets/
│   ├── pos/                        ← sale screen, cart, checkout
│   ├── products/
│   ├── categories/
│   ├── inventory/
│   ├── sales/
│   ├── expenses/
│   ├── suppliers/
│   ├── reports/
│   └── settings/
└── shared/
    ├── widgets/                    ← reusable across features
    ├── providers/                  ← app-wide providers (auth state, sync status)
    └── router/
        └── app_router.dart         ← GoRouter configuration
```

### 4.2 Naming conventions

```dart
// Files: snake_case
product_repository.dart
sync_queue_dao.dart

// Classes: PascalCase
class ProductRepository {}
class SyncQueueDao {}

// Variables and functions: camelCase
final productList = <Product>[];
Future<void> flushSyncQueue() async {}

// Constants: camelCase with k prefix
const kScanThresholdMs = 100;
const kPrinterSendTimeoutSeconds = 3;

// Riverpod providers: camelCase, descriptive, end with Provider
final productListProvider = StreamProvider<List<Product>>(...);
final syncStatusProvider = StateProvider<SyncStatus>(...);
final activeCartProvider = StateNotifierProvider<CartNotifier, CartState>(...);

// Private members: _camelCase
final _controller = StreamController<String>();
void _handleScanResult(String barcode) {}
```

### 4.3 Riverpod — how to use it

Every feature follows this exact pattern. No exceptions.

```dart
// 1. Repository (pure Dart — no Flutter, no UI)
// features/products/repositories/product_repository.dart

class ProductRepository {
  final AppDatabase _db;
  final SyncQueueDao _syncQueue;

  ProductRepository(this._db, this._syncQueue);

  // READ: always from local SQLite
  Stream<List<Product>> watchAll() => _db.productDao.watchAllActive();

  // WRITE: local SQLite first, then sync queue
  Future<void> saveProduct(ProductCompanion product) async {
    await _db.productDao.upsert(product);
    await _syncQueue.enqueue(
      eventType: product.id.present ? 'PRODUCT_UPDATED' : 'PRODUCT_CREATED',
      payload: product.toJson(),
      referenceId: product.id.value,
    );
  }
}

// 2. Provider
// features/products/providers/product_providers.dart

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncQueueDaoProvider),
  );
});

final productListProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).watchAll();
});

// 3. Screen consumes provider — never accesses DB directly
// features/products/screens/product_list_screen.dart

class ProductListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productListProvider);

    return products.when(
      data: (list) => ProductGrid(products: list),
      loading: () => const ProductGridSkeleton(),
      error: (e, _) => ErrorMessage(message: 'Could not load products'),
    );
  }
}
```

**Rules:**
- UI never imports a DAO directly — always through a repository
- UI never imports `package:drift` — only the repository does
- Providers are defined in `features/<name>/providers/` — never inside a widget file
- `StateNotifier` for mutable state (cart, form), `StreamProvider` for DB streams, `FutureProvider` for one-shot async, `Provider` for sync dependencies

### 4.4 Drift (SQLite) — how to write it

```dart
// core/database/tables/products_table.dart

class Products extends Table {
  TextColumn get id => text()();                          // UUID, set by app
  TextColumn get categoryId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get barcode => text().nullable()();
  IntColumn get priceMmk => integer()();
  IntColumn get costPriceMmk => integer().nullable()();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(5))();
  TextColumn get imagePath => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get stockNegative => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();                 // Unix ms
  IntColumn get updatedAt => integer()();                 // Unix ms
  IntColumn get deletedAt => integer().nullable()();      // soft delete
  TextColumn get deviceId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// core/database/daos/product_dao.dart

@DriftAccessor(tables: [Products])
class ProductDao extends DatabaseAccessor<AppDatabase> with _$ProductDaoMixin {

  // Always filter soft-deleted records
  Stream<List<Product>> watchAllActive() =>
    (select(products)..where((p) => p.deletedAt.isNull())).watch();

  Future<void> upsert(ProductsCompanion product) =>
    into(products).insertOnConflictUpdate(product);

  // Soft delete — never hard delete
  Future<void> softDelete(String id) =>
    (update(products)..where((p) => p.id.equals(id)))
      .write(ProductsCompanion(deletedAt: Value(DateTime.now().millisecondsSinceEpoch)));
}
```

**Stock is summed from the event log, and the local log can hold rows the server refused:**

```dart
// core/database/daos/inventory_dao.dart

// inventory_events is append-only. The SQLite copy carries a local-only
// rejectedAt marker for rows whose event or group the server permanently
// rejected (SYNC-PROTOCOL.md §11.1). Those rows describe a movement that
// happened nowhere, so they must not count toward stock.

Future<int> computeStock(String productId) async {
  final delta = inventoryEvents.quantityDelta.sum();
  final query = selectOnly(inventoryEvents)
    ..addColumns([delta])
    ..where(inventoryEvents.productId.equals(productId) &
            inventoryEvents.rejectedAt.isNull());   // ← never omit this
  return (await query.getSingle()).read(delta) ?? 0;
}

// Two identification paths, both gated on syncedAt.isNull() so a
// server-accepted row can never be marked. Standalone events
// (INVENTORY_ADJUSTED / DAMAGED / RETURNED) have no referenceId.

Future<void> markEventRejected(String eventId, int now) =>
  (update(inventoryEvents)
    ..where((e) => e.id.equals(eventId) & e.syncedAt.isNull()))
  .write(InventoryEventsCompanion(rejectedAt: Value(now)));

Future<void> markGroupRejected(String referenceId, int now) =>
  (update(inventoryEvents)
    ..where((e) => e.referenceId.equals(referenceId) & e.syncedAt.isNull()))
  .write(InventoryEventsCompanion(rejectedAt: Value(now)));
```

**Rules:**
- Every table that participates in sync must have `createdAt`, `updatedAt`, `deletedAt`, `deviceId`
- Always filter `deletedAt.isNull()` in every read query — never expose soft-deleted records to the UI
- Never use auto-increment integer IDs — always UUID strings generated by the app
- Migrations go in `core/database/migrations/` — never modify an existing migration file
- **Every stock computation must filter `rejectedAt.isNull()`.** Any query that sums `quantityDelta` for stock — inventory list, low-stock report, product detail, the post-sync recompute — excludes rows marked `rejectedAt`. Omitting the filter silently reports stock that the server, every other device, and every report will disagree with. See `DATA-MODEL.md` §3.5 and `SYNC-PROTOCOL.md` §3.4
- **`rejectedAt` may only be set while `syncedAt` is null, and that must be enforced at runtime** — in the DAO or repository performing the write, as shown above, *and* as a table-level `CHECK` constraint in the migration. A Dart `assert()` does not count: it is stripped from release builds, which is the only place the invariant matters. This is the single property that keeps the marker from becoming a back door into accepted history. Identify the row by event `id` when `referenceId` is null (standalone), and by `referenceId` when the event is grouped. Calling only `markGroupRejected` for an `INVENTORY_ADJUSTED` / `INVENTORY_DAMAGED` / `INVENTORY_RETURNED` matches nothing and leaves stock wrong.
- **Setting `rejectedAt` is the only write permitted to an existing `inventory_events` row.** It is not a delete and grants no exception to §1 rule 2 — no row is ever removed, and the row stays in the log for the audit trail

### 4.5 Error handling in Flutter

```dart
// ✅ Correct — catch, log, show plain language
Future<void> saveProduct(ProductCompanion product) async {
  try {
    await _repository.saveProduct(product);
  } on DriftException catch (e, stack) {
    _logger.error('Failed to save product', error: e, stackTrace: stack);
    state = state.copyWith(error: 'Could not save product. Try again.');
  } catch (e, stack) {
    _logger.error('Unexpected error saving product', error: e, stackTrace: stack);
    state = state.copyWith(error: 'Something went wrong. Try again.');
  }
}

// ❌ Wrong — never let exceptions bubble to the UI unhandled
await _repository.saveProduct(product); // if this throws, app crashes
```

**Rules:**
- Every `async` function that touches the database, network, or hardware is wrapped in try/catch
- Errors are logged with full stack trace
- User-facing error messages are plain language, maximum one sentence
- Never rethrow from a UI action handler — catch and set error state

### 4.6 Currency formatting

```dart
// core/utils/currency_formatter.dart
// Always use this — never format MMK inline

class CurrencyFormatter {
  static String format(int amountMmk) {
    // Output: "13,000 MMK"
    final formatted = NumberFormat('#,###', 'en_US').format(amountMmk);
    return '$formatted MMK';
  }

  static String formatCompact(int amountMmk) {
    // Output: "13,000" — for tight spaces
    return NumberFormat('#,###', 'en_US').format(amountMmk);
  }
}

// ✅ Correct
Text(CurrencyFormatter.format(sale.totalAmountMmk))

// ❌ Wrong
Text('${sale.totalAmountMmk} MMK')
Text('${sale.totalAmountMmk.toString()} MMK')
```

### 4.7 Date and timezone

```dart
// core/utils/date_utils.dart
// All date logic goes through here — never use DateTime.now() directly in business logic

import 'package:timezone/timezone.dart' as tz;

class ShopDateUtils {
  static const shopTimezone = 'Asia/Yangon'; // UTC+6:30 — never change this

  static tz.TZDateTime nowInShop() =>
    tz.TZDateTime.now(tz.getLocation(shopTimezone));

  static String shopDateString(DateTime utc) {
    final local = tz.TZDateTime.from(utc, tz.getLocation(shopTimezone));
    return DateFormat('yyyy-MM-dd').format(local);
  }

  static bool isSameShopDay(DateTime a, DateTime b) =>
    shopDateString(a) == shopDateString(b);
}

// ✅ Correct
final today = ShopDateUtils.nowInShop();
final isSameDay = ShopDateUtils.isSameShopDay(sale.createdAt, DateTime.now());

// ❌ Wrong — never use device local time for business logic
final today = DateTime.now();
```

---

## 5. Go Standards

### 5.1 Project structure

```
services/backend/
├── cmd/
│   └── server/
│       └── main.go              ← entry point only — no logic here
├── internal/
│   ├── auth/
│   │   ├── handler.go           ← HTTP handler
│   │   ├── service.go           ← business logic
│   │   └── repository.go        ← DB queries
│   ├── sync/
│   │   ├── handler.go
│   │   ├── service.go
│   │   ├── event_processor.go   ← routes events to correct handler
│   │   └── repository.go
│   ├── categories/               ← ADDED in 1.1 — was missing; CATEGORY_* events had nowhere to route
│   ├── products/
│   ├── inventory/
│   ├── sales/
│   ├── expenses/
│   ├── suppliers/                ← covers both suppliers and supplier_orders (ARCHITECTURE.md §6)
│   ├── reports/
│   ├── devices/
│   └── dashboard/
│       └── websocket_hub.go
├── pkg/
│   ├── db/
│   │   ├── connection.go
│   │   └── migrations/          ← golang-migrate SQL files
│   ├── middleware/
│   │   ├── auth.go              ← JWT validation middleware
│   │   ├── logger.go
│   │   └── rate_limit.go
│   ├── timezone/
│   │   └── shop.go              ← SHOP_TIMEZONE constant
│   └── response/
│       └── response.go          ← standard JSON response helpers
└── Dockerfile
```

Each feature package (`categories`, `products`, `inventory`, `sales`, `expenses`, `suppliers`, `devices`) follows the same three-file shape: `handler.go`, `service.go`, `repository.go` — see §5.3.

### 5.2 Naming conventions

```go
// Files: snake_case
product_repository.go
sync_event_processor.go

// Packages: single lowercase word matching directory name
package sync
package auth
package products
package categories

// Exported (public): PascalCase
type ProductRepository struct {}
func NewProductRepository(db *sqlx.DB) *ProductRepository {}

// Unexported (private): camelCase
type syncBatch struct {}
func (s *SyncService) processEvent(event SyncEvent) error {}

// Constants: PascalCase for exported, camelCase for unexported
const ShopTimezone = "Asia/Yangon"
const maxBatchSize = 50
const printerTimeoutSeconds = 3
```

### 5.3 Handler → Service → Repository pattern

Every feature follows this exact three-layer pattern. No handler queries the database directly.

```go
// internal/products/handler.go
// Handler: parse request, call service, return response. No business logic here.

type Handler struct {
  service *Service
}

func (h *Handler) GetProducts(c *gin.Context) {
  deviceID := c.GetString("device_id") // set by JWT middleware

  products, err := h.service.GetAllProducts(c.Request.Context(), deviceID)
  if err != nil {
    response.InternalError(c, "Could not load products")
    return
  }

  response.OK(c, products)
}

// internal/products/service.go
// Service: business logic, validation, orchestration. No HTTP, no SQL.

type Service struct {
  repo *Repository
}

func (s *Service) GetAllProducts(ctx context.Context, deviceID string) ([]Product, error) {
  return s.repo.FindAllActive(ctx)
}

// internal/products/repository.go
// Repository: SQL only. No business logic, no HTTP.

type Repository struct {
  db *sqlx.DB
}

func (r *Repository) FindAllActive(ctx context.Context) ([]Product, error) {
  var products []Product
  err := r.db.SelectContext(ctx, &products,
    `SELECT * FROM products WHERE deleted_at IS NULL ORDER BY name ASC`)
  if err != nil {
    return nil, fmt.Errorf("products.FindAllActive: %w", err)
  }
  return products, nil
}
```

### 5.4 Error handling in Go

```go
// ✅ Correct — wrap errors with context, handle at the handler level

// Repository — wrap with context
func (r *Repository) FindAllActive(ctx context.Context) ([]Product, error) {
  var products []Product
  if err := r.db.SelectContext(ctx, &products, query); err != nil {
    return nil, fmt.Errorf("products.FindAllActive: %w", err)
  }
  return products, nil
}

// Service — add business context
func (s *Service) GetAllProducts(ctx context.Context) ([]Product, error) {
  products, err := s.repo.FindAllActive(ctx)
  if err != nil {
    return nil, fmt.Errorf("GetAllProducts: %w", err)
  }
  return products, nil
}

// Handler — translate to HTTP response, log the error
func (h *Handler) GetProducts(c *gin.Context) {
  products, err := h.service.GetAllProducts(c.Request.Context())
  if err != nil {
    log.Printf("ERROR: %v", err) // full error in server logs
    response.InternalError(c, "Could not load products") // plain language to client
    return
  }
  response.OK(c, products)
}

// ❌ Wrong — ignore errors
products, _ := r.db.SelectContext(ctx, &products, query)

// ❌ Wrong — expose internal error to client
c.JSON(500, gin.H{"error": err.Error()})
```

### 5.5 Sync event processor

All writes arrive through `POST /v1/sync/events`. The event processor routes each event type to the correct handler.

**Fixed in 1.1** — this switch previously omitted `CATEGORY_*`, `SALE_VOIDED`, and `SUPPLIER_*`/`SUPPLIER_ORDER_*`, which are all real event types defined in `API-SPEC.md` §5. Any event type not listed here falls through to `default` and is rejected as unknown — so this switch must be kept in sync with that table whenever a new event type is added to the spec.

```go
// internal/sync/event_processor.go

func (p *EventProcessor) Process(ctx context.Context, event SyncEvent) (SyncResult, error) {
  switch event.EventType {
  case "CATEGORY_CREATED", "CATEGORY_UPDATED", "CATEGORY_DELETED":
    return p.categoryService.HandleEvent(ctx, event)

  case "PRODUCT_CREATED", "PRODUCT_UPDATED", "PRODUCT_DELETED":
    return p.productService.HandleEvent(ctx, event)

  case "INVENTORY_SOLD", "INVENTORY_VOIDED", "INVENTORY_RESTOCKED",
       "INVENTORY_ADJUSTED", "INVENTORY_DAMAGED", "INVENTORY_RETURNED":
    return p.inventoryService.HandleEvent(ctx, event)

  case "SALE_CREATED", "SALE_VOIDED":
    return p.salesService.HandleEvent(ctx, event)

  case "EXPENSE_CREATED", "EXPENSE_UPDATED", "EXPENSE_DELETED":
    return p.expenseService.HandleEvent(ctx, event)

  case "SUPPLIER_CREATED", "SUPPLIER_UPDATED", "SUPPLIER_DELETED",
       "SUPPLIER_ORDER_CREATED", "SUPPLIER_ORDER_UPDATED", "SUPPLIER_ORDER_RECEIVED":
    return p.supplierService.HandleEvent(ctx, event)

  case "DEVICE_ACTIVATED":
    return p.deviceService.HandleEvent(ctx, event)

  default:
    return SyncResult{}, fmt.Errorf("unknown event type: %s", event.EventType)
  }
}
```

**Rule:** `SALE_CREATED`/`SALE_VOIDED` and their related `INVENTORY_*` events arrive as one atomic group (`API-SPEC.md` §6, `SYNC-PROTOCOL.md` §2.5) sharing a `reference_id` — the processor must apply each group inside a single DB transaction, never call `salesService` and `inventoryService` as two independent, separately-committed steps for the same group.

### 5.6 Shop timezone in Go

```go
// pkg/timezone/shop.go

package timezone

import "time"

const ShopTimezone = "Asia/Yangon"

func ShopLocation() *time.Location {
  loc, err := time.LoadLocation(ShopTimezone)
  if err != nil {
    panic(fmt.Sprintf("could not load shop timezone %s: %v", ShopTimezone, err))
  }
  return loc
}

func NowInShop() time.Time {
  return time.Now().In(ShopLocation())
}

func ShopDateString(t time.Time) string {
  return t.In(ShopLocation()).Format("2006-01-02")
}

func IsSameShopDay(a, b time.Time) bool {
  return ShopDateString(a) == ShopDateString(b)
}

// ✅ Correct
if !timezone.IsSameShopDay(sale.ServerReceivedAt, time.Now()) {
  return errors.New("void only allowed on same shop day as sale")
}

// ❌ Wrong
if sale.CreatedAt.Day() != time.Now().Day() {} // uses device/server local time
```

### 5.7 Database migrations

```
pkg/db/migrations/
  000001_initial_schema.up.sql
  000001_initial_schema.down.sql
  000002_add_devices_revoked_at.up.sql
  000002_add_devices_revoked_at.down.sql
```

**Rules:**
- Never modify an existing migration file — add a new one
- Every `up` migration has a corresponding `down` migration
- Migrations run automatically on server startup
- Migration filenames: `{sequence}_{description}.{direction}.sql`
- Test both up and down locally before committing

### 5.8 Standard response format

```go
// pkg/response/response.go

type APIResponse struct {
  Success bool        `json:"success"`
  Data    interface{} `json:"data,omitempty"`
  Error   string      `json:"error,omitempty"`
}

func OK(c *gin.Context, data interface{}) {
  c.JSON(200, APIResponse{Success: true, Data: data})
}

func BadRequest(c *gin.Context, message string) {
  c.JSON(400, APIResponse{Success: false, Error: message})
}

func Unauthorized(c *gin.Context) {
  c.JSON(401, APIResponse{Success: false, Error: "Authentication required"})
}

func InternalError(c *gin.Context, message string) {
  c.JSON(500, APIResponse{Success: false, Error: message})
}
```

---

## 6. Testing Standards

### What to test

| Layer | What to test | Tool |
|-------|-------------|------|
| Go repository | SQL queries return correct data | `testcontainers` + real PostgreSQL |
| Go service | Business logic, event routing, conflict resolution | `testing` package + mocks |
| Go handler | HTTP status codes, response shape | `httptest` |
| Flutter repository | Drift queries on in-memory DB | `drift` test utilities |
| Flutter providers | State transitions | `riverpod` test utilities |
| Flutter widgets | Key interactions (tap complete sale, void confirmation) | `flutter_test` |

### What not to test
- Third-party library internals
- Pure getters/setters with no logic
- UI pixel-perfect layout (too brittle)

### Test file naming
```
Go:      product_repository_test.go  (same directory as source)
Flutter: product_repository_test.dart (in test/ mirroring lib/ structure)
```

### Minimum coverage targets
- Sync event processor: 90% — this is the highest-risk code
- Auth service: 90%
- Inventory event log computation: 90%
- Everything else: 70%

---

## 7. Logging Standards

### Go
```go
// Use structured logging — log/slog (Go 1.21+)
// Never use fmt.Println in production code

slog.Info("sync batch processed",
  "device_id", event.DeviceID,
  "event_count", len(batch.Events),
  "duration_ms", elapsed.Milliseconds(),
)

slog.Error("failed to process sync event",
  "event_id", event.ID,
  "event_type", event.EventType,
  "error", err,
)
```

### Flutter
```dart
// Use logger package — never use print() in production code

final _logger = Logger('ProductRepository');

_logger.info('Product saved', {'product_id': product.id});
_logger.error('Failed to save product', error: e, stackTrace: stack);
```

---

## 8. Environment Configuration

### Go — environment variables
```
DATABASE_URL=postgres://user:pass@localhost:5432/g9pos
JWT_SECRET=<random 256-bit secret>
SHOP_TIMEZONE=Asia/Yangon
APP_ENV=development|production
PORT=8080
```

Never commit `.env` files. Use `.env.example` with placeholder values in the repo.

### Flutter — environment
```dart
// Use --dart-define for build-time config
// Never hardcode API URLs

// Run with:
// flutter run --dart-define=API_URL=http://localhost:8080

const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');
```

---

## 9. Code Review Checklist

Before merging any PR, verify:

**Correctness**
- [ ] All writes go through sync queue — no direct REST writes
- [ ] No hard deletes — soft delete only
- [ ] Stock never stored as raw number
- [ ] All dates use `ShopDateUtils` / `timezone.ShopLocation()`
- [ ] Event groups not split across batches
- [ ] New event types are added to `event_processor.go`'s switch AND to `API-SPEC.md` §5's table — never just one (added 1.1)

**Quality**
- [ ] No hardcoded colors, fonts, or spacing in Flutter
- [ ] No `print()` or `fmt.Println()` in production code
- [ ] All errors caught and shown as plain language
- [ ] No raw exceptions exposed to user
- [ ] Tap targets minimum 48×48px

**Tests**
- [ ] New business logic has tests
- [ ] Sync event processor paths are tested
- [ ] Migrations have both up and down

**Git**
- [ ] Conventional Commit message format
- [ ] One logical change per commit
- [ ] No unrelated changes bundled in   