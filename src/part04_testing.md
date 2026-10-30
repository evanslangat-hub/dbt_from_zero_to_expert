# PART IV - TRUST

# 7. Testing, Unit Tests, and Contracts

## 7.1 The testing mindset

A dbt test is a SQL query that returns **rows that violate an expectation**. If the query returns zero rows, the test passes. This is simple and powerful: you can test anything expressible in SQL.

There are four layers of trust:

| Layer | Question | Tool |
|---|---|---|
| Schema tests | Are keys unique, non-null, and related? | Generic tests in YAML |
| Business tests | Does the logic match the business rule? | Singular tests, dbt_expectations |
| Unit tests | Does this model produce the expected output for known input? | dbt unit tests |
| Contracts | Does the model's shape match the promised schema? | Model contracts |

## 7.2 Generic tests

Built-in generic tests:

- `unique`
- `not_null`
- `accepted_values`
- `relationships`

```yaml
version: 2

models:
  - name: fct_orders
    columns:
      - name: order_id
        data_tests:
          - unique
          - not_null
      - name: order_status
        data_tests:
          - accepted_values:
              values: ["O", "P", "F"]
              quote: true
      - name: customer_id
        data_tests:
          - relationships:
              to: ref('dim_customers')
              field: customer_id
```

Configuration options:

```yaml
data_tests:
  - unique:
      severity: warn
      config:
        where: "order_date >= current_date - interval 30 days"
        limit: 100
        store_failures: true
```

`store_failures: true` writes failing rows to a table in the target schema (named `<model>_<test>`). This is invaluable for debugging, but it creates objects; clean them up or use a dedicated schema.

## 7.3 Severity and thresholds

| Severity | Effect |
|---|---|
| `error` (default) | Test failure fails the build; downstream models are skipped |
| `warn` | Logs a warning; build continues |

Use `warn` for new tests that may be noisy, then promote to `error` after cleaning the data. Do not leave warnings forever; they become noise.

## 7.4 Singular tests

A singular test is a SQL file in `tests/` that returns failing rows:

`tests/assert_order_total_non_negative.sql`:

```sql
select *
from {{ ref('fct_orders') }}
where order_total < 0
```

`tests/assert_no_future_orders.sql`:

```sql
select *
from {{ ref('fct_orders') }}
where order_date > current_date()
```

Run:

```powershell
dbt test --select assert_order_total_non_negative
```

Singular tests are best for cross-column or business rules that generic tests cannot express. Keep them small and named after the assertion.

## 7.5 Custom generic tests

Create `macros/test_positive_value.sql`:

```jinja
{% test positive_value(model, column_name) %}
    select *
    from {{ model }}
    where {{ column_name }} < 0
{% endtest %}
```

Use it:

```yaml
columns:
  - name: order_total
    data_tests:
      - positive_value
```

With arguments:

```jinja
{% test value_between(model, column_name, min_value, max_value) %}
    select *
    from {{ model }}
    where {{ column_name }} < {{ min_value }}
       or {{ column_name }} > {{ max_value }}
{% endtest %}
```

```yaml
data_tests:
  - value_between:
      min_value: 0
      max_value: 1000000
```

Custom tests are reusable across models and packages. Namespace them with a package if you distribute them.

## 7.6 Unit tests

Unit tests validate a model's logic with fixed inputs, without depending on warehouse data. They are fast, deterministic, and ideal for complex SQL.

```yaml
version: 2

unit_tests:
  - name: test_fct_orders_revenue
    model: fct_orders
    given:
      - input: ref('stg_orders')
        rows:
          - {order_id: 1, customer_id: 10, order_date: 2024-01-01, order_status: F, order_total: 100}
          - {order_id: 2, customer_id: 11, order_date: 2024-01-02, order_status: O, order_total: 200}
      - input: ref('int_order_line_totals')
        rows:
          - {order_id: 1, line_count: 2, total_quantity: 3, net_line_revenue: 90, gross_line_revenue: 108}
          - {order_id: 2, line_count: 1, total_quantity: 1, net_line_revenue: 200, gross_line_revenue: 240}
    expect:
      rows:
        - {order_id: 1, order_total: 100, line_count: 2, net_line_revenue: 90}
        - {order_id: 2, order_total: 200, line_count: 1, net_line_revenue: 200}
```

Notes:

- Unit tests can override macros, vars, and inputs.
- They run with `dbt test` (or `dbt build`) and are included in `dbt test --select test_type:unit`.
- Unit tests are not a replacement for data tests; they test logic, not production data.
- In dbt v2, `dbt build` runs all unit tests first. Local execution with DuckDB is experimental (`compute: local`).

