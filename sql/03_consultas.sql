-- =====================================================================
-- 03_consultas.sql — Consultas para revisar el modelo y calcular KPIs
-- =====================================================================
-- Cada SELECT de este archivo se muestra en la terminal al ejecutar
-- run_sql.py. Usalo para:
--   * comprobar que las tablas se cargaron bien (cantidad de filas, nulos...)
--   * escribir las consultas clave de los KPIs que pide la consigna
--     (ventas, usuarios activos, ticket promedio, NPS, ventas por provincia,
--     ranking mensual por producto) usando las tablas del modelo estrella.
-- =====================================================================


-- Ejemplo: revisar la dimensión producto
SELECT product_key, name, category, family, list_price
FROM dim_product
ORDER BY product_key;


-- TU TURNO: agregá acá tus consultas.

-- Rango de fechas de las ventas
SELECT MIN(order_date) AS primera, MAX(order_date) AS ultima
FROM raw.sales_order;

-- ---------------------------------------------------------------
-- Dimensión fecha (generada, no viene de raw)
-- ---------------------------------------------------------------
CREATE TABLE dim_date (
    date_key     INTEGER PRIMARY KEY,   -- ej. 20240131
    date         DATE NOT NULL,
    year         INTEGER,
    quarter      INTEGER,
    month        INTEGER,
    month_name   VARCHAR,
    year_month   VARCHAR,               -- ej. 2024-01
    day          INTEGER,
    day_name     VARCHAR,
    is_weekend   BOOLEAN
);

INSERT INTO dim_date
SELECT
    CAST(strftime(d.fecha, '%Y%m%d') AS INTEGER) AS date_key,
    d.fecha                                     AS date,
    year(d.fecha)                               AS year,
    quarter(d.fecha)                            AS quarter,
    month(d.fecha)                              AS month,
    monthname(d.fecha)                          AS month_name,
    strftime(d.fecha, '%Y-%m')                  AS year_month,
    day(d.fecha)                                AS day,
    dayname(d.fecha)                            AS day_name,
    isodow(d.fecha) IN (6, 7)                   AS is_weekend
FROM (
    SELECT CAST(range AS DATE) AS fecha
    FROM range(DATE '2024-01-01', DATE '2025-10-01', INTERVAL 1 DAY)
) AS d;
