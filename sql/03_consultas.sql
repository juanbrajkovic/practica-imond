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

-- Revisión: ventas por estado del pedido
SELECT status, COUNT(*) AS filas, SUM(line_total) AS ventas
FROM fact_sales
GROUP BY status
ORDER BY filas DESC;

-- Revisión: ventas por provincia (¿cuántas quedaron "Desconocida"?)
SELECT p.name AS provincia, COUNT(*) AS filas
FROM fact_sales AS f
JOIN dim_province AS p ON p.province_key = f.province_key
GROUP BY p.name
ORDER BY filas DESC;

-- ===============================================================
-- KPIs
-- ===============================================================

-- KPI 1a: Ventas totales (tarjeta $M)
SELECT
    SUM(total_amount)               AS ventas_totales,
    SUM(total_amount) / 1000000     AS ventas_millones,
    COUNT(*)                        AS pedidos_validos
FROM fact_orders
WHERE is_valid_sale;

-- KPI 1b: Ventas por mes (serie temporal)
SELECT
    d.year_month,
    SUM(f.total_amount) AS ventas
FROM fact_orders AS f
JOIN dim_date    AS d ON d.date_key = f.date_key
WHERE f.is_valid_sale
GROUP BY d.year_month
ORDER BY d.year_month;

-- KPI 2a: Usuarios activos totales (tarjeta nK)
SELECT
    COUNT(DISTINCT CASE WHEN is_logged_in THEN customer_key END) AS clientes_logueados,
    COUNT(CASE WHEN NOT is_logged_in THEN 1 END)                 AS sesiones_anonimas,
    COUNT(DISTINCT CASE WHEN is_logged_in THEN customer_key END)
      + COUNT(CASE WHEN NOT is_logged_in THEN 1 END)             AS usuarios_activos
FROM fact_web_session;

-- KPI 2b: Usuarios activos por mes (serie temporal)
SELECT
    d.year_month,
    COUNT(DISTINCT CASE WHEN f.is_logged_in THEN f.customer_key END)
      + COUNT(CASE WHEN NOT f.is_logged_in THEN 1 END) AS usuarios_activos
FROM fact_web_session AS f
JOIN dim_date         AS d ON d.date_key = f.date_key
GROUP BY d.year_month
ORDER BY d.year_month;

-- KPI 3a: Ticket promedio (tarjeta $K)
SELECT
    SUM(total_amount) / COUNT(*)          AS ticket_promedio,
    SUM(total_amount) / COUNT(*) / 1000   AS ticket_promedio_miles
FROM fact_orders
WHERE is_valid_sale;

-- KPI 3b: Ticket promedio por mes y canal
SELECT
    d.year_month,
    ch.name                              AS canal,
    SUM(f.total_amount) / COUNT(*)       AS ticket_promedio
FROM fact_orders AS f
JOIN dim_date    AS d  ON d.date_key     = f.date_key
JOIN dim_channel AS ch ON ch.channel_key = f.channel_key
WHERE f.is_valid_sale
GROUP BY d.year_month, ch.name
ORDER BY d.year_month, ch.name;

-- KPI 4a: NPS total (tarjeta en puntos)
SELECT
    COUNT(*)            AS respuestas,
    SUM(is_promoter)    AS promotores,
    SUM(is_detractor)   AS detractores,
    ROUND((SUM(is_promoter) - SUM(is_detractor)) * 100.0 / COUNT(*), 1) AS nps
FROM fact_nps;

-- KPI 4b: NPS por mes y canal (tendencia)
SELECT
    d.year_month,
    ch.name AS canal,
    COUNT(*) AS respuestas,
    ROUND((SUM(f.is_promoter) - SUM(f.is_detractor)) * 100.0 / COUNT(*), 1) AS nps
FROM fact_nps    AS f
JOIN dim_date    AS d  ON d.date_key     = f.date_key
JOIN dim_channel AS ch ON ch.channel_key = f.channel_key
GROUP BY d.year_month, ch.name
ORDER BY d.year_month, ch.name;

-- KPI 5: Ventas por provincia (mapa o barras)
SELECT
    p.name                AS provincia,
    COUNT(*)              AS pedidos,
    SUM(f.total_amount)   AS ventas,
    ROUND(SUM(f.total_amount) * 100.0 / SUM(SUM(f.total_amount)) OVER (), 1) AS porcentaje
FROM fact_orders  AS f
JOIN dim_province AS p ON p.province_key = f.province_key
WHERE f.is_valid_sale
GROUP BY p.name
ORDER BY ventas DESC;

-- KPI 6: Ranking mensual de ventas por producto (top N)
SELECT
    d.year_month,
    p.name                AS producto,
    SUM(f.quantity)       AS unidades,
    SUM(f.line_total)     AS ventas,
    RANK() OVER (
        PARTITION BY d.year_month
        ORDER BY SUM(f.line_total) DESC
    )                     AS ranking
FROM fact_sales  AS f
JOIN dim_date    AS d ON d.date_key    = f.date_key
JOIN dim_product AS p ON p.product_key = f.product_key
WHERE f.is_valid_sale
GROUP BY d.year_month, p.name
ORDER BY d.year_month, ranking;