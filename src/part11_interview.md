# PART X - MASTERY

# 19. Interview Questions and Answers (100+)

Use these for self-testing. Cover the answer, then explain it out loud as if you were in an interview. Answers are deliberately concise; add examples from your capstone.

## 19.1 Fundamentals

| # | Question | Answer |
|---|---|---|
| 1 | What is dbt? | A transformation framework that compiles Jinja+SQL, builds a DAG, executes models/tests in dependency order, and produces docs/artifacts inside the warehouse. |
| 2 | What does dbt not do? | Extract/load data, store data, replace a general-purpose scheduler or BI tool. |
| 3 | ETL vs ELT? | ETL transforms before loading; ELT loads raw then transforms in the warehouse. dbt is an ELT transformation tool. |
| 4 | What is a model? | A SQL `SELECT` file that dbt persists as a view/table/incremental/etc. |
| 5 | What does `ref()` do? | Resolves the correct relation for the target and adds a DAG dependency. |
| 6 | `ref()` vs `source()`? | `ref()` points to a dbt model; `source()` points to declared raw tables. |
| 7 | What is a DAG? | A directed acyclic graph of nodes and dependencies; dbt uses it for ordering and parallelism. |
| 8 | What is a materialization? | The strategy for persisting a model (view, table, incremental, ephemeral, MV, streaming table). |
| 9 | What is a profile? | Connection/environment configuration (`profiles.yml`): adapter, host, catalog, schema, credentials, threads. |
| 10 | What is the target? | The active output in a profile (`dev`, `ci`, `prod`). |
| 11 | What is an adapter? | A plugin that translates dbt operations into a warehouse's SQL/API (e.g., dbt-databricks). |
| 12 | What is a macro? | A reusable Jinja function that returns SQL or a value. |
| 13 | What is a package? | A distributable collection of macros/models/tests installed via `packages.yml`. |
| 14 | What is an artifact? | Generated metadata: `manifest.json`, `run_results.json`, `catalog.json`, `sources.json`. |
| 15 | Why version-control dbt? | Reviewable logic, reproducibility, CI, rollback, collaboration. |

## 19.2 Modeling

| # | Question | Answer |
|---|---|---|
| 16 | What is a staging model? | A 1:1-ish model over a source that renames, casts, and cleans; no business logic. |
| 17 | What is an intermediate model? | Reusable business logic/joins between staging and marts; often not exposed to BI. |
| 18 | What is a mart? | A consumption-ready fact, dimension, or report model. |
| 19 | What is grain? | The meaning of one row (e.g., one row per order). It must be declared and tested. |
| 20 | Fact vs dimension? | Facts are events/measurements (orders, payments); dimensions are descriptive context (customer, product). |
| 21 | Surrogate key vs natural key? | Surrogate is generated (hash/sequence); natural is from the business data. |
| 22 | Why avoid `select *` in marts? | Hides schema changes, breaks contracts, scans unused columns, makes lineage unclear. |
| 23 | How do you deduplicate? | `row_number() over (partition by key order by updated_at desc)` + filter = 1, or `qualify`. |
| 24 | How do you handle fan-out? | Check cardinality before joining; aggregate to the target grain; test uniqueness after joins. |
| 25 | What is a slowly changing dimension? | A dimension that changes over time; Type 2 preserves history with valid-from/valid-to. |
| 26 | Star schema vs wide table? | Star is normalized for reuse/governance; wide tables are denormalized for a specific consumer. |
| 27 | Where does business logic live? | In intermediate/marts or macros, never duplicated across models. |
| 28 | How do you name models? | `stg_`, `int_`, `fct_`, `dim_`, `rpt_`; plural entities; `_id`, `_at`, `_date`, `is_` conventions. |
| 29 | How do you choose a materialization? | Based on size, freshness, query frequency, recompute cost, and warehouse features. |
| 30 | What is an ephemeral model? | A model inlined as a CTE; no relation, not directly queryable/testable. |

## 19.3 Jinja, macros, packages

