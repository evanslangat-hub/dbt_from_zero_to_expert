# PART IX - CAPSTONE

# 18. Capstone: Build the ClearPay Lakehouse End to End

## 18.1 Scenario

You are the analytics engineer for **ClearPay**, a payments company. The commerce platform lands raw orders, customers, and line items in a Databricks bronze schema. Finance needs daily revenue, refunds, and customer lifetime value. Operations needs late-order and refund monitoring. The data team wants a governed, tested, documented dbt project with CI/CD and a small semantic layer.

Your job: take the raw data from zero to a production-ready dbt project, then defend your design decisions.

## 18.2 What you will build

```text
analytics_lab/
├── bronze/                 # raw tables (sources)
├── silver/                 # staging, intermediate, snapshots
└── gold/                   # facts, dimensions, reports, metrics
```

Models (minimum):

| Layer | Model | Grain | Materialization |
|---|---|---|---|
| Staging | `stg_orders` | one row per order | view |
| Staging | `stg_customers` | one row per customer | view |
| Staging | `stg_lineitems` | one row per order line | view |
| Staging | `stg_refunds` | one row per refund | view |
| Intermediate | `int_orders_enriched` | one row per order | view |
| Intermediate | `int_order_line_totals` | one row per order | view |
| Intermediate | `int_customer_order_history` | one row per customer | view |
| Mart | `fct_orders` | one row per order | incremental |
| Mart | `fct_refunds` | one row per refund | incremental |
| Mart | `dim_customers` | one row per customer | table |
| Mart | `dim_payment_methods` | one row per method | table |
| Report | `rpt_revenue_daily` | one row per day | table or MV |
| Report | `rpt_customer_lifetime_value` | one row per customer | table |

Plus:

- Source freshness on bronze tables.
- Generic tests on all keys and relationships.
- Singular tests for business rules (no negative revenue, refunds <= order total, no future dates).
- A unit test for the order-line aggregation.
- A contract on `fct_orders` and `dim_customers`.
- A snapshot of customers (SCD2).
- A materialized view or streaming table (choose one and justify).
- Semantic model + 3 metrics.
- Documentation with descriptions, exposures, and lineage.
- CI pipeline using `state:modified+`.
- An AI-assisted change, reviewed and validated.

## 18.3 Dataset setup

If `samples.tpch` is available:

```sql
CREATE OR REPLACE TABLE analytics_lab.bronze.orders_raw AS
SELECT *, current_timestamp() AS _ingested_at
FROM samples.tpch.orders;

CREATE OR REPLACE TABLE analytics_lab.bronze.customer_raw AS
SELECT *, current_timestamp() AS _ingested_at
FROM samples.tpch.customer;

CREATE OR REPLACE TABLE analytics_lab.bronze.lineitem_raw AS
SELECT *, current_timestamp() AS _ingested_at
FROM samples.tpch.lineitem;
```

Create the seeds:

`seeds/payment_methods.csv`:

```csv
payment_method_code,payment_method_name,is_refundable
1,Credit Card,true
2,Bank Transfer,true
3,Wallet,false
4,Cash,false
```

`seeds/refunds.csv`:

```csv
refund_id,order_id,refund_date,refund_amount,refund_reason
9001,1,2024-01-15,10.00,damaged
9002,2,2024-01-20,5.50,late_delivery
9003,3,2024-02-01,20.00,customer_request
```

`seeds/fx_rates.csv` (optional):

```csv
currency,rate_to_usd,rate_date
USD,1.0,2024-01-01
EUR,1.08,2024-01-01
GBP,1.27,2024-01-01
```

If `samples.tpch` is unavailable, use any small CSV and adapt column names. The architecture matters more than the exact data.

## 18.4 Milestones

### Milestone 0 - Project and repository

