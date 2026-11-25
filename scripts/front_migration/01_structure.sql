CREATE TABLE IF NOT EXISTS dim_products (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    external_id bigint NOT NULL UNIQUE,
    product_code text,
    name text,
    date_add timestamp DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dim_ranges (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    external_id bigint NOT NULL UNIQUE,
    name text,
    factor numeric
);

CREATE TABLE IF NOT EXISTS dim_vendors (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    external_id bigint NOT NULL UNIQUE,
    name text
);

CREATE TABLE IF NOT EXISTS dim_transtypes (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    external_id integer NOT NULL UNIQUE,
    name text
);

CREATE TABLE IF NOT EXISTS dim_personals (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    external_id integer NOT NULL UNIQUE,
    lastname text,
    firstname text
);

CREATE TABLE IF NOT EXISTS dim_storages (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    external_id bigint NOT NULL UNIQUE,
    name text
);

CREATE TABLE IF NOT EXISTS fact_purchases (
    source_id bigint PRIMARY KEY,
    document_id bigint NOT NULL,
    operation_date timestamp NOT NULL,
    time_id integer NOT NULL,
    product_id bigint NOT NULL REFERENCES dim_products(external_id),
    vendor_id bigint REFERENCES dim_vendors(external_id),
    range_id bigint,
    quantity numeric,
    unit_price numeric,
    amount numeric
);

CREATE TABLE IF NOT EXISTS fact_sales (
    source_id bigint PRIMARY KEY,
    receipt_id numeric,
    operation_date timestamp NOT NULL,
    time_id integer NOT NULL,
    product_id bigint NOT NULL REFERENCES dim_products(external_id),
    transtype_id integer REFERENCES dim_transtypes(external_id),
    quantity numeric,
    amount numeric
);

CREATE TABLE IF NOT EXISTS fact_personnel_audit (
    source_id bigint PRIMARY KEY,
    operation_date timestamp NOT NULL,
    time_id integer NOT NULL,
    person_id integer NOT NULL REFERENCES dim_personals(external_id),
    event_type text,
    is_error integer
);

CREATE TABLE IF NOT EXISTS fact_stock_movements (
    source_id bigint PRIMARY KEY,
    document_id bigint NOT NULL,
    operation_date timestamp NOT NULL,
    time_id integer NOT NULL,
    product_id bigint NOT NULL REFERENCES dim_products(external_id),
    storage_id bigint,
    range_id bigint,
    operation_type integer NOT NULL,
    quantity numeric
);
