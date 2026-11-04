# EcoBottle AR — Data Warehouse y Dashboard Comercial

Práctica de **Introducción al Marketing Online y los Negocios Digitales**.

Mini–ecosistema de datos comercial (online + offline) para EcoBottle AR: a partir de las tablas de origen del sistema de ventas se construye un **modelo estrella (Kimball)** en DuckDB, se calculan los KPIs comerciales y se exportan las tablas a CSV para alimentar el dashboard.

- Repositorio original (datos y consigna): [AugustoCarmona/mkt_tp_final](https://github.com/AugustoCarmona/mkt_tp_final)
- Dashboard: (https://datastudio.google.com/reporting/686c7b8e-da3f-4d25-b472-912ec1ac4d7b)

---

## Índice

1. [Cómo ejecutarlo](#1-cómo-ejecutarlo)
2. [Estructura del repositorio](#2-estructura-del-repositorio)
3. [Modelo de datos](#3-modelo-de-datos)
4. [Diccionario de datos](#4-diccionario-de-datos)
5. [Supuestos y decisiones](#5-supuestos-y-decisiones)
6. [KPIs y consultas clave](#6-kpis-y-consultas-clave)
7. [Hallazgos](#7-hallazgos)
8. [Dashboard](#8-dashboard)
9. [Convenciones del repositorio](#9-convenciones-del-repositorio)

---

## 1. Cómo ejecutarlo

**Requisitos:** Python 3.9 o superior y Git.

```bash
# 1. Clonar el repositorio
git clone https://github.com/juanbrajkovic/practica-imond.git
cd practica-imond

# 2. Crear el entorno virtual
python -m venv .venv          # en Windows, si "python" no existe: py -m venv .venv

# 3. Activarlo
source .venv/bin/activate     # Mac / Linux
.venv\Scripts\activate        # Windows

# 4. Instalar dependencias
pip install -r requirements.txt

# 5. Armar el data warehouse
python run_sql.py
```

`run_sql.py` crea la base `warehouse.duckdb` desde cero, ejecuta en orden los archivos de `sql/`, muestra en la terminal el resultado de cada consulta, exporta cada tabla a CSV en `dw/` y dibuja el modelo en `dw/modelo_estrella.md`.

Otros comandos útiles:

| Comando | Qué hace |
|---|---|
| `python run_sql.py --explorar` | Abre DuckDB en el navegador con las tablas de origen (`raw`) |
| `python run_sql.py --ui` | Arma el warehouse y abre DuckDB con las tablas del modelo y las de origen |

> Cada vez que se abre una terminal nueva hay que volver a activar el entorno virtual.

---

## 2. Estructura del repositorio

```
raw/                     datos de origen (un CSV por tabla, no se modifican)
sql/
  01_dimensiones.sql     creación y carga de las dimensiones
  02_hechos.sql          creación y carga de los hechos, con FOREIGN KEY
  03_consultas.sql       consultas de control, KPIs y hallazgos
dw/                      data warehouse exportado a CSV (fuente del dashboard)
  modelo_estrella.md     diagrama del modelo, generado automáticamente
run_sql.py               ejecuta los SQL y arma el warehouse
requirements.txt         dependencias (DuckDB)
```

---

## 3. Modelo de datos

El modelo sigue la metodología de **Kimball**: 6 dimensiones y 6 tablas de hechos. Como varios hechos comparten las mismas dimensiones (**dimensiones conformadas**), el esquema es una **constelación de hechos** (*galaxy schema*).

📊 **Diagrama completo:** [`dw/modelo_estrella.md`](dw/modelo_estrella.md)

| Hecho | Grano (una fila por…) | Dimensiones | KPIs que alimenta |
|---|---|---|---|
| `fact_orders` | pedido | fecha, cliente, canal, tienda, provincia | Ventas, Ticket Promedio, Ventas por Provincia |
| `fact_sales` | producto dentro de un pedido | fecha, cliente, producto, canal, tienda, provincia | Ranking mensual por producto |
| `fact_web_session` | visita a la web | fecha, cliente, canal | Usuarios Activos |
| `fact_nps` | respuesta de encuesta | fecha, cliente, canal | NPS |
| `fact_payment` | pago | fecha, cliente, canal | Conciliación ventas vs. pagos |
| `fact_shipment` | envío | fecha, cliente, canal, tienda, provincia | Tiempos de entrega |

Las 13 tablas de origen quedan cubiertas: `product` y `product_category` → `dim_product`; `store`, `address` y `province` → `dim_store`; `sales_order` y `sales_order_item` → `fact_orders` y `fact_sales`; el resto, cada una en su dimensión o hecho.

---

## 4. Diccionario de datos

Convenciones:
- **`_key`**: clave subrogada, propia del warehouse (PK en dimensiones, FK en hechos).
- **`_id`**: clave natural, el identificador que viene del sistema de origen.
- **`-1`**: fila "Desconocido" para hechos sin ese dato (ver supuestos).

### Dimensiones

#### `dim_date` — calendario (generado, no viene de `raw`)
| Columna | Tipo | Descripción / dominio |
|---|---|---|
| `date_key` | INTEGER **PK** | Fecha como número `AAAAMMDD` (ej. 20240131) |
| `date` | DATE | Fecha |
| `year` | INTEGER | Año (2024–2025) |
| `quarter` | INTEGER | Trimestre (1–4) |
| `month` | INTEGER | Mes (1–12) |
| `month_name` | VARCHAR | Nombre del mes (en inglés) |
| `year_month` | VARCHAR | Año-mes, ej. `2024-01` |
| `day` | INTEGER | Día del mes |
| `day_name` | VARCHAR | Día de la semana (en inglés) |
| `is_weekend` | BOOLEAN | TRUE si es sábado o domingo |

639 filas: del 01/01/2024 al 30/09/2025.

#### `dim_customer` — clientes
| Columna | Tipo | Descripción / dominio |
|---|---|---|
| `customer_key` | INTEGER **PK** | Clave subrogada (-1 = Desconocido) |
| `customer_id` | INTEGER | ID de origen |
| `full_name` | VARCHAR | Nombre y apellido |
| `status` | VARCHAR | `A` = activo, `I` = dio de baja su cuenta |
| `created_at` | TIMESTAMP | Fecha de alta |

#### `dim_product` — productos
| Columna | Tipo | Descripción / dominio |
|---|---|---|
| `product_key` | INTEGER **PK** | Clave subrogada |
| `product_id` | INTEGER | ID de origen |
| `sku` | VARCHAR | Código del producto |
| `name` | VARCHAR | Classic A Bottle / Sport B Bottle |
| `category` | VARCHAR | Classic / Sport |
| `family` | VARCHAR | Bottles (categoría padre, jerarquía aplanada) |
| `list_price` | DECIMAL(12,2) | Precio de lista sin IVA |

#### `dim_channel` — canales de venta
| Columna | Tipo | Descripción / dominio |
|---|---|---|
| `channel_key` | INTEGER **PK** | Clave subrogada |
| `channel_id` | INTEGER | ID de origen |
| `code` | VARCHAR | `ONLINE` / `OFFLINE` |
| `name` | VARCHAR | Tienda Online / Tiendas Físicas |

#### `dim_province` — provincias
| Columna | Tipo | Descripción / dominio |
|---|---|---|
| `province_key` | INTEGER **PK** | Clave subrogada (-1 = Desconocida) |
| `province_id` | INTEGER | ID de origen |
| `code` | VARCHAR | BA / CBA / SF / MZA |
| `name` | VARCHAR | Buenos Aires / Córdoba / Santa Fe / Mendoza |

#### `dim_store` — tiendas físicas
| Columna | Tipo | Descripción / dominio |
|---|---|---|
| `store_key` | INTEGER **PK** | Clave subrogada (-1 = Sin tienda / online) |
| `store_id` | INTEGER | ID de origen |
| `name` | VARCHAR | Tienda BA / CBA / SF / MZA |
| `address` | VARCHAR | Dirección (desde `address`) |
| `city` | VARCHAR | Ciudad (desde `address`) |
| `province` | VARCHAR | Provincia (desde `province`, jerarquía aplanada) |

### Hechos

#### `fact_orders` — pedidos (11.969 filas)
| Columna | Tipo | Descripción / dominio |
|---|---|---|
| `order_id` | BIGINT **PK** | ID del pedido |
| `date_key` | INTEGER **FK** → `dim_date` | Fecha del pedido |
| `customer_key` | INTEGER **FK** → `dim_customer` | Cliente |
| `channel_key` | INTEGER **FK** → `dim_channel` | Canal |
| `store_key` | INTEGER **FK** → `dim_store` | Tienda (-1 si es online) |
| `province_key` | INTEGER **FK** → `dim_province` | Provincia de la dirección de envío |
| `status` | VARCHAR | CREATED / PAID / FULFILLED / CANCELLED / REFUNDED |
| `is_valid_sale` | BOOLEAN | TRUE si `status` es PAID o FULFILLED |
| `subtotal` | DECIMAL(12,2) | Suma de líneas, sin IVA |
| `tax_amount` | DECIMAL(12,2) | IVA (21 % del subtotal) |
| `shipping_fee` | DECIMAL(12,2) | Costo de envío |
| `total_amount` | DECIMAL(12,2) | subtotal + IVA + envío |

#### `fact_sales` — líneas de pedido (14.573 filas)
| Columna | Tipo | Descripción / dominio |
|---|---|---|
| `order_item_id` | BIGINT **PK** | ID de la línea |
| `order_id` | BIGINT | Pedido al que pertenece (dimensión degenerada) |
| `date_key` | INTEGER **FK** → `dim_date` | Fecha del pedido |
| `customer_key` | INTEGER **FK** → `dim_customer` | Cliente |
| `product_key` | INTEGER **FK** → `dim_product` | Producto |
| `channel_key` | INTEGER **FK** → `dim_channel` | Canal |
| `store_key` | INTEGER **FK** → `dim_store` | Tienda (-1 si es online) |
| `province_key` | INTEGER **FK** → `dim_province` | Provincia |
| `status` | VARCHAR | Estado del pedido |
| `is_valid_sale` | BOOLEAN | TRUE si PAID o FULFILLED |
| `quantity` | INTEGER | Unidades |
| `unit_price` | DECIMAL(12,2) | Precio unitario sin IVA |
| `discount_amount` | DECIMAL(12,2) | Descuento |
| `line_total` | DECIMAL(12,2) | cantidad × precio − descuento |

#### `fact_web_session` — visitas web (100.363 filas)
| Columna | Tipo | Descripción / dominio |
|---|---|---|
| `session_id` | BIGINT **PK** | ID de la visita |
| `date_key` | INTEGER **FK** → `dim_date` | Fecha de inicio |
| `customer_key` | INTEGER **FK** → `dim_customer` | Cliente (-1 si no inició sesión) |
| `channel_key` | INTEGER **FK** → `dim_channel` | Siempre ONLINE |
| `source` | VARCHAR | ads / direct / referral / organic |
| `device` | VARCHAR | Dispositivo |
| `is_logged_in` | BOOLEAN | TRUE si el visitante inició sesión |
| `duration_seconds` | INTEGER | Duración de la visita (fin − inicio) |

#### `fact_nps` — respuestas NPS (3.083 filas)
| Columna | Tipo | Descripción / dominio |
|---|---|---|
| `nps_id` | BIGINT **PK** | ID de la respuesta |
| `date_key` | INTEGER **FK** → `dim_date` | Fecha de respuesta |
| `customer_key` | INTEGER **FK** → `dim_customer` | Cliente (-1 si es anónima) |
| `channel_key` | INTEGER **FK** → `dim_channel` | Canal |
| `score` | INTEGER | Puntaje 0–10 |
| `nps_category` | VARCHAR | Promotor (9–10) / Pasivo (7–8) / Detractor (0–6) |
| `is_promoter` | INTEGER | 1 si es promotor, 0 si no |
| `is_detractor` | INTEGER | 1 si es detractor, 0 si no |
| `comment` | VARCHAR | Comentario libre (opcional) |

#### `fact_payment` — pagos (11.969 filas)
| Columna | Tipo | Descripción / dominio |
|---|---|---|
| `payment_id` | BIGINT **PK** | ID del pago |
| `order_id` | BIGINT | Pedido (dimensión degenerada) |
| `date_key` | INTEGER **FK** → `dim_date` | Fecha del pedido |
| `customer_key` | INTEGER **FK** → `dim_customer` | Cliente |
| `channel_key` | INTEGER **FK** → `dim_channel` | Canal |
| `method` | VARCHAR | CASH / CARD / TRANSFER / GATEWAY |
| `status` | VARCHAR | PENDING / PAID / FAILED / REFUNDED |
| `amount` | DECIMAL(12,2) | Monto cobrado |
| `paid_at` | TIMESTAMP | Fecha de cobro (vacío si no se concretó) |
| `is_paid` | BOOLEAN | TRUE si el pago se concretó |

#### `fact_shipment` — envíos (7.009 filas)
| Columna | Tipo | Descripción / dominio |
|---|---|---|
| `shipment_id` | BIGINT **PK** | ID del envío |
| `order_id` | BIGINT | Pedido (dimensión degenerada) |
| `date_key` | INTEGER **FK** → `dim_date` | Fecha del pedido |
| `customer_key` | INTEGER **FK** → `dim_customer` | Cliente |
| `channel_key` | INTEGER **FK** → `dim_channel` | Canal |
| `store_key` | INTEGER **FK** → `dim_store` | Tienda (-1 si es online) |
| `province_key` | INTEGER **FK** → `dim_province` | Provincia de destino |
| `carrier` | VARCHAR | Correo (Correo Argentino) |
| `status` | VARCHAR | READY / SHIPPED / DELIVERED / CANCELLED |
| `shipped_at` | TIMESTAMP | Fecha de despacho |
| `delivered_at` | TIMESTAMP | Fecha de entrega |
| `transit_days` | INTEGER | Días entre despacho y entrega |
| `order_to_delivery_days` | INTEGER | Días entre la compra y la entrega |

---

## 5. Supuestos y decisiones

**Modelado**
- Se usan **claves subrogadas** (`_key`) generadas en el warehouse, y se conserva la **clave natural** (`_id`) para poder buscar cada registro al cargar los hechos.
- Las jerarquías se **aplanan** en las dimensiones (producto → categoría → familia; tienda → dirección → provincia) para mantener un esquema estrella y no un copo de nieve.
- Se agregó una fila **`-1`** en `dim_customer` (Desconocido), `dim_store` (Sin tienda / online) y `dim_province` (Desconocida), para que los hechos sin ese dato no queden con la FK vacía.
- Las ventas se modelan con **dos hechos de distinto grano**: `fact_orders` (cabecera) y `fact_sales` (líneas), porque los KPIs de la consigna usan montos de ambos niveles.
- `dim_date` se **genera** con un rango de días (01/01/2024 a 30/09/2025), que cubre todas las fechas de pedidos, visitas y encuestas.
- En `fact_payment` y `fact_shipment`, `date_key` es la **fecha del pedido** (siempre existe), para que los filtros por período queden alineados con las ventas. Las fechas exactas de pago, despacho y entrega se guardan como columnas aparte.
- `source` y `device` quedan como atributos dentro de `fact_web_session` por tener pocos valores.
- No se llevan al warehouse datos personales que no aportan al análisis (**email y teléfono** de clientes) ni códigos operativos (`transaction_ref`, `tracking_number`).
- Las transformaciones se escriben en **SQL** y las ejecuta el script de Python `run_sql.py`, siguiendo la estructura del repositorio de la cátedra.

**Métricas**
- **Venta válida:** pedido con estado `PAID` o `FULFILLED`. CREATED, CANCELLED y REFUNDED no cuentan como venta, pero se conservan en los hechos (indicador `is_valid_sale`).
- **Ventas, Ticket Promedio y Ventas por Provincia** usan `total_amount` (con IVA y envío), como define la consigna. El **ranking por producto** usa `line_total` (sin IVA ni envío), porque el envío y el IVA no se pueden asignar a un producto.
- **Provincia de una venta:** la de la dirección de envío. En compras en tienda, la dirección de envío es la de la tienda.
- **Usuarios activos:** clientes distintos que iniciaron sesión + cada sesión anónima como un usuario. Como ~96 % de las visitas son anónimas, el indicador tiende a sobreestimar (una misma persona sin loguearse cuenta una vez por visita). La suma de los meses no coincide con el total del período porque un cliente cuenta una vez por mes.
- Todas las visitas web se asignan al canal **ONLINE**.
- **NPS** = (% promotores − % detractores) × 100. Promotor: 9–10; Pasivo: 7–8; Detractor: 0–6.
- **Tiempos de entrega:** se calculan solo sobre envíos `DELIVERED`. Los pedidos de fines de septiembre 2025 que todavía no se entregaron al momento de la foto quedan afuera.
   **Dashboard**
   - El filtro de provincia no afecta Usuarios Activos ni NPS, y el de producto solo afecta el ranking: las visitas web y las encuestas no tienen provincia ni producto en los datos de origen, y las ventas por pedido pueden incluir varios productos.

---

## 6. KPIs y consultas clave

Todas las consultas están en [`sql/03_consultas.sql`](sql/03_consultas.sql). Resultados para el período completo (01/2024 – 09/2025):

| KPI | Resultado |
|---|---|
| Total Ventas | **$382,4M** (10.998 pedidos válidos) |
| Usuarios Activos | **73,8K** (3.077 clientes logueados + 70.751 sesiones anónimas) |
| Ticket Promedio | **$34,8K** |
| NPS | **30 puntos** (1.428 promotores, 503 detractores sobre 3.083 respuestas) |
| Ventas por Provincia | Buenos Aires 37,3 % · Córdoba 23,4 % · Santa Fe 22,9 % · Mendoza 16,4 % |

**Ventas por mes**
```sql
SELECT d.year_month, SUM(f.total_amount) AS ventas
FROM fact_orders AS f
JOIN dim_date    AS d ON d.date_key = f.date_key
WHERE f.is_valid_sale
GROUP BY d.year_month
ORDER BY d.year_month;
```

**Usuarios activos por mes**
```sql
SELECT d.year_month,
       COUNT(DISTINCT CASE WHEN f.is_logged_in THEN f.customer_key END)
         + COUNT(CASE WHEN NOT f.is_logged_in THEN 1 END) AS usuarios_activos
FROM fact_web_session AS f
JOIN dim_date         AS d ON d.date_key = f.date_key
GROUP BY d.year_month
ORDER BY d.year_month;
```

**Ticket promedio**
```sql
SELECT SUM(total_amount) / COUNT(*) AS ticket_promedio
FROM fact_orders
WHERE is_valid_sale;
```

**NPS por mes y canal**
```sql
SELECT d.year_month, ch.name AS canal,
       ROUND((SUM(f.is_promoter) - SUM(f.is_detractor)) * 100.0 / COUNT(*), 1) AS nps
FROM fact_nps    AS f
JOIN dim_date    AS d  ON d.date_key     = f.date_key
JOIN dim_channel AS ch ON ch.channel_key = f.channel_key
GROUP BY d.year_month, ch.name
ORDER BY d.year_month, ch.name;
```

**Ventas por provincia**
```sql
SELECT p.name AS provincia,
       SUM(f.total_amount) AS ventas,
       ROUND(SUM(f.total_amount) * 100.0 / SUM(SUM(f.total_amount)) OVER (), 1) AS porcentaje
FROM fact_orders  AS f
JOIN dim_province AS p ON p.province_key = f.province_key
WHERE f.is_valid_sale
GROUP BY p.name
ORDER BY ventas DESC;
```

**Ranking mensual por producto**
```sql
SELECT d.year_month, p.name AS producto,
       SUM(f.line_total) AS ventas,
       RANK() OVER (PARTITION BY d.year_month ORDER BY SUM(f.line_total) DESC) AS ranking
FROM fact_sales  AS f
JOIN dim_date    AS d ON d.date_key    = f.date_key
JOIN dim_product AS p ON p.product_key = f.product_key
WHERE f.is_valid_sale
GROUP BY d.year_month, p.name
ORDER BY d.year_month, ranking;
```

---

## 7. Hallazgos

**1. Crisis logística en julio–agosto 2024 y su impacto en la satisfacción.**
Los días entre la compra y la entrega casi se duplicaron en todas las provincias (Buenos Aires: de ~3,5 a ~8 días; interior: de ~5,5 a ~10 días) y volvieron a la normalidad en septiembre. En esos mismos dos meses el **NPS online cayó a −6 y −26,5**, mientras que el de las tiendas físicas (que no dependen del correo) se mantuvo en ~38. No es un efecto estacional: julio 2025 fue normal.

**2. La demora en las entregas no es exclusiva de Mendoza.**
En promedio, Mendoza (5,8 días) tarda lo mismo que Santa Fe y menos que **Córdoba (6,1 días)**, la más lenta. El tiempo de preparación es igual en todas las provincias (~1 día); la diferencia está en el viaje del correo. Se recomienda ampliar el objetivo de reducción de tiempos a Córdoba.

**3. Meta de Córdoba (+15 % de ventas).**
Contra el mismo trimestre del año anterior, Córdoba creció +12,4 % (T1 2025), +7,7 % (T2) y **+25,3 % (T3)**. Cumple la meta en el último trimestre, pero ese salto está inflado porque el T3 2024 fue anormalmente bajo por la crisis logística.

**Otras observaciones**
- **Estacionalidad:** diciembre es el pico de ventas y de usuarios activos ($28,4M en dic-2024) y julio es el mes más flojo en ambos años.
- **2025 crece respecto de 2024** en casi todos los meses comparables.
- **~8 % de los pedidos se pierde** (cancelados, devueltos o sin pagar): 971 de 11.969.
- **Las tiendas físicas tienen mejor NPS** que la tienda online casi todos los meses.
- **El ticket promedio es similar** en ambos canales (~$32K–$40K).
- **Classic A vende más unidades, pero Sport B factura más** por su mayor precio; el liderazgo del ranking se alterna mes a mes y Sport B tiene su pico en junio.

---

## 8. Dashboard

_[Agregar enlace al tablero y capturas.]_

Fuente: los CSV de la carpeta `dw/`. Filtros: fecha, canal, provincia y producto.

---

## 9. Convenciones del repositorio

- Entorno virtual (`.venv`) con dependencias en `requirements.txt`.
- Commits con **[Conventional Commits](https://www.conventionalcommits.org/es/)**: `feat(sql): ...`, `fix(sql): ...`, `docs: ...`.
- Toda la gestión del repositorio se hace desde la consola (`git add`, `git commit`, `git push`).
- `warehouse.duckdb` no se sube a GitHub (está en `.gitignore`): se regenera con `python run_sql.py`.
