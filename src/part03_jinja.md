# PART III - REUSABILITY

# 5. Jinja and Macros

## 5.1 Why Jinja

Jinja is a templating language that turns SQL into a program. In dbt it enables:

- Dynamic relation names via `ref()` and `source()`.
- Conditional SQL such as `is_incremental()`.
- Loops over columns, dates, or lists.
- Reusable macros for logic that must be identical everywhere.
- Environment-specific behavior via `target.name` and variables.

The goal is not clever code. The goal is **one definition of a business rule**, with SQL that remains readable and reviewable.

## 5.2 Jinja basics

```jinja
{% set tax_rate = 0.2 %}

select
    order_id,
    order_total,
    order_total * {{ tax_rate }} as order_total_with_tax
from {{ ref('stg_orders') }}
```

Output:

```sql
select
    order_id,
    order_total,
    order_total * 0.2 as order_total_with_tax
from analytics_lab.silver.stg_orders
```

Delimiters:

| Syntax | Purpose |
|---|---|
| `{{ ... }}` | Output an expression |
| `{% ... %}` | Statement (if, for, set, macro) |
| `{# ... #}` | Comment |
| `{%- ... -%}` | Whitespace control |

Whitespace control matters when generating SQL. `{%-` strips whitespace before the tag; `-%}` strips after it. A stray newline is harmless, but a stray comma is not.

## 5.3 Variables, conditionals, and loops

```jinja
{% set payment_methods = ['card', 'bank_transfer', 'wallet'] %}

select
    order_id,
    {% for method in payment_methods %}
    sum(case when payment_method = '{{ method }}' then order_total else 0 end)
        as {{ method }}_revenue
        {%- if not loop.last %},{% endif %}
    {% endfor %}
from {{ ref('fct_orders') }}
group by 1
```

Loop variables: `loop.index`, `loop.index0`, `loop.first`, `loop.last`, `loop.length`.

Conditionals:

```jinja
{% if target.name == 'prod' %}
    where order_date >= dateadd(day, -365, current_date)
{% else %}
    where order_date >= dateadd(day, -30, current_date)
{% endif %}
```

Use environment conditionals sparingly. Hidden production-only logic makes bugs hard to reproduce. Prefer variables with explicit defaults.

## 5.4 Filters and tests

Filters transform values:

```jinja
{{ 'orders' | upper }}                 -- ORDERS
{{ ['a', 'b'] | join(', ') }}          -- a, b
{{ 3.14159 | round(2) }}               -- 3.14
{{ none | default('unknown') }}        -- unknown
{{ model.name | replace('stg_', '') }} -- orders
```

dbt adds filters such as `as_text`, `as_number`, `as_bool`, `as_native`, `fromjson`, `tojson`, `zip`, and `split`.

Tests use `is`:

```jinja
{% if loop.first %}...{% endif %}
{% if value is none %}...{% endif %}
{% if value is defined %}...{% endif %}
```

## 5.5 The dbt Jinja context

Available in models and macros (not all in YAML):

| Name | What it gives you |
|---|---|
| `ref`, `source` | Relations and dependencies |
| `config` | Set configuration |
| `var` | Project/CLI variables |
| `env_var` | Environment variables |
| `target` | Current target (name, schema, catalog, type) |
| `this` | Current relation |
| `is_incremental()` | Whether to run incremental logic |
| `model` | Current model metadata (`name`, `path`, `config`) |
| `run_started_at` | Run timestamp |
| `invocation_id` | Run identifier |
| `execute` | True during execution, false during parsing |
| `flags` | Global flags |
| `graph` | Nodes and dependencies |
| `adapter` | Adapter methods (`get_relation`, `dispatch`, etc.) |
| `exceptions` | `raise_compiler_error`, `warn` |
| `log` | `log(msg, info=True)` |
| `modules` | Python modules (`re`, `itertools`, `datetime`) |

A useful pattern is to guard introspection during parsing:

```jinja
{% if execute %}
    {% set relation = adapter.get_relation(
        database=target.catalog,
        schema='bronze',
        identifier='orders_raw'
    ) %}
    {{ log('Relation: ' ~ relation, info=True) }}
{% endif %}
```

If you call `adapter.get_relation` during parsing without the guard, dbt may query the warehouse before it is ready, or return `None` unexpectedly.

## 5.6 Macros

A macro is a reusable Jinja function. Define it in `macros/`:

```jinja
{% macro cents_to_dollars(column_name, scale=2) -%}
    ({{ column_name }} / 100.0)::numeric(18, {{ scale }})
{%- endmacro %}
```

Use it:

```sql
select
    order_id,
    {{ cents_to_dollars('order_total_cents') }} as order_total
from {{ ref('stg_orders') }}
```

