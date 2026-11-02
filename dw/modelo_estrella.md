# Modelo estrella

Generado por `run_sql.py` a partir de las tablas de `warehouse.duckdb`.

```mermaid
erDiagram
    dim_channel ||--o{ fact_nps : "channel_key"
    dim_channel ||--o{ fact_orders : "channel_key"
    dim_channel ||--o{ fact_sales : "channel_key"
    dim_customer ||--o{ fact_nps : "customer_key"
    dim_customer ||--o{ fact_orders : "customer_key"
    dim_customer ||--o{ fact_sales : "customer_key"
    dim_date ||--o{ fact_nps : "date_key"
    dim_date ||--o{ fact_orders : "date_key"
    dim_date ||--o{ fact_sales : "date_key"
    dim_product ||--o{ fact_sales : "product_key"
    dim_province ||--o{ fact_orders : "province_key"
    dim_province ||--o{ fact_sales : "province_key"
    dim_store ||--o{ fact_orders : "store_key"
    dim_store ||--o{ fact_sales : "store_key"
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
    fact_nps {
        BIGINT nps_id PK
        INTEGER date_key FK
        INTEGER customer_key FK
        INTEGER channel_key FK
        INTEGER score
        VARCHAR nps_category
        INTEGER is_promoter
        INTEGER is_detractor
        VARCHAR comment
    }
    fact_orders {
        BIGINT order_id PK
        INTEGER date_key FK
        INTEGER customer_key FK
        INTEGER channel_key FK
        INTEGER store_key FK
        INTEGER province_key FK
        VARCHAR status
        BOOLEAN is_valid_sale
        DECIMAL subtotal
        DECIMAL tax_amount
        DECIMAL shipping_fee
        DECIMAL total_amount
    }
    fact_sales {
        BIGINT order_item_id PK
        BIGINT order_id
        INTEGER date_key FK
        INTEGER customer_key FK
        INTEGER product_key FK
        INTEGER channel_key FK
        INTEGER store_key FK
        INTEGER province_key FK
        VARCHAR status
        BOOLEAN is_valid_sale
        INTEGER quantity
        DECIMAL unit_price
        DECIMAL discount_amount
        DECIMAL line_total
    }
```