- Fix the project name/config mismatch (`dbt_dbx` vs `databricks_dbt`).
- Add `.gitignore` for `.venv`, `target/`, `dbt_packages/`, `logs/`, `profiles.yml`, `.env`.
- Add `requirements.txt` with pinned `dbt-databricks`.
- Commit a README with setup steps.
- Create `dev_<yourname>` schema for development.

**Done when:** `dbt debug` passes and a trivial model builds into your dev schema.

### Milestone 1 - Sources and staging

- Declare sources with descriptions, `loaded_at_field`, and freshness.
- Build the four staging models with explicit casts and deduplication where needed.
- Add PK tests (`unique`, `not_null`) and accepted values for statuses.
- Run `dbt build -s staging`.

**Done when:** all staging tests pass, and source freshness returns PASS/WARN with an explanation.

### Milestone 2 - Intermediate and marts

- Build the intermediates and marts in the table above.
- Add `relationships` tests from facts to dimensions.
- Add a singular test for negative revenue and future dates.
- Run `dbt build`.

**Done when:** the DAG builds, tests pass, and `rpt_revenue_daily` reconciles to `fct_orders` for three sample days.

### Milestone 3 - Contracts and unit tests

- Add contracts to `fct_orders` and `dim_customers` with explicit `data_type`s.
- Add a unit test for `int_order_line_totals` (two lines for one order).
- Break a column type intentionally and confirm the contract fails; then fix it.

**Done when:** contract and unit tests run in CI, and you can explain what each catches.

### Milestone 4 - Snapshot

- Add an `updated_at` column to `stg_customers` (or use the check strategy).
- Create `customers_snapshot` with `unique_key='customer_id'`.
- Update a customer's market segment in bronze, rerun the snapshot, and show the history.
- Add a test for one current row per customer.

**Done when:** the snapshot contains old and new versions with correct `dbt_valid_from`/`dbt_valid_to`.

### Milestone 5 - Incremental fact with late data

- Convert `fct_orders` to incremental with `merge` on `order_id`.
- Add a 3-day lookback.
- Simulate a late order and prove it is picked up.
- Run twice without changes and prove idempotency.
- Run `--full-refresh` and compare counts.

**Done when:** no duplicate keys, late data handled, and the full refresh matches the incremental result.

### Milestone 6 - Databricks optimization

Choose **one**:

- A materialized view `mv_revenue_daily` over `rpt_revenue_daily` with a schedule.
- A streaming table over JSON events in a Unity Catalog volume.
- Liquid clustering on `fct_orders` by `customer_id`.

Add `tblproperties` for auto-compaction. Measure query performance before/after.

**Done when:** you can explain the trade-off and show a before/after metric.

### Milestone 7 - Semantic layer

- Add a semantic model to `fct_orders` with `order` primary entity, `customer` foreign entity, time dimension `order_date`, and simple metrics `order_revenue`, `order_count`.
- Add a semantic model to `dim_customers` with `customer` primary entity and `market_segment` dimension.
- Add `average_order_value` as a ratio metric.
- Query revenue by market segment and by month.
- Document the metric definitions.

**Done when:** two consumers (for example, a CLI query and a BI tool) return the same revenue for the same period.

### Milestone 8 - CI/CD

- Add a GitHub Actions workflow using a service principal.
- Use `dbt build -s state:modified+ --defer --state <prod-manifest>`.
- Add a production job (dbt platform, Databricks Workflows, or Airflow).
- Add failure notifications.
- Add a cleanup step for CI schemas.

**Done when:** a PR runs a slim CI build and a merge triggers production.

### Milestone 9 - Observability and docs

- Add exposures for the finance dashboard and the operations alert.
- Generate docs and verify lineage from source to exposure.
- Add Elementary or a simple artifact dashboard for test results.
- Add a runbook: what to do when a test fails.

**Done when:** a new team member can navigate from a dashboard to the source table using docs.

### Milestone 10 - Governance