| # | Question | Answer |
|---|---|---|
| 31 | Why use Jinja? | Reuse logic, parameterize environments, generate SQL dynamically. |
| 32 | `{{ }}` vs `{% %}`? | Output vs statement/control flow. |
| 33 | What is `is_incremental()`? | True only when the target exists, is incremental, and this is not a full refresh. |
| 34 | What is `this`? | The current model's relation object. |
| 35 | What does `run_query` do? | Executes SQL and returns a result table; guard with `execute`. |
| 36 | Why is `execute` important? | During parsing, dbt does not run queries; introspection should be skipped. |
| 37 | What is `adapter.dispatch`? | Selects an adapter-specific macro implementation for cross-platform projects. |
| 38 | Macro vs model for logic? | Macros for reusable SQL fragments; models for persisted, testable transformations. |
| 39 | How do you test a macro? | Use it in a model with known inputs, unit-test the model, or `dbt run-operation` for side effects. |
| 40 | What is `dbt_utils.generate_surrogate_key`? | A null-safe hash over a list of columns. |
| 41 | Risk of packages? | Supply-chain risk, version drift, incompatible macros, hidden introspection cost. |
| 42 | How do you pin packages? | Exact version or narrow range; commit `package-lock.yml`; test upgrades. |

## 19.4 Testing and contracts

| # | Question | Answer |
|---|---|---|
| 43 | How does a dbt test work? | A SQL query returns failing rows; zero rows = pass. |
| 44 | Generic vs singular test? | Generic is reusable via YAML (`unique`, `relationships`); singular is a one-off SQL file in `tests/`. |
| 45 | What are the four built-in tests? | `unique`, `not_null`, `accepted_values`, `relationships`. |
| 46 | How do you make a test warn only? | `severity: warn` in the test config. |
| 47 | What does `store_failures` do? | Writes failing rows to a table for debugging. |
| 48 | Unit test vs data test? | Unit tests use fixed inputs to test logic; data tests validate production data. |
| 49 | What does a contract enforce? | Column names/types (and constraints) at build time; it fails if the model doesn't match. |
| 50 | Where are contracts supported? | Table, view, incremental, materialized view; not ephemeral. |
| 51 | How do you test an incremental model? | Run twice, check idempotency/duplicate keys, test late data, and compare to a full refresh. |
| 52 | How do you keep tests cheap? | Filter recent partitions, test smaller staging models, use unit tests, batch tests, and thresholds. |
| 53 | What is source freshness? | A timestamp-based check that raw data is recent; not a substitute for data tests. |
| 54 | What is a flaky test? | A test whose result depends on time/order/volatile data; fix by fixing dates or isolating data. |
| 55 | What test catches duplicate joins? | `unique` on the expected grain + `relationships` on foreign keys. |

## 19.5 Sources, seeds, snapshots, docs

| # | Question | Answer |
|---|---|---|
| 56 | Why declare sources? | Lineage, freshness, tests, environment portability, documentation. |
| 57 | When use a seed? | Small, static reference data under version control. Never large or frequently changing data. |
| 58 | How do you load a seed? | `dbt seed`; `--full-refresh` to reload. |
| 59 | What is a snapshot? | An SCD2 history table tracking row changes over time. |
| 60 | Timestamp vs check strategy? | Timestamp uses an `updated_at` column; check compares selected columns (more expensive, works without a timestamp). |
| 61 | What happens on a hard delete? | Depends on `hard_deletes`/`invalidate_hard_deletes`; it can be ignored or marked invalid. |
| 62 | How do you query current snapshot rows? | `where dbt_valid_to is null` (or the configured current sentinel). |
| 63 | Should you snapshot a mart? | No; snapshot a staging model closest to the source. |
| 64 | What is an exposure? | A documented downstream consumer (dashboard, app, ML model) with dependencies. |
| 65 | What is a doc block? | Reusable Markdown referenced with `{{ doc('name') }}`. |
| 66 | What is in `catalog.json`? | Warehouse metadata: columns, types, stats, and table info from `dbt docs generate`. |
| 67 | How do you measure impact? | `dbt ls -s +exposure:name` and lineage in docs. |

## 19.6 Incremental and microbatch

