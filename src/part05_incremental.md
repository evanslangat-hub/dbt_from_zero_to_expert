# PART V - SCALE

# 9. Incremental Models and Microbatch

## 9.1 Why incremental

A full table rebuild is simple but expensive at scale. Incremental models process only new or changed data and apply it to an existing table. The trade-off is complexity: you must define what "new" means, handle late data, and ensure idempotency.

When to use incremental:

- The table is large (millions+ rows) and grows append-only.
- A full rebuild exceeds the job window or costs too much.
- The transformation is expensive relative to the new data volume.

When not to:

- The table is small.
- The logic requires a full recomputation (for example, global ranking).
- The source data is not time-ordered and changes unpredictably (use a snapshot or full rebuild).

## 9.2 How dbt incremental works

On the first run (or `--full-refresh`):

1. dbt creates a table from the model's `SELECT` (often via a temporary relation).
2. Subsequent runs: dbt compiles the model with `is_incremental()` returning true, builds a temporary relation, and applies the configured strategy (merge, append, delete+insert, replace_where, insert_overwrite, microbatch).

`is_incremental()` returns true only if:

- The target relation already exists.
- `--full-refresh` is not set.
- The model is materialized as incremental.

Important: the filter inside `is_incremental()` is your responsibility (except for microbatch). dbt does not automatically know what "new" means.

## 9.3 The canonical pattern

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge',
    on_schema_change='append_new_columns'
) }}

select *
from {{ ref('stg_orders') }}

{% if is_incremental() %}
where order_date >= (
    select coalesce(max(order_date), '1900-01-01') from {{ this }}
)
{% endif %}
```

Add a lookback for late-arriving data:

```sql
{% if is_incremental() %}
where order_date >= (
    select dateadd(day, -3, coalesce(max(order_date), '1900-01-01')) from {{ this }}
)
{% endif %}
```

Then ensure the strategy replaces rows for those dates, not just appends.

## 9.4 Incremental strategies on Databricks

| Strategy | DML | Requires | Use |
|---|---|---|---|
| `append` | `INSERT INTO` | Nothing | Append-only events, no updates |
| `merge` (default) | `MERGE INTO` | Delta/Hudi; `unique_key` recommended | Upserts by key |
| `delete+insert` | Delete matching keys, insert | Delta, `unique_key`, DBR 12.2+ | Full-record replacement |
| `replace_where` | `INSERT ... REPLACE WHERE` | Delta, `incremental_predicates` | Replace partitions/ranges |
| `insert_overwrite` | Replace partitions/clusters | `partition_by` or clustering | Recompute whole partitions |
| `microbatch` | `replace_where` per batch | Delta, `event_time`, `begin`, `batch_size` | Large time-series |

### `append`

```sql
{{ config(materialized='incremental', incremental_strategy='append') }}

select *
from {{ ref('stg_events') }}
{% if is_incremental() %}
where event_ts > (select coalesce(max(event_ts), '1900-01-01') from {{ this }})
{% endif %}
```

Risk: if the filter overlaps, you get duplicates. Use only for truly append-only data or deduplicate downstream.

### `merge`

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge'
) }}
```

dbt generates a `MERGE` with `WHEN MATCHED THEN UPDATE` and `WHEN NOT MATCHED THEN INSERT`. If `unique_key` is omitted, it behaves like append.

Databricks merge options (1.9+):

```sql
{{ config(
    unique_key='id',
    target_alias='t',
    source_alias='s',
    matched_condition='t.updated_at < s.updated_at',
    not_matched_condition='s.id is not null',
    not_matched_by_source_condition='t.updated_at < current_timestamp()',
    not_matched_by_source_action='delete',
    merge_with_schema_evolution=true
) }}
```

Use these for soft deletes, conditional updates, and schema evolution. Review generated SQL in `target/run/`.

### `delete+insert`

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='delete+insert',
    incremental_predicates='order_date >= current_date - interval 30 days'
) }}
```

Deletes rows matching keys in the new batch, then inserts. Simpler than merge when you replace whole records.

### `replace_where`

```sql
{{ config(
    materialized='incremental',
    incremental_strategy='replace_where',
    incremental_predicates='order_date >= current_date - interval 7 days'
) }}
```

Only rows matching the predicate are replaced. Caution: `replace_where` inserts by column order on Databricks; keep column order stable or use `on_schema_change`.

### `insert_overwrite`

```sql
{{ config(
    materialized='incremental',
    incremental_strategy='insert_overwrite',
    partition_by='order_date'
) }}
```

Replaces entire partitions returned by the query. If no `partition_by`, it replaces the whole table. Use `liquid_clustered_by` for clustered tables (dbt-databricks uses `replace on` keys).

## 9.5 `on_schema_change`

| Value | Behavior |
|---|---|
| `ignore` (default) | Ignore new/changed columns; may fail on removed columns |
| `fail` | Error if schema changes |
| `append_new_columns` | Add new columns to the target |
| `sync_all_columns` | Add/remove/reorder to match the model (can be expensive) |

Choose deliberately:

- Additive sources: `append_new_columns`.
- Stable contracts: `fail` (catch changes early).
- Development: `sync_all_columns`, but test on a clone.

## 9.6 Late-arriving data

Late data breaks naive max-date filters. Patterns:

1. **Lookback window**: reprocess the last N days on every run. Simple and robust if N covers lateness.
2. **High-water mark table**: store the max event time processed, plus a buffer.
3. **Merge by key**: even if you select a wide window, `merge` upserts, so duplicates are avoided (but cost increases).
4. **Microbatch with `lookback`**: dbt reprocesses N batches automatically.

Choose based on source SLAs and cost. Document the lateness assumption.

## 9.7 Idempotency and reruns

An incremental model must be safe to run twice. Tests:

- Run twice without new data: row counts should not change.
- Run with an overlapping window: no duplicate keys.
- Run `--full-refresh`: results should match the incremental table.

If a run fails midway, dbt's transaction semantics depend on the adapter. Databricks Delta supports atomic operations; still, design models so partial batches can be rerun.

## 9.8 Backfills

```powershell
dbt run -s fct_orders --full-refresh
```

For microbatch, use event-time bounds:

```powershell
dbt run -s fct_orders --event-time-start "2024-01-01" --event-time-end "2024-02-01"
```

For large backfills:

- Run in date slices to control cost.
- Use a separate warehouse/compute if possible.
- Notify downstream consumers.
- Compare results with `audit_helper`.

## 9.9 Microbatch deep dive

Microbatch is designed for large time-series data. Instead of writing `is_incremental()` logic, you declare:

```sql
{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='order_date',
    begin='2020-01-01',
    batch_size='day',
    lookback=2,
    full_refresh=false
) }}

