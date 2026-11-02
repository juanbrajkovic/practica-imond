-- =====================================================================
-- 02_hechos.sql — Tablas de HECHOS del modelo estrella
-- =====================================================================
-- Este archivo se ejecuta después de 01_dimensiones.sql porque los hechos
-- apuntan a las dimensiones con FOREIGN KEY (REFERENCES).
--
-- Para cada tabla de hechos:
--   1. Definí el GRANO: ¿qué representa UNA fila?
--      (ej.: un producto dentro de un pedido, una sesión web, una respuesta NPS)
--   2. CREATE TABLE con:
--        - PRIMARY KEY
--        - una FOREIGN KEY por cada dimensión:  product_key INTEGER REFERENCES dim_product (product_key)
--        - las métricas (cantidades, importes, puntajes...)
--   3. INSERT INTO ... SELECT uniendo las tablas de origen (raw.) con las dimensiones
--      para obtener las claves.
--
-- Patrón para obtener la clave de una dimensión:
--
--   SELECT i.order_item_id, p.product_key, i.quantity, i.line_total
--   FROM raw.sales_order_item AS i
--   JOIN dim_product AS p ON p.product_id = i.product_id
--
-- Si una FOREIGN KEY apunta a una clave que no existe en la dimensión,
-- DuckDB rechaza la carga y run_sql.py te muestra el error.
-- =====================================================================


-- TU TURNO: creá acá las tablas de hechos.

-- ---------------------------------------------------------------
-- Hecho ventas: una fila por producto dentro de cada pedido
-- ---------------------------------------------------------------
CREATE TABLE fact_sales (
    order_item_id    BIGINT PRIMARY KEY,
    order_id         BIGINT NOT NULL,
    date_key         INTEGER REFERENCES dim_date(date_key),
    customer_key     INTEGER REFERENCES dim_customer(customer_key),
    product_key      INTEGER REFERENCES dim_product(product_key),
    channel_key      INTEGER REFERENCES dim_channel(channel_key),
    store_key        INTEGER REFERENCES dim_store(store_key),
    province_key     INTEGER REFERENCES dim_province(province_key),
        status           VARCHAR,
    is_valid_sale    BOOLEAN,     -- TRUE si FULFILLED o PAID
    quantity         INTEGER,
    unit_price       DECIMAL(12, 2),
    discount_amount  DECIMAL(12, 2),
    line_total       DECIMAL(12, 2)
);

INSERT INTO fact_sales
SELECT
    i.order_item_id,
    i.order_id,
    CAST(strftime(o.order_date, '%Y%m%d') AS INTEGER) AS date_key,
    COALESCE(c.customer_key, -1)  AS customer_key,
    p.product_key,
    ch.channel_key,
    COALESCE(s.store_key, -1)     AS store_key,
    COALESCE(pr.province_key, -1) AS province_key,
    o.status,
        o.status IN ('FULFILLED', 'PAID') AS is_valid_sale,
    i.quantity,
    i.unit_price,
    i.discount_amount,
    i.line_total
FROM raw.sales_order_item AS i
JOIN raw.sales_order      AS o  ON o.order_id = i.order_id
-- buscar las claves en las dimensiones (usando los _id)
LEFT JOIN dim_product     AS p  ON p.product_id  = i.product_id
LEFT JOIN dim_customer    AS c  ON c.customer_id = o.customer_id
LEFT JOIN dim_channel     AS ch ON ch.channel_id = o.channel_id
LEFT JOIN dim_store       AS s  ON s.store_id    = o.store_id
-- provincia: la de la tienda si hay, si no la del envío
LEFT JOIN raw.store       AS rs ON rs.store_id   = o.store_id
LEFT JOIN raw.address     AS ta ON ta.address_id = rs.address_id
LEFT JOIN raw.address     AS sa ON sa.address_id = o.shipping_address_id
LEFT JOIN dim_province    AS pr ON pr.province_id = COALESCE(ta.province_id, sa.province_id);