| # | Question | Answer |
|---|---|---|
| 68 | How does incremental work? | First run creates a table; later runs apply a strategy (merge/append/replace) to new/changed rows. |
| 69 | When is `is_incremental()` false? | First run, full refresh, or non-incremental materialization. |
| 70 | What does `unique_key` do? | Identifies rows for merge/update/delete strategies. |
| 71 | Merge without `unique_key`? | It inserts all new rows (append-like). |
| 72 | `merge` vs `delete+insert`? | Merge updates matched rows; delete+insert deletes matching keys and inserts whole records. |
| 73 | What does `replace_where` require? | Delta and `incremental_predicates`; replaces only matching rows. |
| 74 | What does `insert_overwrite` do? | Replaces entire partitions/clusters returned by the query. |
| 75 | What is `on_schema_change`? | Controls how schema changes are handled (`ignore`, `fail`, `append_new_columns`, `sync_all_columns`). |
| 76 | How do you handle late data? | Lookback window, high-water mark with buffer, merge by key, or microbatch `lookback`. |
| 77 | How do you backfill? | `--full-refresh` for a full rebuild; event-time bounds for microbatch; run in slices for cost. |
| 78 | What is microbatch? | An incremental strategy that processes independent time batches using `event_time`, `begin`, and `batch_size`. |
| 79 | Databricks microbatch implementation? | Uses `replace_where`; batches can run concurrently and be retried. |
| 80 | How do you test idempotency? | Run twice with no changes; counts/keys should not change; compare to full refresh. |
| 81 | Why can incremental drift? | Logic changes without a full refresh, late data outside the window, schema changes, or failed partial runs. |
| 82 | Incremental vs MV? | Incremental is dbt-managed DML; MV is warehouse-managed refresh. Choose based on SQL support, freshness, and control. |

## 19.7 Databricks

| # | Question | Answer |
|---|---|---|
| 83 | Three-level namespace? | `catalog.schema.table` in Unity Catalog. |
| 84 | SQL warehouse vs cluster? | Warehouse is SQL compute (default `http_path`); clusters are general Spark compute (some Python model modes). |
| 85 | Databricks default table format? | Delta Lake. |
| 86 | Partition vs liquid clustering? | Partitioning uses directories for low-cardinality filters; liquid clustering adapts file layout for broader access patterns. |
| 87 | Can you combine partition and liquid clustering? | No. |
| 88 | MV requirements? | Unity Catalog and a serverless SQL warehouse; supported SQL/configs. |
| 89 | Streaming table requirements? | Unity Catalog + serverless SQL warehouse/Lakeflow; use `STREAM`/`read_files`. |
| 90 | Changing a streaming table query? | Applies to future rows only; `--full-refresh` to reprocess available data. |
| 91 | Python model materializations? | `table` and `incremental` only. |
| 92 | Python submission methods? | `all_purpose_cluster`, `job_cluster`, `serverless_cluster`, `workflow_job`. |
| 93 | How to select compute per model? | `databricks_compute` config + named `compute` entries in the profile. |
| 94 | How to apply UC grants? | `grants` config in YAML/model, or post-hooks; group-based, least privilege. |
| 95 | Row filters/column masks? | UC functions applied via `row_filter`/`column_mask` configs (supported materializations only). |
| 96 | Why `ConcurrentModificationException`? | Concurrent writes to the same Delta table; serialize or isolate writes. |
| 97 | How to optimize Delta tables? | `OPTIMIZE`, liquid clustering, compaction, predictive optimization, right file sizes. |
| 98 | What is `skip_optimize`? | Per-model opt-out of dbt's post-build `OPTIMIZE`; global `DATABRICKS_SKIP_OPTIMIZE` takes precedence. |

## 19.8 Production, CI/CD, performance

| # | Question | Answer |
|---|---|---|
| 99 | What is slim CI? | Building/testing only modified nodes and descendants using state + deferral. |
| 100 | What does `--defer` do? | Points unselected upstream refs at the state environment instead of rebuilding them. |
| 101 | What is `state:modified`? | A selector comparing the current project to a previous manifest; file/config changes, not data changes. |
| 102 | How do you deploy dbt? | Orchestrator (dbt platform, Databricks Workflows, Airflow) runs `dbt build` with prod credentials; artifacts/alerting. |
| 103 | What do you alert on? | Failed builds, freshness breaches, critical test failures, duration/cost anomalies. |
| 104 | How do you avoid overlapping runs? | Scheduler concurrency limits, job locks, serialized writes, separate targets. |
| 105 | How do you find slow models? | `run_results.json`, query history, bytes scanned, shuffles, joins; sort by duration. |
| 106 | Does more `threads` always help? | No; it can overwhelm the warehouse and increase queuing. Tune to capacity. |
| 107 | How do you cut costs? | Incremental/slim builds, partition pruning, right-size compute, avoid full scans, optimize tests, cluster tables. |
| 108 | How do you roll back? | Revert the code, redeploy the previous commit, or swap schemas/views; snapshots preserve history. |
| 109 | What is dbt State? | A platform capability that skips/clones/reuses nodes based on logic and data freshness; not the same as `state:modified`. |
| 110 | How do you monitor data quality over time? | Elementary/dbt artifacts, test history, row-count anomalies, freshness dashboards. |