Macros can return SQL, values, or both. Use whitespace control to keep generated SQL tidy.

### Arguments and defaults

```jinja
{% macro revenue(column_name, status='F', include_tax=false) -%}
    sum(
        case
            when order_status = '{{ status }}'
            then {{ column_name }}
            else 0
        end
    )
{%- endmacro %}
```

### Calling macros from YAML

```yaml
models:
  - name: fct_orders
    config:
      meta:
        owner: "{{ var('team_owner', 'analytics') }}"
```

In dbt v1, YAML Jinja is restricted to built-ins; project macros are not available in YAML. In dbt v2, project macros are available. This is a meaningful migration difference.

### `return()`

`return()` stops macro execution and returns a value:

```jinja
{% macro safe_divide(numerator, denominator) -%}
    {%- if denominator == 0 -%}
        {{ return('null') }}
    {%- endif -%}
    ({{ numerator }} * 1.0 / {{ denominator }})
{%- endmacro %}
```

## 5.7 Practical macro library

### Surrogate key

```jinja
{% macro surrogate_key(fields) -%}
    md5(concat_ws('|',
        {%- for field in fields -%}
            coalesce(cast({{ field }} as string), '')
            {%- if not loop.last %}, {% endif -%}
        {%- endfor -%}
    ))
{%- endmacro %}
```

Usage:

```sql
{{ surrogate_key(['order_id', 'line_number']) }} as order_line_key
```

Prefer `dbt_utils.generate_surrogate_key`; it handles nulls and types consistently and is tested by the community.

### Grant select after build

```jinja
{% macro grant_select(schema, role) -%}
    {% set sql %}
        grant select on schema {{ schema }} to role {{ role }};
    {% endset %}
    {% do run_query(sql) %}
    {{ log('Granted select on ' ~ schema ~ ' to ' ~ role, info=True) }}
{%- endmacro %}
```

Use it in a post-hook. Chapter 11 covers grants properly.

### Date spine

```jinja
{% macro date_spine(start_date, end_date) -%}
    select explode(sequence(
        to_date('{{ start_date }}'),
        to_date('{{ end_date }}'),
        interval 1 day
    )) as date_day
{%- endmacro %}
```

Databricks supports `sequence` and `explode`. `dbt_utils.date_spine` is more portable.

### Union relations

```jinja
{% macro union_relations(relations) -%}
    {% for relation in relations %}
        select '{{ relation.name }}' as source_model, *
        from {{ relation }}
        {% if not loop.last %}union all{% endif %}
    {% endfor %}
{%- endmacro %}
```

In practice, use `dbt_utils.union_relations` so schemas are aligned by column name, not position.

## 5.8 `run_query` and statement blocks

`run_query` executes SQL during compilation/execution and returns a table:

```jinja
{% macro get_max_order_date() -%}
    {% set query %}
        select max(order_date) as max_date from {{ ref('fct_orders') }}
    {% endset %}
    {% set result = run_query(query) %}
    {% if execute %}
        {{ return(result.columns[0].values()[0]) }}
    {% endif %}
    {{ return(none) }}
{%- endmacro %}
```

Rules:

- Only run queries when `execute` is true.
- `run_query` inside a model is usually a smell; prefer a variable, a model, or an incremental filter.
- Use it for metadata, grants, dynamic SQL, and operations.

`{% call statement(...) %}` executes side-effecting SQL:

```jinja
{% call statement('grant', fetch_result=false) %}
    grant select on {{ this }} to role analyst;
{% endcall %}
```

## 5.9 `adapter.dispatch`: cross-platform macros

If your project runs on multiple adapters, dispatch lets each adapter provide its own implementation:

```jinja
{% macro date_add(datepart, interval, date) -%}
    {{ return(adapter.dispatch('date_add', 'my_project')(datepart, interval, date)) }}
{%- endmacro %}

{% macro default__date_add(datepart, interval, date) -%}
    dateadd({{ datepart }}, {{ interval }}, {{ date }})
{%- endmacro %}

{% macro databricks__date_add(datepart, interval, date) -%}
    date_add({{ date }}, {{ interval }})
{%- endmacro %}
```

dbt's own `dbt.dateadd` macro already dispatches across adapters; use it before writing your own.

## 5.10 Debugging Jinja

| Tool | Use |
|---|---|
| `dbt compile -s model` | Render SQL; inspect `target/compiled/...` |
| `{{ log('msg', info=True) }}` | Print during parse/compile |
| `dbt --debug run` | Verbose logs |
| `{{ this }}` | Check the resolved relation |
| `dbt run-operation macro_name --args '{...}'` | Run a macro without a model |
| `dbt parse` | Catch syntax/parse errors early |
| VS Code dbt extension | Inline Jinja diagnostics and compiled SQL preview |