-- ---------------------------------------------------------------
-- Hecho NPS: una fila por respuesta de encuesta
-- ---------------------------------------------------------------
CREATE TABLE fact_nps (
    nps_id         BIGINT PRIMARY KEY,
    date_key       INTEGER REFERENCES dim_date(date_key),
    customer_key   INTEGER REFERENCES dim_customer(customer_key),
    channel_key    INTEGER REFERENCES dim_channel(channel_key),
    score          INTEGER,
    nps_category   VARCHAR,     -- Promotor / Pasivo / Detractor
    is_promoter    INTEGER,     -- 1 si puntaje 9-10
    is_detractor   INTEGER,     -- 1 si puntaje 0-6
    comment        VARCHAR
);

INSERT INTO fact_nps
SELECT
    n.nps_id,
    CAST(strftime(n.responded_at, '%Y%m%d') AS INTEGER) AS date_key,
    COALESCE(c.customer_key, -1) AS customer_key,
    ch.channel_key,
    n.score,
    CASE
        WHEN n.score >= 9 THEN 'Promotor'
        WHEN n.score >= 7 THEN 'Pasivo'
        ELSE 'Detractor'
    END AS nps_category,
    CASE WHEN n.score >= 9 THEN 1 ELSE 0 END AS is_promoter,
    CASE WHEN n.score <= 6 THEN 1 ELSE 0 END AS is_detractor,
    n.comment
FROM raw.nps_response AS n
LEFT JOIN dim_customer AS c  ON c.customer_id = n.customer_id
LEFT JOIN dim_channel  AS ch ON ch.channel_id = n.channel_id;

-- ---------------------------------------------------------------
-- Hecho pedidos: una fila por pedido (cabecera)
-- Base para Ventas, Ticket Promedio y Ventas por Provincia
-- ---------------------------------------------------------------
CREATE TABLE fact_orders (
    order_id       BIGINT PRIMARY KEY,
    date_key       INTEGER REFERENCES dim_date(date_key),
    customer_key   INTEGER REFERENCES dim_customer(customer_key),
    channel_key    INTEGER REFERENCES dim_channel(channel_key),
    store_key      INTEGER REFERENCES dim_store(store_key),
    province_key   INTEGER REFERENCES dim_province(province_key),
    status         VARCHAR,
    is_valid_sale  BOOLEAN,          -- TRUE si PAID o FULFILLED
    subtotal       DECIMAL(12, 2),
    tax_amount     DECIMAL(12, 2),
    shipping_fee   DECIMAL(12, 2),
    total_amount   DECIMAL(12, 2)
);

INSERT INTO fact_orders
SELECT
    o.order_id,
    CAST(strftime(o.order_date, '%Y%m%d') AS INTEGER) AS date_key,
    COALESCE(c.customer_key, -1)  AS customer_key,
    ch.channel_key,
    COALESCE(s.store_key, -1)     AS store_key,
    COALESCE(pr.province_key, -1) AS province_key,
    o.status,
    o.status IN ('FULFILLED', 'PAID') AS is_valid_sale,
    o.subtotal,
    o.tax_amount,
    o.shipping_fee,
    o.total_amount
FROM raw.sales_order AS o
LEFT JOIN dim_customer AS c  ON c.customer_id  = o.customer_id
LEFT JOIN dim_channel  AS ch ON ch.channel_id  = o.channel_id
LEFT JOIN dim_store    AS s  ON s.store_id     = o.store_id
-- provincia según la dirección de envío (en tienda = dirección de la tienda)
LEFT JOIN raw.address  AS sa ON sa.address_id  = o.shipping_address_id
LEFT JOIN dim_province AS pr ON pr.province_id = sa.province_id;

-- ---------------------------------------------------------------
-- Hecho sesiones web: una fila por visita
-- Base para Usuarios Activos
-- ---------------------------------------------------------------
CREATE TABLE fact_web_session (
    session_id        BIGINT PRIMARY KEY,
    date_key          INTEGER REFERENCES dim_date(date_key),
    customer_key      INTEGER REFERENCES dim_customer(customer_key),
    channel_key       INTEGER REFERENCES dim_channel(channel_key),
    source            VARCHAR,     -- ads / direct / referral / organic
    device            VARCHAR,
    is_logged_in      BOOLEAN,     -- TRUE si el visitante inició sesión
    duration_seconds  INTEGER
);