## 19.9 Semantic Layer, AI, and v2

| # | Question | Answer |
|---|---|---|
| 111 | What is the Semantic Layer? | A metrics layer that defines metrics/dimensions once and serves consistent SQL to BI/APIs/AI. |
| 112 | What is an entity? | A join key with a type (primary/foreign/unique/natural). |
| 113 | What is a time spine? | A date table used for cumulative/conversion metrics and time-based calculations. |
| 114 | Simple vs ratio metric? | Simple aggregates a column; ratio divides numerator by denominator metrics. |
| 115 | How do you test metrics? | Test underlying keys/grains/joins, unit-test logic, reconcile totals, validate time spine. |
| 116 | Wizard vs Copilot? | Wizard is an agent for multi-step, validated development; Copilot is inline quick actions/chat. |
| 117 | What is MCP? | Model Context Protocol: a standard for exposing dbt metadata/tools to AI agents. |
| 118 | What is an agent skill? | A `SKILL.md` file with reusable instructions for an AI coding agent. |
| 119 | What is dbt v2? | The Rust-based engine (Fusion) installed via `pip install dbt`; faster, stricter, static analysis, LSP. |
| 120 | What is static analysis? | Parsing/validating SQL semantics without executing; strict mode enables column lineage/type checks. |
| 121 | What is `--use-v2-parser`? | A dbt 1.12 opt-in flag to test v2 parser compatibility. |
| 122 | What breaks in v2? | Deprecated configs/flags, unknown YAML keys, missing vars/macros, duplicate docs, invalid anchors. |
| 123 | When stay on v1? | Incompatible packages/adapters or unvalidated migration; v1 remains supported. |

## 19.10 Scenario and debugging questions

| # | Question | Answer |
|---|---|---|
| 124 | A dashboard shows double revenue. How do you debug? | Check grain/fan-out, duplicate keys, join cardinality, filters, and whether the dashboard sums an already-aggregated table. |
| 125 | A test passes in dev but fails in prod. Why? | Different data volume, late data, permissions, schema drift, environment-specific logic, or tests filtered in dev. |
| 126 | A model takes 40 minutes. What do you check? | Bytes scanned, joins/shuffles, materialization, partitioning, warehouse size, exploded rows, and unnecessary columns. |
| 127 | A source added a column and the pipeline broke. Why? | `select *`/contract mismatch/`on_schema_change: fail`; make columns explicit and choose schema policy. |
| 128 | A snapshot has duplicate current rows. Why? | Non-unique `unique_key`, duplicate source rows, or concurrent snapshot runs; deduplicate and test. |
| 129 | Incremental row counts dropped after a rerun. Why? | The filter selected a narrower window; `merge` deleted/replaced rows, or a full refresh rebuilt from partial data. |
| 130 | CI is slow and expensive. How do you fix it? | Slim CI, state/deferral, smaller warehouse, selective tests, `--empty` for schema checks, caching deps. |
| 131 | An AI agent proposes a 20-file refactor. What do you do? | Ask for a plan and scope, split into small changes, review diffs, run targeted builds/tests, and never auto-merge. |
| 132 | Two developers built into the same schema. What went wrong? | Shared target schema; use per-developer schemas or isolated catalogs and `generate_schema_name`. |
| 133 | A production job succeeds but data is stale. Why? | Source freshness not checked, incremental filter missed late data, upstream job failed silently, or the MV/stream didn't refresh. |
| 134 | You must change a public model's column type. How? | Version the model or add a new column, contract it, communicate, deprecate the old version, and migrate consumers. |

## 19.11 Ten coding tasks

**Task 1 - Deduplicate latest record.**

```sql
select *
from (
    select *,
           row_number() over (
               partition by order_id
               order by updated_at desc
           ) as rn
    from {{ ref('stg_orders') }}
)
where rn = 1
```

