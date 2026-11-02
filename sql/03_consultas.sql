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