Run only unit tests:

```powershell
dbt test --select test_type:unit
```

## 7.7 Model contracts

A contract declares the model's column names and data types and enforces them at build time.

```yaml
models:
  - name: fct_orders
    config:
      contract:
        enforced: true
    columns:
      - name: order_id
        data_type: bigint
        constraints:
          - type: not_null
      - name: customer_id
        data_type: bigint
      - name: order_date
        data_type: date
      - name: order_total
        data_type: decimal(18,2)
```

Requirements:

- Every column in the model must be listed with a `data_type`.
- The model's SQL must produce exactly those columns (order can be enforced).
- Contracts are supported for table, view, incremental, and materialized view; not ephemeral.
- Databricks enforces `not_null` and `check` constraints where supported; primary/foreign key constraints are informational in many cases (verify current Databricks behavior).

Contracts are a commitment to downstream consumers. Use them for public marts, not every staging model.

## 7.8 Source freshness

Freshness answers: "Is the raw data recent enough?" Configure it on sources:

```yaml
sources:
  - name: bronze
    schema: bronze
    tables:
      - name: orders_raw
        loaded_at_field: _ingested_at
        freshness:
          warn_after: {count: 6, period: hour}
          error_after: {count: 24, period: hour}
        filter: "_ingested_at >= current_date - interval 7 days"
```

Run:

```powershell
dbt source freshness
```

Results go to `target/sources.json`. In dbt v2, `dbt freshness` also checks models with freshness configured.

Freshness is not a data quality test; it checks timestamps. Pair it with row-count and null tests.

## 7.9 Testing strategy by layer

| Layer | Minimum tests | Why |
|---|---|---|
| Staging | PK unique + not_null; accepted values for statuses | Catch source anomalies early |
| Intermediate | Uniqueness at the intended grain; relationships | Catch join fan-out |
| Facts | PK unique + not_null; FK relationships; amount ranges | Trust the numbers |
| Dimensions | PK unique + not_null; one row per entity | Prevent duplicate dimensions |
| Reports | Row count > 0; reconciliation to source | Catch empty/broken dashboards |

The testing pyramid for data:

1. Many cheap schema tests on keys.
2. Some business-rule tests on marts.
3. A few unit tests for complex logic.
4. Contracts on public interfaces.
5. Freshness and volume checks for operations.

## 7.10 Testing anti-patterns

| Anti-pattern | Problem | Fix |
|---|---|---|
| Testing everything as `error` on day one | Noisy failures block delivery | Start with `warn`, clean data, promote |
| No `where` on huge tests | Full scans cost money | Filter to recent partitions |
| Testing only at the end | Bugs are expensive to trace | Test staging and intermediate |
| Assuming tests replace contracts | Shape changes still break consumers | Use contracts on public marts |
| Ignoring warnings | Real issues get lost | Triage and fix or remove |
| Tests that depend on current date | Flaky at month boundaries | Use fixed dates or vars |
| No ownership | Failures have no owner | Tag models/tests with a team |

## 7.11 Exercises

**Exercise 7.1 - Generic tests.** Add `unique` and `not_null` to `stg_orders.order_id`, `accepted_values` to `order_status`, and `relationships` from `fct_orders.customer_id` to `dim_customers.customer_id`.

**Exercise 7.2 - Singular test.** Write a test that fails if any `fct_orders.order_date` is in the future. Run it.

**Exercise 7.3 - Custom generic test.** Write `not_negative` and apply it to `order_total` and `net_line_revenue`.

**Exercise 7.4 - Unit test.** Write a unit test for `int_order_line_totals` with two line items for one order. Assert the count and sum.

**Exercise 7.5 - Contract.** Add a contract to `dim_customers` with explicit data types for five columns. Intentionally add an extra column to the model and observe the failure.

**Exercise 7.6 - Freshness.** Configure freshness on `orders_raw` with a `loaded_at_field`. Run `dbt source freshness` and interpret the result.

**Answers.** 7.1: Add tests under each column in YAML. 7.2: `where order_date > current_date()`. 7.3: `{% test not_negative(model, column_name) %} ... where {{ column_name }} < 0 {% endtest %}`. 7.4: Use `given` for `stg_lineitems` and `expect` for the aggregate. 7.5: The contract failure lists missing/extra columns. 7.6: `PASS`, `WARN`, or `ERROR` with max loaded timestamp.

## 7.12 Interview check

