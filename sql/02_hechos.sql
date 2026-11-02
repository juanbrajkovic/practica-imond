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