Common errors:

- Forgetting `{% endif %}` or `{% endfor %}`.
- Calling `ref()` in a macro that runs at parse time when `execute` is false.
- Quoting: `'{{ var("x") }}'` versus `{{ var("x") }}`.
- A trailing comma after a loop.
- Case sensitivity in `target.name` comparisons.
- Using `this` in a macro called outside a model context.

## 5.11 Exercises

**Exercise 5.1 - Cents.** Write `cents_to_dollars(column, scale=2)` and use it in `stg_payments` to convert an integer cents column to decimal dollars.

**Exercise 5.2 - Pivot.** Write a macro that pivots payment methods into columns. Use a list variable and a loop. Compile the model and inspect the SQL.

**Exercise 5.3 - Safe divide.** Write `safe_divide(numerator, denominator)` that returns `null` when the denominator is zero. Test it with a zero denominator.

**Exercise 5.4 - Date spine.** Generate one row per day from 2024-01-01 to 2024-12-31 using a macro or `dbt_utils.date_spine`. Use it to fill missing dates in revenue.

**Exercise 5.5 - Dispatch.** Write a `date_add` macro that dispatches to `databricks__date_add` and `default__date_add`. Call it from a model.

**Exercise 5.6 - Debug.** A macro produces a trailing comma before `from`. Diagnose using whitespace control and `loop.last`.

**Answers.** 5.1: `({{ column_name }} / 100.0)::decimal(18, {{ scale }})`. 5.2: Build `case` expressions in a loop and join with commas. 5.3: Use `nullif(denominator, 0)` or an `if`. 5.4: `dbt_utils.date_spine(datepart='day', start_date='2024-01-01', end_date='2025-01-01')`. 5.5: `adapter.dispatch('date_add', 'dbt_dbx')`. 5.6: Strip whitespace before the comma and emit it only when `not loop.last`.

## 5.12 Interview check

- When should logic be a macro versus a model?
- What is the difference between `run_query` and a normal `select`?
- Why is `execute` important?
- How do you make a macro portable across adapters?
- What are the risks of overusing Jinja?
- How do you test a macro?
- How do you document a macro?

# 6. Packages and the dbt Ecosystem

## 6.1 Why packages

Packages let you reuse tested macros, tests, models, and semantic definitions maintained by the community or your organization. They reduce boilerplate and encode best practices. They also add supply-chain risk, so pin versions and review what you install.

## 6.2 Installing packages

`packages.yml`:

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.3.0", "<2.0.0"]

  - package: calogica/dbt_expectations
    version: [">=0.10.0", "<0.11.0"]

  - package: dbt-labs/codegen
    version: [">=0.13.0", "<0.14.0"]

  - package: dbt-labs/audit_helper
    version: [">=0.12.0", "<0.13.0"]

  - package: dbt-labs/dbt_project_evaluator
    version: [">=1.0.0", "<2.0.0"]
```

Then:

```powershell
dbt deps
```

Packages install into `dbt_packages/` (gitignored). `dbt clean` removes them.

### Other package sources

```yaml
packages:
  - local: ../shared_dbt_models
  - git: https://github.com/your-org/your-package.git
    revision: v1.2.0
  - package: your-org/your-package
    version: 1.2.0
```

For private Git, use SSH keys or a token in CI. dbt 1.12 supports private packages with native SSH configuration.

### Version pinning

Always pin:

- Exact (`1.3.0`) for maximum reproducibility.
- A narrow range (`>=1.3.0, <2.0.0`) for patches but not breaking changes.

Commit `package-lock.yml` (generated by `dbt deps`) so CI installs the same versions.

## 6.3 `dbt_utils`: the essential toolbox

| Macro | What it does | Example |
|---|---|---|
| `generate_surrogate_key` | Hash a list of columns into a key | `{{ dbt_utils.generate_surrogate_key(['order_id','line_number']) }}` |
| `star` | Select all columns except some | `{{ dbt_utils.star(from=ref('stg_orders'), except=['comment']) }}` |
| `union_relations` | Union relations by column name | `{{ dbt_utils.union_relations(relations=[ref('a'), ref('b')]) }}` |
| `date_spine` | Generate a date/period spine | `{{ dbt_utils.date_spine('day', '2024-01-01', '2025-01-01') }}` |
| `pivot` | Pivot values into columns | `{{ dbt_utils.pivot('payment_method', ['card','bank']) }}` |
| `unpivot` | Unpivot columns into rows | `{{ dbt_utils.unpivot(ref('t'), cast_to='string', exclude=['id']) }}` |
| `deduplicate` | Deduplicate by key | `{{ dbt_utils.deduplicate(relation=ref('x'), partition_by='id', order_by='updated_at desc') }}` |

Example: explicit columns plus a surrogate key.

```sql
select
    {{ dbt_utils.generate_surrogate_key(['order_id', 'line_number']) }} as order_line_key,
    {{ dbt_utils.star(from=ref('stg_lineitems'), except=['comment']) }}