**Task 2 - Incremental merge with a 7-day lookback.**

```sql
{{ config(materialized='incremental', unique_key='order_id', incremental_strategy='merge') }}

select *
from {{ ref('stg_orders') }}

{% if is_incremental() %}
where order_date >= (
    select dateadd(day, -7, coalesce(max(order_date), '1900-01-01')) from {{ this }}
)
{% endif %}
```

**Task 3 - Snapshot with check strategy.**

```sql
{% snapshot customers_snapshot %}
{{ config(
    target_schema='silver',
    unique_key='customer_id',
    strategy='check',
    check_cols=['customer_name', 'market_segment']
) }}
select customer_id, customer_name, market_segment
from {{ ref('stg_customers') }}
{% endsnapshot %}
```

**Task 4 - Generic test for a positive amount.**

```jinja
{% test positive_amount(model, column_name) %}
select * from {{ model }} where {{ column_name }} < 0
{% endtest %}
```

**Task 5 - Surrogate key macro.**

```jinja
{% macro surrogate_key(fields) %}
    md5(concat_ws('|',
        {%- for f in fields -%}
            coalesce(cast({{ f }} as string), '')
            {%- if not loop.last %}, {% endif -%}
        {%- endfor -%}
    ))
{% endmacro %}
```

**Task 6 - Fill missing dates.**

```sql
with spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="to_date('2024-01-01')",
        end_date="to_date('2025-01-01')"
    ) }}
),

revenue as (
    select order_date, sum(order_total) as revenue
    from {{ ref('fct_orders') }}
    group by 1
)

select
    s.date_day,
    coalesce(r.revenue, 0) as revenue
from spine s
left join revenue r on s.date_day = r.order_date
```

**Task 7 - Pivot payment methods.**

```sql
select
    order_date,
    {% for method in ['Credit Card', 'Bank Transfer', 'Wallet', 'Cash'] %}
    sum(case when payment_method_name = '{{ method }}' then order_total else 0 end)
        as {{ method | lower | replace(' ', '_') }}_revenue
        {%- if not loop.last %},{% endif %}
    {% endfor %}
from {{ ref('fct_orders') }}
group by 1
```

**Task 8 - Selection commands.**

```powershell
dbt build -s +fct_orders                  # ancestors + fact
dbt test -s tag:finance                   # finance tests
dbt build -s state:modified+ --defer --state ./state
dbt list -s +exposure:revenue_dashboard
```

**Task 9 - CI job (minimal).**

```yaml
name: dbt-ci
on: [pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: {python-version: "3.12"}
      - run: pip install -r requirements.txt
      - run: dbt deps
      - run: dbt build --select state:modified+ --defer --state state
        env:
          DATABRICKS_TOKEN: ${{ secrets.DATABRICKS_TOKEN }}
```

**Task 10 - Debug fan-out.**

```sql
-- Find keys with more than one row after a join
select order_id, count(*) as c
from {{ ref('fct_orders') }}
group by 1
having c > 1;

-- Inspect the join cardinality before aggregating
select count(*) as rows, count(distinct o.order_id) as orders
from orders o
join lineitems l on o.order_id = l.order_id;
```

# 20. Cheat Sheets, Glossary, Resources, and a 30-Day Plan

## 20.1 Command cheat sheet

| Command | What it does |
|---|---|
| `dbt init` | Create a project/profile |
| `dbt debug` | Validate connection/config |
| `dbt deps` | Install packages |
| `dbt parse` | Parse and write manifest |
| `dbt compile` | Render SQL only |
| `dbt run` | Build models |
| `dbt test` | Run tests |
| `dbt build` | Seeds, models, snapshots, tests in DAG order |
| `dbt seed` | Load CSVs |
| `dbt snapshot` | Run snapshots |
| `dbt source freshness` | Check source timestamps |
| `dbt docs generate` | Build docs/catalog artifacts |
| `dbt docs serve` | Serve docs locally |
| `dbt show -s model` | Preview results |
| `dbt ls -s ...` | List selected nodes |
| `dbt run-operation macro` | Run a macro |
| `dbt clone` | Clone relations from state |
| `dbt retry` | Retry failed nodes |
| `dbt clean` | Remove generated files |
| `dbt --version` | Versions |

