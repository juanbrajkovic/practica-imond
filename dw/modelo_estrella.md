# Modelo estrella

Generado por `run_sql.py` a partir de las tablas de `warehouse.duckdb`.

```mermaid
erDiagram
    dim_channel {
        INTEGER channel_key PK
        INTEGER channel_id
        VARCHAR code
        VARCHAR name
    }
    dim_customer {
        INTEGER customer_key PK
        INTEGER customer_id
        VARCHAR full_name
        VARCHAR status
        TIMESTAMP created_at
    }
    dim_date {
        INTEGER date_key PK
        DATE date
        INTEGER year
        INTEGER quarter
        INTEGER month
        VARCHAR month_name
        VARCHAR year_month
        INTEGER day
        VARCHAR day_name
        BOOLEAN is_weekend
    }
    dim_product {
        INTEGER product_key PK
        INTEGER product_id
        VARCHAR sku
        VARCHAR name
        VARCHAR category
        VARCHAR family
        DECIMAL list_price
    }
    dim_province {
        INTEGER province_key PK
        INTEGER province_id
        VARCHAR code
        VARCHAR name
    }
    dim_store {
        INTEGER store_key PK
        INTEGER store_id
        VARCHAR name
        VARCHAR address
        VARCHAR city
        VARCHAR province
    }
```