- Add groups/owners and tags to all marts.
- Add `databricks_tags` and a column mask for a PII column.
- Grant `SELECT` on gold to an analyst group.
- Make `fct_orders` and `dim_customers` public with contracts.
- Run `dbt_project_evaluator` and fix the top five issues.

**Done when:** access is least-privilege and ownership is visible in docs.

### Milestone 11 - AI and v2 readiness

- Use Wizard, Copilot, or an MCP-connected agent to add one model with tests and docs. Review the diff and validate with `dbt build`.
- Configure an agent skill with your conventions.
- Run `dbt parse --use-v2-parser`; fix any issues.
- Write a short evaluation: what the AI did well, what it missed, and how you verified it.

**Done when:** the AI-assisted change is merged through the normal PR process with human review.

### Milestone 12 - Present and defend

Prepare a 15-minute walkthrough:

1. Architecture and layering.
2. Grain and key decisions for each mart.
3. Testing strategy and what would wake you up at night.
4. Incremental/late-data handling.
5. Cost/performance choices.
6. Governance and access.
7. What you would do next with more time.

**Done when:** you can answer the interview questions in Part X about your own project.

## 18.5 Acceptance rubric

| Area | Needs work (1) | Good (3) | Excellent (5) |
|---|---|---|---|
| Modeling | Duplicated logic, unclear grain | Layered, named consistently, documented | Clear contracts, reusable intermediates, justified materializations |
| Testing | Only PK tests | PK/FK, accepted values, business rules | Unit tests, contracts, freshness, failure ownership, cheap tests |
| Incremental | Full rebuild only | Merge with key | Late data, idempotency, backfill plan, monitoring |
| Databricks | Default table/view | Partition/cluster or MV | Measured performance/cost, correct UC governance |
| CI/CD | Manual runs | PR build + prod job | Slim CI, deferral, alerts, rollback |
| Docs | Model names only | Descriptions + lineage | Exposures, ownership, runbook, metric definitions |
| Security | Broad grants | Group grants | Masks/row filters, least privilege, audit |
| AI | None | Used for a small task | Validated, governed, with a skill and evaluation |

Target: at least "Good" in every area, "Excellent" in three.

## 18.6 Validation queries

```sql
-- Row counts by layer
select 'stg_orders' as model, count(*) from analytics_lab.silver.stg_orders
union all
select 'fct_orders', count(*) from analytics_lab.gold.fct_orders
union all
select 'dim_customers', count(*) from analytics_lab.gold.dim_customers;

-- Duplicate keys
select order_id, count(*) c
from analytics_lab.gold.fct_orders
group by 1 having c > 1;

-- Orphan customers
select count(*)
from analytics_lab.gold.fct_orders f
left join analytics_lab.gold.dim_customers d using (customer_id)
where d.customer_id is null;

-- Revenue reconciliation
select
    (select sum(order_total) from analytics_lab.gold.fct_orders) as fact_revenue,
    (select sum(revenue) from analytics_lab.gold.rpt_revenue_daily) as report_revenue;
```

## 18.7 Stretch goals

- Add a second source system (for example, payments or refunds from a JSON volume) and a streaming table.
- Implement SCD2 for products.
- Add a dbt Mesh project for finance with a public `fct_orders`.
- Build a metrics API or BI dashboard on the Semantic Layer.
- Add a data contract with a schema registry.
- Implement cost anomaly alerts from `system.billing.usage`.
- Write a migration plan to dbt v2 and run CI in parallel.

## 18.8 Capstone questions

1. Why did you choose view/table/incremental/MV for each model?
2. What is the grain of each mart, and how is it enforced?
3. Which test would catch a 10% revenue drop? Which would not?
4. How does your pipeline handle a late-arriving order?
5. What happens if the source schema adds a column?
6. How do you roll back a bad deployment?
7. Where is PII, and who can see it?
8. What is your cost per run, and how would you reduce it by 30%?
9. Which parts of the project would break if you moved to dbt v2 today?
10. What did the AI get wrong, and how did you catch it?