## 20.2 Configuration precedence

1. In-file `{{ config(...) }}` (highest).
2. Properties YAML (`models: - name: ... config:`).
3. `dbt_project.yml` folder/project config.
4. Adapter defaults (lowest).

CLI flags override some configs at runtime (for example `--full-refresh`).

## 20.3 Materialization cheat sheet

| Materialization | Persists? | Rebuild behavior | Use |
|---|---|---|---|
| view | Yes (view) | Recreates | Light transforms/staging |
| table | Yes (table) | Full rebuild | Marts, dashboards |
| incremental | Yes (table) | DML on new/changed rows | Large facts/events |
| ephemeral | No | Inlined CTE | Tiny helpers |
| materialized_view | Yes (MV) | Warehouse refresh | Aggregations |
| streaming_table | Yes (ST) | Incremental ingestion | Streams/files |

## 20.4 Incremental cheat sheet

| Strategy | Key config | Databricks |
|---|---|---|
| append | none | all formats |
| merge | `unique_key` | Delta/Hudi |
| delete+insert | `unique_key`, DBR 12.2+ | Delta |
| replace_where | `incremental_predicates` | Delta, DBR 12+ |
| insert_overwrite | `partition_by`/clustering | Delta |
| microbatch | `event_time`, `begin`, `batch_size` | Delta, `replace_where` |

## 20.5 Databricks config cheat sheet

| Config | Example |
|---|---|
| `materialized` | `table`, `view`, `incremental`, `materialized_view`, `streaming_table` |
| `file_format` | `delta` |
| `table_format` | `iceberg` |
| `partition_by` | `['order_date']` |
| `liquid_clustered_by` | `['customer_id']` |
| `auto_liquid_cluster` | `true` |
| `tblproperties` | `{'delta.autoOptimize.optimizeWrite': 'true'}` |
| `databricks_tags` | `{'domain': 'finance'}` |
| `column_mask` | `{function: 'cat.sch.mask_email'}` |
| `row_filter` | `{function: 'cat.sch.region_filter', columns: [region]}` |
| `databricks_compute` | `large` |
| `grants` | `{select: ['analyst_role']}` |
| `schedule` | `{cron: '0 0 * * * ? *'}` or `{every: '2 HOURS'}` |

## 20.6 Jinja context cheat sheet

| Name | Use |
|---|---|
| `ref('model')` | Model relation + dependency |
| `source('src', 'table')` | Source relation |
| `config(...)` | Set config |
| `var('name', default)` | Variable |
| `env_var('NAME')` | Environment variable |
| `target.name/schema/catalog` | Environment |
| `this` | Current relation |
| `is_incremental()` | Incremental guard |
| `model.name` | Model metadata |
| `run_started_at` | Run timestamp |
| `adapter.get_relation(...)` | Metadata lookup |
| `run_query(sql)` | Execute SQL |
| `exceptions.raise_compiler_error` | Fail compilation |
| `log(msg, info=True)` | Log message |

## 20.7 Node selection cheat sheet

| Selector | Meaning |
|---|---|
| `model` | Exact node |
| `folder` | Path/name |
| `tag:x` | Tag |
| `config.materialized:table` | Config |
| `source:src.table` | Source |
| `exposure:x` | Exposure |
| `test_type:unit` | Unit tests |
| `state:modified` | Changed vs state |
| `result:error` | Previously failed |
| `+model`, `model+`, `+model+`, `@model` | Graph operators |
| `--exclude` | Subtract |
| `--selector name` | YAML selector |

## 20.8 Testing cheat sheet

| Test | Catches |
|---|---|
| `unique` | Duplicate PKs/grain issues |
| `not_null` | Missing keys/required values |
| `accepted_values` | Unexpected statuses/categories |
| `relationships` | Orphan FKs/fan-out |
| Singular SQL | Business rules |
| Unit test | Logic regression with fixed inputs |
| Contract | Column name/type drift |
| Freshness | Stale ingestion |

## 20.9 Troubleshooting cheat sheet