- What does a dbt test return when it passes?
- Difference between a generic test and a singular test?
- When would you use a unit test instead of a data test?
- What does a model contract enforce on Databricks?
- How do you test an incremental model?
- How do you keep tests cheap on a billion-row table?
- What is the difference between source freshness and a data test?

# 8. Sources, Seeds, Snapshots, and Documentation

## 8.1 Sources in depth

A source definition is a contract with the ingestion layer. Include:

- `name`: logical source name.
- `catalog`/`database` and `schema`.
- `tables` with `name`, optional `identifier`, `description`.
- `loaded_at_field` and freshness.
- `quoting` when identifiers are case-sensitive.
- `meta` for ownership, PII, SLA.
- `columns` with tests and descriptions.

```yaml
version: 2

sources:
  - name: bronze
    catalog: analytics_lab
    schema: bronze
    description: "Raw landing zone; append-only."
    meta:
      owner: "data-platform"
      sla: "hourly"
    freshness:
      warn_after: {count: 2, period: hour}
      error_after: {count: 6, period: hour}
    tables:
      - name: orders_raw
        description: "Order headers from the commerce platform."
        loaded_at_field: _ingested_at
        columns:
          - name: o_orderkey
            description: "Order key."
            data_tests:
              - unique
              - not_null
      - name: customer_raw
        description: "Customer master data."
        loaded_at_field: _ingested_at
```

### Source tests

You can test source columns directly; failures indicate ingestion or schema problems, not model bugs. This is valuable for early warning.

### Source quoting

```yaml
sources:
  - name: legacy
    schema: "Sales"
    quoting:
      database: true
      schema: true
      identifier: true
```

Use quoting only when needed; it makes SQL case-sensitive.

### Source freshness filters

For large append-only tables, filter to recent partitions:

```yaml
filter: "_ingested_at >= current_date - interval 2 days"
```

This makes freshness cheap.

## 8.2 Seeds

Seeds are CSV files in `seeds/` that dbt loads as tables. They are version-controlled reference data, not a production ingestion mechanism.

`seeds/payment_methods.csv`:

```csv
payment_method_code,payment_method_name,is_refundable
1,Credit Card,true
2,Bank Transfer,true
3,Wallet,false
4,Cash,false
```

`dbt_project.yml`:

```yaml
seeds:
  dbt_dbx:
    +schema: utility
    +quote_columns: false
```

Load:

```powershell
dbt seed
dbt seed --full-refresh
```

Use seeds for:

- Small lookup tables (country codes, payment methods).
- Static mappings that analysts should review.
- Test fixtures.

Do not use seeds for:

- Large datasets (they are versioned in Git and loaded on every run).
- Frequently changing data.
- PII or secrets.
- Data that belongs in ingestion.

### Seed configuration

Per-seed in `seeds/_seeds.yml`:

```yaml
version: 2

seeds:
  - name: payment_methods
    description: "Payment method lookup."
    config:
      column_types:
        payment_method_code: int
        payment_method_name: string
        is_refundable: boolean
      delimiter: ","
      quote_columns: false
```

### Seed tests

Seeds support the same tests:

```yaml
seeds:
  - name: payment_methods
    columns:
      - name: payment_method_code
        data_tests: [unique, not_null]
```

## 8.3 Snapshots (SCD Type 2)

A snapshot records how a row changes over time. It produces a history table with `dbt_valid_from`, `dbt_valid_to`, and (optionally) `dbt_scd_id`, `dbt_updated_at`, `dbt_is_deleted`.

Why: source systems overwrite data. If a customer changes address, the source keeps only the new address. A snapshot preserves the old address and when it changed.

### Timestamp strategy

Use when the source has an `updated_at` column that changes on every update.

`snapshots/customers_snapshot.sql`:

```sql
{% snapshot customers_snapshot %}

{{
    config(
        target_schema='silver',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at',
        hard_deletes='invalidate'
    )
}}

select
    customer_id,
    customer_name,
    market_segment,
    updated_at
from {{ ref('stg_customers') }}

{% endsnapshot %}
```

### Check strategy

Use when there is no reliable `updated_at`; dbt compares a list of columns.

```sql
{% snapshot customers_snapshot_check %}

{{
    config(
        target_schema='silver',
        unique_key='customer_id',
        strategy='check',
        check_cols=['customer_name', 'market_segment']
    )
}}

select
    customer_id,
    customer_name,
    market_segment
from {{ ref('stg_customers') }}

{% endsnapshot %}
```

### Key configs

