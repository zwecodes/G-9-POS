-- G9POS initial PostgreSQL schema.
-- DATA-MODEL.md §3 / §5. SQLite-only columns (synced_at, rejected_at, sync_queue) are omitted.

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,
    -- NULL for staff; unique when set (DATA-MODEL.md §3.1 / API-SPEC.md §2.6)
    username        TEXT,
    -- NULL for staff; never returned or pulled to devices
    password_hash   TEXT,
    pin             TEXT NOT NULL,
    role            TEXT NOT NULL DEFAULT 'staff',
    created_at      TIMESTAMPTZ NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL,
    deleted_at      TIMESTAMPTZ NULL
);

CREATE TABLE devices (
    id              UUID PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users (id),
    name            TEXT NOT NULL,
    type            TEXT NOT NULL,
    is_active_pos   BOOLEAN NOT NULL DEFAULT false,
    last_seen_at    TIMESTAMPTZ NULL,
    last_sync_at    TIMESTAMPTZ NULL,
    app_version     TEXT NULL,
    created_at      TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ NULL
);

CREATE TABLE categories (
    id              UUID PRIMARY KEY,
    name            TEXT NOT NULL,
    sort_order      INTEGER NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL,
    deleted_at      TIMESTAMPTZ NULL,
    device_id       UUID NOT NULL
);

CREATE TABLE products (
    id                    UUID PRIMARY KEY,
    category_id           UUID NULL REFERENCES categories (id),
    name                  TEXT NOT NULL,
    barcode               TEXT NULL,
    price_mmk             INTEGER NOT NULL,
    cost_price_mmk        INTEGER NULL,
    unit                  TEXT NOT NULL DEFAULT 'pcs',
    low_stock_threshold   INTEGER NOT NULL DEFAULT 5,
    image_path            TEXT NULL,
    is_active             BOOLEAN NOT NULL DEFAULT true,
    stock_negative        BOOLEAN NOT NULL DEFAULT false,
    created_at            TIMESTAMPTZ NOT NULL,
    updated_at            TIMESTAMPTZ NOT NULL,
    deleted_at            TIMESTAMPTZ NULL,
    device_id             UUID NOT NULL
);

CREATE TABLE inventory_events (
    id                  UUID PRIMARY KEY,
    product_id          UUID NOT NULL REFERENCES products (id),
    event_type          TEXT NOT NULL,
    quantity_delta      INTEGER NOT NULL,
    reference_id        UUID NULL,
    reference_type      TEXT NOT NULL,
    note                TEXT NULL,
    operator_id         UUID NOT NULL REFERENCES users (id),
    device_id           UUID NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL,
    server_received_at  TIMESTAMPTZ NULL,
    CONSTRAINT inventory_events_quantity_delta_nonzero
        CHECK (quantity_delta <> 0)
);

CREATE TABLE sales (
    id                  UUID PRIMARY KEY,
    sale_number         TEXT NOT NULL,
    operator_id         UUID NOT NULL REFERENCES users (id),
    device_id           UUID NOT NULL,
    payment_method      TEXT NOT NULL,
    total_amount_mmk    INTEGER NOT NULL,
    discount_amount_mmk INTEGER NOT NULL DEFAULT 0,
    note                TEXT NULL,
    status              TEXT NOT NULL DEFAULT 'completed',
    voided_at           TIMESTAMPTZ NULL,
    voided_by           UUID NULL REFERENCES users (id),
    void_reason         TEXT NULL,
    created_at          TIMESTAMPTZ NOT NULL,
    server_received_at  TIMESTAMPTZ NULL
);

CREATE TABLE sale_items (
    id                      UUID PRIMARY KEY,
    sale_id                 UUID NOT NULL REFERENCES sales (id),
    product_id              UUID NOT NULL REFERENCES products (id),
    product_name_snapshot   TEXT NOT NULL,
    price_snapshot_mmk      INTEGER NOT NULL,
    quantity                INTEGER NOT NULL,
    subtotal_mmk            INTEGER NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL
);

CREATE TABLE expenses (
    id              UUID PRIMARY KEY,
    category        TEXT NOT NULL,
    amount_mmk      INTEGER NOT NULL,
    note            TEXT NULL,
    expense_date    TEXT NOT NULL,
    operator_id     UUID NOT NULL REFERENCES users (id),
    device_id       UUID NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL,
    deleted_at      TIMESTAMPTZ NULL
);

CREATE TABLE suppliers (
    id              UUID PRIMARY KEY,
    name            TEXT NOT NULL,
    phone           TEXT NULL,
    address         TEXT NULL,
    note            TEXT NULL,
    created_at      TIMESTAMPTZ NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL,
    deleted_at      TIMESTAMPTZ NULL,
    device_id       UUID NOT NULL
);

CREATE TABLE supplier_orders (
    id              UUID PRIMARY KEY,
    supplier_id     UUID NULL REFERENCES suppliers (id),
    order_date      TEXT NOT NULL,
    total_cost_mmk  INTEGER NOT NULL,
    note            TEXT NULL,
    status          TEXT NOT NULL,
    received_at     TIMESTAMPTZ NULL,
    operator_id     UUID NOT NULL REFERENCES users (id),
    device_id       UUID NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL
);

CREATE TABLE supplier_order_items (
    id                  UUID PRIMARY KEY,
    order_id            UUID NOT NULL REFERENCES supplier_orders (id),
    product_id          UUID NOT NULL REFERENCES products (id),
    quantity            INTEGER NOT NULL,
    cost_per_unit_mmk   INTEGER NOT NULL,
    subtotal_mmk        INTEGER NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL
);

-- DATA-MODEL.md §5 (SQLite indexes that also apply server-side)
CREATE INDEX idx_products_barcode ON products (barcode);
CREATE INDEX idx_sales_created_at ON sales (created_at);
CREATE INDEX idx_sale_items_sale_id ON sale_items (sale_id);
CREATE INDEX idx_inventory_events_product_id ON inventory_events (product_id);

-- DATA-MODEL.md §5 PostgreSQL additional
CREATE INDEX idx_inventory_events_server_received ON inventory_events (server_received_at);
CREATE INDEX idx_sales_device_id ON sales (device_id);
CREATE INDEX idx_sales_status ON sales (status);
CREATE INDEX idx_inventory_events_reference_id ON inventory_events (reference_id);
CREATE UNIQUE INDEX idx_users_username ON users (username) WHERE username IS NOT NULL;