| Symptom | First checks |
|---|---|
| Connection/auth | `dbt debug`, env var, token expiry, host/http_path |
| Catalog/schema not found | `SHOW CATALOGS`, grants, profile |
| Model in wrong schema | `generate_schema_name`, `+schema`, target |
| Config ignored | Project name mismatch, missing `+`, precedence |
| Duplicate rows | Grain, joins, incremental key, source duplicates |
| Test fails only in prod | Data volume, late data, filters, permissions |
| Slow run | Full scans, joins, threads, warehouse size, tests |
| MV/ST errors | UC + serverless requirement, unsupported SQL/config |
| Python model fails | Notebook permissions, cluster config, packages, timeout |
| CI fails | Secrets, service principal grants, state manifest path |

## 20.10 Glossary

| Term | Definition |
|---|---|
| **Adapter** | Plugin translating dbt operations to a warehouse. |
| **Analytics engineering** | The discipline of building tested, documented transformation layers. |
| **Artifact** | Generated metadata files in `target/`. |
| **Catalog (dbt)** | The docs/catalog artifact describing warehouse metadata. |
| **Catalog (UC)** | Top-level Unity Catalog container. |
| **Contract** | Enforced column names/types for a model. |
| **CTE** | Common table expression (`with ... as`). |
| **DAG** | Directed acyclic graph of dependencies. |
| **Deferral** | Using state relations for unselected upstream refs. |
| **Dimension** | Descriptive attribute/table for grouping. |
| **Ephemeral** | Model inlined as a CTE, not persisted. |
| **Exposure** | Documented downstream consumer. |
| **Fact** | Event/measurement table. |
| **Freshness** | Timestamp-based recency check. |
| **Generic test** | Reusable YAML test (`unique`, etc.). |
| **Grain** | Meaning of one row. |
| **Group** | Ownership/access boundary. |
| **Incremental** | Materialization processing new/changed data. |
| **Jinja** | Templating language used by dbt. |
| **Macro** | Reusable Jinja function. |
| **Manifest** | `manifest.json`, the full parsed project graph. |
| **Mart** | Consumption-ready model. |
| **Materialization** | Persistence strategy. |
| **Metric** | Business calculation defined in the Semantic Layer. |
| **MetricFlow** | dbt's metric query engine. |
| **Microbatch** | Time-batch incremental strategy. |
| **Model** | SQL file that dbt runs. |
| **Model version** | A versioned interface for a model. |
| **Node** | Any dbt resource (model, test, seed, snapshot, etc.). |
| **Package** | Reusable dbt code installed via `packages.yml`. |
| **Parse** | Reading/rendering the project into a manifest. |
| **Partition** | Physical data subdivision. |
| **Primary key** | Unique identifier for a row. |
| **Profile** | Connection/environment config. |
| **Project** | The dbt codebase and `dbt_project.yml`. |
| **Ref** | Reference to another model. |
| **Run results** | `run_results.json` execution metadata. |
| **Schema** | Namespace for tables (and YAML test file). |
| **Seed** | CSV loaded by dbt. |
| **Semantic layer** | Metrics/dimensions layer for consistent consumption. |
| **Semantic model** | Model annotated with entities/dimensions/metrics. |
| **Singular test** | One-off SQL test in `tests/`. |
| **Snapshot** | SCD2 history table. |
| **Source** | Declared raw table. |
| **Staging** | Cleaning/renaming layer. |
| **State** | Previous manifest used for comparison. |
| **Static analysis** | SQL validation without execution (v2). |
| **Streaming table** | Databricks incremental ingestion table. |
| **Surrogate key** | Generated key. |
| **Target** | Active profile output. |
| **Time spine** | Date table for metric calculations. |
| **Unit test** | Fixed-input test of model logic. |
| **Var** | Project/CLI variable. |
| **View** | Virtual table. |
| **YAML selector** | Named, version-controlled selection. |
| **dbt State** | Platform capability for skip/clone/reuse. |
| **dbt Wizard** | Agentic AI for development. |
| **dbt Copilot** | Inline AI assistance. |
| **MCP** | Model Context Protocol for AI tools. |

## 20.11 Resources