| Config | Meaning |
|---|---|
| `unique_key` | Business key of the row |
| `strategy` | `timestamp` or `check` |
| `updated_at` | Timestamp column for timestamp strategy |
| `check_cols` | Columns to compare, or `all` |
| `hard_deletes` | `ignore`, `invalidate`, or `new_record` (version-dependent) |
| `invalidate_hard_deletes` | Legacy way to mark deleted rows |
| `snapshot_meta_column_names` | Rename metadata columns |
| `dbt_valid_to_current` | Use a sentinel date for current rows instead of null |
| `target_schema` | Where to write the snapshot |

Run:

```powershell
dbt snapshot
```

Query:

```sql
select *
from analytics_lab.silver.customers_snapshot
where dbt_valid_to is null;  -- current records
```

### Snapshot best practices

- Snapshot a **staging** model, not a mart.
- Choose a stable `unique_key`; changes to it create new history rows.
- Timestamp strategy is cheaper and more reliable when a trustworthy `updated_at` exists.
- Snapshot tables grow forever; plan retention and clustering.
- Test uniqueness of `(unique_key, dbt_valid_from)`.
- Do not `--full-refresh` snapshots casually; you can lose history.
- Document what a change means (address change, plan change, etc.).

## 8.4 Documentation

dbt docs are generated from:

- Model/source/seed/snapshot descriptions in YAML.
- Column descriptions.
- Doc blocks (reusable Markdown).
- Exposures (dashboards, ML models, apps).
- Tests and lineage.

Generate and serve:

```powershell
dbt docs generate
dbt docs serve --port 8080
```

Artifacts:

- `target/manifest.json`: full project graph.
- `target/catalog.json`: warehouse metadata (columns, types, stats).
- `target/run_results.json`: execution results.
- `target/sources.json`: freshness results.

### Doc blocks

`models/docs.md`:

```markdown
{% docs order_status %}
One of:
- `O`: order placed
- `P`: order shipped/processing
- `F`: order fulfilled
{% enddocs %}
```

Reference it:

```yaml
columns:
  - name: order_status
    description: "{{ doc('order_status') }}"
```

### Exposures

Exposures document downstream consumers:

```yaml
version: 2

exposures:
  - name: revenue_dashboard
    type: dashboard
    maturity: high
    url: https://bi.example.com/dashboards/123
    description: "Daily revenue dashboard for finance."
    owner:
      name: Finance Analytics
      email: finance-analytics@example.com
    depends_on:
      - ref('rpt_revenue_daily')
      - ref('fct_orders')
    tags: ["finance"]
```

Exposures appear in lineage and help assess impact: "If I change `fct_orders`, which dashboards break?"

### Documentation quality

- Describe the grain ("one row per order").
- Describe caveats ("excludes test orders", "revenue is net of refunds").
- Define ambiguous terms ("active customer").
- Link to source systems and owners.
- Keep docs close to code; review them in PRs.

## 8.5 Exercises

**Exercise 8.1 - Source.** Declare `lineitem_raw` as a source with a description and a `loaded_at_field`. Add a `unique` test on `(order_id, line_number)` using a custom test or a singular test.

**Exercise 8.2 - Seed.** Create `payment_methods.csv`, load it, and join it to `stg_orders` in an intermediate model. Add a `not_null` test.

**Exercise 8.3 - Snapshot.** Create a timestamp snapshot of `stg_customers` using an `updated_at` column. If your source lacks one, add a synthetic `updated_at` in staging or use the check strategy. Update a customer's name in the raw table, rerun the snapshot, and query the history.

**Exercise 8.4 - Docs.** Add a doc block for `order_status` and reference it from `fct_orders`. Add an exposure for `rpt_revenue_daily`.

**Exercise 8.5 - Impact.** Use `dbt list -s +exposure:revenue_dashboard` to see everything the dashboard depends on. What would break if `stg_orders` changed?

**Answers.** 8.1: Use a singular test with `group by order_id, line_number having count(*) > 1`. 8.3: The old row gets `dbt_valid_to` set and a new row is inserted with `dbt_valid_to = null`. 8.5: The list includes the exposure's parents; direct changes to staging propagate to the fact and report.

## 8.6 Interview check

- What is the difference between a seed and a source?
- When would you snapshot a source versus a staging model?
- Timestamp vs check strategy: trade-offs?
- How do you document a dashboard dependency?
- What happens to a snapshot when a row is deleted?
- How do you test a snapshot?
- What is in `catalog.json` that is not in `manifest.json`?