from {{ ref('stg_lineitems') }}
```

Caveat: `star` hides schema changes. Use it in staging, not in marts with contracts.

## 6.4 `dbt_expectations`: richer tests

```yaml
models:
  - name: fct_orders
    columns:
      - name: order_total
        data_tests:
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 1000000
          - dbt_expectations.expect_column_values_to_not_be_null
      - name: order_status
        data_tests:
          - dbt_expectations.expect_column_distinct_count_to_be_between:
              min_value: 1
              max_value: 10
```

Useful tests: value ranges, row counts, column-pair consistency, regex matches, freshness, quantiles, null proportions, uniqueness within a group.

## 6.5 `codegen`: generate YAML and models

Codegen macros generate boilerplate:

- `generate_model_yaml` from a table's columns.
- `generate_source` from a schema.
- `generate_staging_model`.

```powershell
dbt run-operation generate_model_yaml --args '{"model_names": ["stg_orders"]}'
```

Paste the output into YAML, then review and improve descriptions. Generated tests are a starting point, not a substitute for thought.

## 6.6 `audit_helper`: validate a refactor

When migrating logic, compare two relations:

```sql
{{ audit_helper.compare_relations(
    a_relation=ref('fct_orders_old'),
    b_relation=ref('fct_orders_new'),
    primary_key='order_id'
) }}
```

It returns counts of rows in A only, B only, and differing values. Use it before swapping a model in production.

## 6.7 `dbt_project_evaluator`: project governance

This package tests your project's structure: model naming, test coverage, source usage, folder layering, duplicate sources, and more. It is a health check for the dbt project itself, not the data.

```powershell
dbt build --select package:dbt_project_evaluator
```

Review failures as a backlog, not a blocker for every PR.

## 6.8 Elementary: observability

Elementary is an observability package/platform that collects dbt artifacts, test results, run times, and data quality metrics into dashboards. It can alert on failures and anomalies.

Use it when you need:

- Historical test results.
- Anomaly detection.
- Run-time trends.
- Alert routing to Slack/email.

## 6.9 Other notable packages

| Package | Use |
|---|---|
| `dbt-labs/dbt_utils` | General macros |
| `calogica/dbt_expectations` | Rich data tests |
| `dbt-labs/codegen` | Generate YAML/SQL |
| `dbt-labs/audit_helper` | Compare relations |
| `dbt-labs/dbt_project_evaluator` | Project structure tests |
| `elementary-data/elementary` | Observability |
| `dbt-labs/dbt_artifacts` | Load artifacts into tables for analysis |
| Fivetran source/transform packages | Prebuilt staging models for SaaS sources |

## 6.10 Package governance

1. Pin versions and commit the lock file.
2. Review the package's license and maintenance activity.
3. Avoid packages that run introspective queries on every parse.
4. Do not let packages dictate your folder structure or naming.
5. Test upgrades in a branch; compare run times and test results.
6. Keep packages in `packages.yml`, never vendored into your repo.
7. For a monorepo, consider an internal package for shared macros and models.

## 6.11 Exercises

**Exercise 6.1 - Install.** Create `packages.yml` with `dbt_utils` pinned to a range, run `dbt deps`, and use `generate_surrogate_key` in a model.

**Exercise 6.2 - Star.** Use `dbt_utils.star` to select all columns except `comment` from `stg_orders`. Compile and inspect the SQL.

**Exercise 6.3 - Tests.** Add two `dbt_expectations` tests to `fct_orders`: `order_total` between 0 and 1,000,000, and `order_status` distinct count between 1 and 10. Run them.

**Exercise 6.4 - Codegen.** Generate YAML for `dim_customers`, paste it into a file, and improve the descriptions. Add at least one test that codegen did not generate.

**Exercise 6.5 - Audit.** Create a copy of `fct_orders` with a deliberate bug, then use `audit_helper.compare_relations` to quantify the difference.

**Answers.** 6.2: The compiled SQL lists every column except `comment`. 6.3: Use the package-qualified test names. 6.4: Codegen produces generic descriptions; replace them. 6.5: The audit output shows rows only in A, only in B, and differing rows.

## 6.12 Interview check

- How do you install and pin a dbt package?
- What are the risks of third-party packages?
- When would you write a macro instead of using a package?
- How does `dbt_utils.star` interact with contracts?
- How do you audit a refactor?
- What does `dbt_project_evaluator` test?