- dbt docs: https://docs.getdbt.com
- dbt Learn courses: https://learn.getdbt.com
- dbt package hub: https://hub.getdbt.com
- dbt Community Slack: https://www.getdbt.com/community/join
- dbt certification: https://www.getdbt.com/dbt-certification
- dbt MCP server: https://github.com/dbt-labs/dbt-mcp
- Databricks dbt docs: https://docs.databricks.com (search "dbt")
- Databricks Unity Catalog: https://docs.databricks.com/data-governance/unity-catalog
- Delta Lake: https://docs.delta.io
- MetricFlow: https://docs.getdbt.com/docs/build/about-metricflow
- dbt GitHub: https://github.com/dbt-labs/dbt-core
- dbt-databricks: https://github.com/databricks/dbt-databricks
- SQL style guide: https://www.sqlstyle.guide
- Use The Index, Luke (SQL performance): https://use-the-index-luke.com

## 20.12 Certification and skill validation

The dbt Analytics Engineering Certification tests:

- dbt fundamentals and project structure.
- Modeling and materializations.
- Jinja/macros/packages.
- Testing, documentation, and sources.
- Incremental models and snapshots.
- Deployment and environments.

To prepare:

1. Finish the capstone.
2. Do the interview questions without notes.
3. Practice explaining trade-offs, not just syntax.
4. Build a small project from an unfamiliar dataset.
5. Review the official docs for anything you use daily.

## 20.13 30-day plan

| Day | Focus | Task |
|---|---|---|
| 1 | Foundations | Read Chapters 1-2; run `dbt debug`; build `stg_orders` |
| 2 | Models/DAG | Chapter 3; build 3 staging models; inspect lineage |
| 3 | Config/schemas | Fix project name; override schema macro; per-dev schema |
| 4 | Layering | Chapter 4; build intermediates and 2 marts |
| 5 | Tests | Add PK/FK tests; run `dbt build`; fix failures |
| 6 | Docs | Descriptions, doc blocks, exposures; `dbt docs serve` |
| 7 | Review | Rebuild from scratch; write a README |
| 8 | Jinja | Chapter 5; write 3 macros; use one in a model |
| 9 | Packages | Chapter 6; install dbt_utils; use surrogate key/star |
| 10 | Testing | Chapter 7; singular test, custom generic test |
| 11 | Unit tests | Add a unit test; break/fix logic |
| 12 | Contracts | Contract `fct_orders`; cause and fix a mismatch |
| 13 | Sources/seeds | Chapter 8; freshness, seed lookup |
| 14 | Snapshots | Build SCD2; update a row; query history |
| 15 | Incremental | Chapter 9; merge, idempotency, backfill |
| 16 | Microbatch | Build a microbatch model; inspect batches |
| 17 | Databricks | Chapter 10; partition/cluster, tags; inspect DDL |
| 18 | MV/ST | Build an MV or streaming table; test refresh |
| 19 | Python | Build a simple Python model; compare compute |
| 20 | Selection/state | Chapter 11; YAML selector, `state:modified+` |
| 21 | CI | Chapter 12; GitHub Actions slim CI |
| 22 | Production | Deploy a scheduled job; add alerts |
| 23 | Performance | Find 5 slow nodes; optimize one; measure |
| 24 | Governance | Groups, grants, mask; run evaluator |
| 25 | Semantic | Chapter 15; semantic model + 3 metrics |
| 26 | AI | Chapter 16; Wizard/MCP lab; agent skill |
| 27 | v2 | Chapter 17; `--use-v2-parser`; static analysis |
| 28 | Capstone | Complete milestones 0-6 |
| 29 | Capstone | Complete milestones 7-12 |
| 30 | Interview | Answer 100+ questions; present your project |

## 20.14 Final checklist

- [ ] I can explain dbt's compilation/execution model.
- [ ] I can design staging/intermediate/marts with clear grains.
- [ ] I can choose and justify a materialization.
- [ ] I can write and debug Jinja macros.
- [ ] I can test keys, relationships, and business rules.
- [ ] I can use contracts and unit tests.
- [ ] I can build sources, seeds, snapshots, and docs.
- [ ] I can design an incremental model with late-data handling.
- [ ] I can use Databricks MVs, streaming tables, and Python models.
- [ ] I can select nodes and build a slim CI pipeline.
- [ ] I can optimize performance and cost.
- [ ] I can implement governance and least privilege.
- [ ] I can define and query Semantic Layer metrics.
- [ ] I can use dbt AI features safely and critically.
- [ ] I can migrate to dbt v2 with a tested plan.
- [ ] I can explain every choice in my capstone.

You are not done when you finish reading. You are done when you can build it, break it, explain it, and teach it. Go build.