INSERT INTO fact_web_session
SELECT
    w.session_id,
    CAST(strftime(w.started_at, '%Y%m%d') AS INTEGER) AS date_key,
    COALESCE(c.customer_key, -1) AS customer_key,
    ch.channel_key,
    w.source,
    w.device,
    w.customer_id IS NOT NULL AS is_logged_in,
    date_diff('second', w.started_at, w.ended_at) AS duration_seconds
FROM raw.web_session AS w
LEFT JOIN dim_customer AS c  ON c.customer_id = w.customer_id
-- todas las visitas web son del canal ONLINE
LEFT JOIN dim_channel  AS ch ON ch.code = 'ONLINE';

-- ---------------------------------------------------------------
-- Hecho pagos: una fila por pago
-- ---------------------------------------------------------------
CREATE TABLE fact_payment (
    payment_id    BIGINT PRIMARY KEY,
    order_id      BIGINT NOT NULL,
    date_key      INTEGER REFERENCES dim_date(date_key),         -- fecha del pedido
    customer_key  INTEGER REFERENCES dim_customer(customer_key),
    channel_key   INTEGER REFERENCES dim_channel(channel_key),
    method        VARCHAR,     -- CASH / CARD / TRANSFER / GATEWAY
    status        VARCHAR,     -- PENDING / PAID / FAILED / REFUNDED
    amount        DECIMAL(12, 2),
    paid_at       TIMESTAMP,   -- vacío si el pago no se concretó
    is_paid       BOOLEAN
);

INSERT INTO fact_payment
SELECT
    pa.payment_id,
    pa.order_id,
    CAST(strftime(o.order_date, '%Y%m%d') AS INTEGER) AS date_key,
    COALESCE(c.customer_key, -1) AS customer_key,
    ch.channel_key,
    pa.method,
    pa.status,
    pa.amount,
    pa.paid_at,
    pa.paid_at IS NOT NULL AS is_paid
FROM raw.payment AS pa
JOIN raw.sales_order   AS o  ON o.order_id     = pa.order_id
LEFT JOIN dim_customer AS c  ON c.customer_id  = o.customer_id
LEFT JOIN dim_channel  AS ch ON ch.channel_id  = o.channel_id;

-- ---------------------------------------------------------------
-- Hecho envíos: una fila por envío
-- Base para analizar tiempos de entrega por provincia
-- ---------------------------------------------------------------
CREATE TABLE fact_shipment (
    shipment_id             BIGINT PRIMARY KEY,
    order_id                BIGINT NOT NULL,
    date_key                INTEGER REFERENCES dim_date(date_key),  -- fecha del pedido
    customer_key            INTEGER REFERENCES dim_customer(customer_key),
    channel_key             INTEGER REFERENCES dim_channel(channel_key),
    store_key               INTEGER REFERENCES dim_store(store_key),
    province_key            INTEGER REFERENCES dim_province(province_key),
    carrier                 VARCHAR,
    status                  VARCHAR,     -- READY / SHIPPED / DELIVERED / CANCELLED
    shipped_at              TIMESTAMP,
    delivered_at            TIMESTAMP,
    transit_days            INTEGER,     -- envío → entrega
    order_to_delivery_days  INTEGER      -- compra → entrega
);

INSERT INTO fact_shipment
SELECT
    sh.shipment_id,
    sh.order_id,
    CAST(strftime(o.order_date, '%Y%m%d') AS INTEGER) AS date_key,
    COALESCE(c.customer_key, -1)  AS customer_key,
    ch.channel_key,
    COALESCE(s.store_key, -1)     AS store_key,
    COALESCE(pr.province_key, -1) AS province_key,
    sh.carrier,
    sh.status,
    sh.shipped_at,
    sh.delivered_at,
    date_diff('day', sh.shipped_at, sh.delivered_at)  AS transit_days,
    date_diff('day', o.order_date, sh.delivered_at)   AS order_to_delivery_days
FROM raw.shipment AS sh
JOIN raw.sales_order   AS o  ON o.order_id     = sh.order_id
LEFT JOIN dim_customer AS c  ON c.customer_id  = o.customer_id
LEFT JOIN dim_channel  AS ch ON ch.channel_id  = o.channel_id
LEFT JOIN dim_store    AS s  ON s.store_id     = o.store_id
LEFT JOIN raw.address  AS sa ON sa.address_id  = o.shipping_address_id
LEFT JOIN dim_province AS pr ON pr.province_id = sa.province_id;