select *
from {{ ref('stg_orders') }}
```

dbt splits the work into one query per day (or hour/month/year), filters upstream models that declare `event_time`, and replaces each batch atomically. On Databricks it uses `replace_where`.

Required configs: `event_time`, `begin`, `batch_size`.

Optional: `lookback` (default 1), `concurrent_batches`.

To let dbt auto-filter an upstream model, give it an `event_time`:

```yaml
models:
  - name: stg_orders
    config:
      event_time: order_date
```

To opt out for a specific ref: `{{ ref('upstream').render() }}`.

Backfill and retry:

```powershell
dbt run -s fct_orders --event-time-start "2024-01-01" --event-time-end "2024-02-01"
dbt retry
```

Microbatch benefits:

- No manual `is_incremental()` filter.
- Idempotent batches.
- Parallel batch execution when safe.
- Partial retry of failed batches.

Limitations:

- Requires a reliable event time.
- Upstream models need `event_time` for filtering; otherwise full scans.
- Not ideal for non-time-series or heavily updated data.

## 9.10 Incremental vs snapshot vs materialized view vs streaming table

| Need | Best choice |
|---|---|
| Upsert changed records by key | Incremental `merge` |
| Preserve full history of changes | Snapshot |
| Append-only events | Incremental `append` or streaming table |
| Warehouse-managed refresh of an aggregation | Materialized view |
| Continuous ingestion from files/streams | Streaming table |
| Recompute partitions | `insert_overwrite` or microbatch |
| Small table, simple logic | Table (full rebuild) |

## 9.11 Performance and cost of incremental models

- Filter early; avoid scanning the full source.
- Partition/cluster on the filter column.
- Use `merge` only when needed; append is cheaper.
- Beware of small files; run `OPTIMIZE` or use liquid clustering.
- Test with `--full-refresh` periodically to catch drift.
- Monitor merge cardinality; exploding joins create duplicate keys and slow merges.
- Use `dbt build` so tests run before downstream models consume bad data.

## 9.12 Exercises

**Exercise 9.1 - Merge.** Convert `fct_orders` to incremental with `unique_key='order_id'` and `merge`. Run twice. Insert a changed order in the source and verify the target updates.

**Exercise 9.2 - Append.** Create `fct_events` with `append` and an event-time filter. Insert an event with an older timestamp and observe that it is not picked up. Add a lookback and rerun.

**Exercise 9.3 - Delete+insert.** Create a model with `delete+insert` on `order_id`. Compare the generated SQL with `merge` in `target/run/`.

**Exercise 9.4 - Microbatch.** Create a microbatch model over `stg_orders` with `event_time='order_date'`, `begin='1990-01-01'`, `batch_size='year'`. Run it and inspect the number of batches in the logs.

**Exercise 9.5 - Late data.** Simulate a late order (order_date 3 days before max) and prove your model handles it. What lookback do you need?

**Exercise 9.6 - Idempotency.** Run your incremental model twice without source changes. Compare row counts and key counts. Then `--full-refresh` and compare.

**Answers.** 9.1: The merge updates the matched row. 9.2: Without lookback, the older event is outside the filter; add `-3 days`. 9.3: `delete+insert` runs a `DELETE` + `INSERT` (or `REPLACE ON` on newer DBR); `merge` runs `MERGE INTO`. 9.4: One batch per year from `begin` to today. 9.5: A lookback >= the lateness window (e.g., 7 days). 9.6: Counts and distinct keys should be stable; full refresh should match.

## 9.13 Interview check

- How does `is_incremental()` work, and when is it false?
- What is the difference between `merge`, `delete+insert`, and `replace_where`?
- How do you handle late-arriving data?
- Why can `append` create duplicates?
- What does `on_schema_change` do?
- When would you choose microbatch over a manual filter?
- How do you backfill an incremental model safely?
- How do you test idempotency?
