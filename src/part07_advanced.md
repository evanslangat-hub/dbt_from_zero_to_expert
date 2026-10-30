# PART VII - ADVANCED ENGINEERING

# 11. Configuration, Selection, State, and Deployment Patterns

## 11.1 Variables and environment configuration

Variables let you parameterize logic without editing SQL:

```yaml
# dbt_project.yml
vars:
  start_date: "2024-01-01"
  payment_methods: ["card", "bank_transfer"]
```

```sql
where order_date >= '{{ var("start_date") }}'
```

Override at runtime:

```powershell
dbt run --vars '{"start_date": "2024-06-01"}'
```

Precedence:

1. CLI `--vars`.
2. `vars.yml` (dbt 1.12+) or `dbt_project.yml` `vars:`.
3. Macro default `var('name', default)`.

dbt 1.12 introduced `vars.yml` at the project root. Variables defined there are available during project parsing, which is useful for project-level config.

### Environment variables

```yaml
# profiles.yml
token: "{{ env_var('DATABRICKS_TOKEN') }}"
```

```sql
select '{{ env_var("DBT_ENV", "dev") }}' as environment
```

Rules:

- Never put secrets in `dbt_project.yml` or model files.
- Use `env_var` with a default only for non-secrets.
- In CI, inject secrets from the CI secret store.
- In dbt platform, use environment variables and extended attributes.

### Target-based logic

```sql
{% if target.name == 'prod' %}
    where order_date >= dateadd(day, -365, current_date)
{% else %}
    where order_date >= dateadd(day, -30, current_date)
{% endif %}
```

Use sparingly. Hidden environment-specific logic makes production behavior hard to reproduce. Prefer variables with explicit defaults.

## 11.2 Node selection

Selection determines what runs. Master these operators:

| Selector | Meaning |
|---|---|
| `stg_orders` | Exact model |
| `staging` | Folder/name path |
| `tag:finance` | Tag |
| `config.materialized:incremental` | Config |
| `source:bronze.orders_raw` | Source |
| `exposure:revenue_dashboard` | Exposure |
| `test_type:unit` | Unit tests |
| `test_type:data` | Data tests |
| `resource_type:model` | Resource type |
| `package:dbt_utils` | Package |
| `state:modified` | Changed vs state |
| `result:error` | Failed in previous run |
| `selector:my_selector` | YAML selector |

Graph operators:

```powershell
dbt run -s +fct_orders           # ancestors + model
dbt run -s fct_orders+           # model + descendants
dbt run -s +fct_orders+          # both
dbt run -s @fct_orders           # model, ancestors, descendants
dbt run -s 2+fct_orders          # two levels up
```

Set operations:

```powershell
dbt run -s "tag:finance,tag:marts"       # union
dbt run -s "tag:finance,tag:daily"       # intersection (comma within quotes)
dbt run -s "tag:finance --exclude tag:deprecated"
```

Use `dbt list` to preview selection before running.

### YAML selectors

`selectors.yml`:

```yaml
selectors:
  - name: finance_daily
    definition:
      union:
        - method: tag
          value: finance
        - method: tag
          value: daily
    description: "Finance models that run daily"
```

Use:

```powershell
dbt run --selector finance_daily
```

Selectors are version-controlled and easier to review than long CLI strings. dbt 1.12 adds composable selectors that can be referenced within `--select`/`--exclude`.

### Indirect selection

By default, `dbt test -s fct_orders` selects tests directly on `fct_orders`. Tests on upstream models are not selected. Use:

```powershell
dbt test -s fct_orders --indirect-selection=buildable
dbt build -s fct_orders --indirect-selection=eager
```

Options: `eager`, `buildable`, `cautious`, `empty`. Choose based on how much confidence you need versus cost.

## 11.3 State, deferral, and slim CI

State comparison uses a previous `manifest.json`:

```powershell
dbt build -s state:modified+ --state ./prod-manifest
```

Typical slim CI:

1. Download the production manifest artifact.
2. Run only modified models and their descendants.
3. Defer unselected upstream refs to production relations.

```powershell
dbt build `
  --select state:modified+ `
  --defer `
  --state ./prod-manifest
```

`--defer` makes `ref()` for unselected nodes point to the state environment (production), so you do not need to rebuild upstream tables in CI.

`dbt clone` copies relations (metadata-level clone) into a target schema, useful for creating a development environment cheaply:

```powershell
dbt clone --state ./prod-manifest --target dev
```

dbt 1.12 also bundles the dbt State plugin (opt-in via `--manage-state`), which can skip/clone/reuse nodes based on logic and data freshness. dbt State is a paid platform capability; see Chapter 17.

### State caveats

- The state manifest must come from a comparable environment (same dbt version, ideally same project).
- `state:modified` detects file changes, not data changes.
- Macros and packages can affect many nodes; state understands config/macro changes, but test it.
- Use `state:modified.body` or `state:modified.configs` for narrower comparisons when needed.

## 11.4 Commands you must know

| Command | Purpose |
|---|---|
| `dbt init` | Create a project/profile |
| `dbt debug` | Test connection and config |
| `dbt deps` | Install packages |
| `dbt parse` | Parse project, write manifest |
| `dbt compile` | Render SQL without running |
| `dbt run` | Execute models |
| `dbt test` | Execute tests |
| `dbt build` | Run models, tests, seeds, snapshots in DAG order |
| `dbt seed` | Load CSV seeds |
| `dbt snapshot` | Run snapshots |
| `dbt source freshness` | Check source freshness |
| `dbt docs generate` | Build docs/catalog |
| `dbt docs serve` | Serve docs locally |
| `dbt ls` / `dbt list` | List selected nodes |
| `dbt show` | Preview model results |
| `dbt run-operation` | Run a macro |
| `dbt clone` | Clone relations from state |
| `dbt retry` | Retry failed nodes from last run |
| `dbt clean` | Remove `target/` and `dbt_packages/` |
| `dbt --version` | Versions |

Useful flags:

```powershell
--select / -s
--exclude
--full-refresh
--vars
--target
--profiles-dir
--project-dir
--threads
--fail-fast
--warn-error
--no-partial-parse
--defer --state
--event-time-start / --event-time-end
--empty            # build schema with no data (where supported)
--sample           # sample mode (platform)
```

## 11.5 Model versions and deprecation

Model versions let you evolve a model without breaking consumers:

```yaml
models:
  - name: dim_customers
    latest_version: 2
    versions:
      - v: 1
        deprecation_date: "2026-06-01"
      - v: 2
```

Consumers pin:

```sql
select * from {{ ref('dim_customers', version=1) }}
```

`ref('dim_customers')` resolves to the latest version. dbt can create a `dim_customers` pointer view when configured. Use versions for breaking changes; do not use them to avoid naming things well.

## 11.6 Groups, access, and dbt Mesh

Groups define ownership and access boundaries:

```yaml
groups:
  - name: finance
    owner:
      name: Finance Analytics
      email: finance-analytics@example.com
```

```yaml
models:
  - name: fct_orders
    group: finance
    access: protected   # private, protected, public
```

Access levels:

| Access | Who can ref it |
|---|---|
| `private` | Same group only |
| `protected` | Same project (default) |
| `public` | Other projects (mesh) |

Cross-project refs use `dependencies.yml` in the downstream project:

```yaml
projects:
  - name: finance_project
```

```sql
select * from {{ ref('finance_project', 'fct_orders') }}
```

dbt Mesh requires a platform account or compatible discovery setup. It lets teams own domains while sharing governed interfaces.

## 11.7 Hooks

Hooks run SQL before/after models or at run boundaries:

```sql
{{ config(
    pre_hook="delete from {{ this }} where order_date = current_date",
    post_hook="optimize {{ this }} zorder by (customer_id)"
) }}
```

Project-level hooks:

```yaml
on-run-start:
  - "{{ log('Starting run', info=True) }}"
on-run-end:
  - "grant select on all tables in schema {{ target.schema }} to role analyst"
```

Hook cautions:

- Hooks run for every selected model; they can be expensive.
- Use `{% if execute %}` guards in macros.
- Hooks are not a substitute for a proper orchestration step.
- Databricks `OPTIMIZE` in a post-hook can be costly on large tables; prefer scheduled maintenance or `skip_optimize`.

## 11.8 User-defined functions (UDFs)

dbt 1.11+ supports functions as first-class resources. Structure:

```text
functions/
├── mask_email.sql
└── functions.yml
```

`functions/mask_email.sql`:

```sql
create or replace function {{ this }} (email string)
returns string
return concat('***@', split_part(email, '@', 2));
```

`functions/functions.yml`:

```yaml
version: 2

functions:
  - name: mask_email
    config:
      schema: security
    arguments:
      - name: email
        data_type: string
    returns:
      data_type: string
```

dbt 1.12 adds JavaScript UDFs (Snowflake/BigQuery) and Python UDFs on Databricks (Unity Catalog required). Check adapter support before relying on them. UDFs are useful for shared masking/tokenization logic, but they add deployment surface; document and test them.

## 11.9 dbt State and advanced reuse

dbt State (formerly state-aware orchestration) compares model logic and upstream data freshness and can skip, clone, or reuse nodes. Key config:

```yaml
models:
  - name: fct_orders
    config:
      state:
        lag_tolerance: "2 hours"
```

Use `dbt state explain -s fct_orders` (v2) or `dbt-state explain` (v1) to see decisions. Requirements:

- dbt platform account for authentication.
- Opt-in via `--manage-state`, `DBT_ENGINE_MANAGE_STATE=true`, or `manage_state: true`.
- Works with v1, v2, and platform; not a replacement for good incremental design.

Use cases: development without rebuilding upstream, CI cost reduction, scheduled jobs that only rebuild changed data.

## 11.10 Exercises

**Exercise 11.1 - Variables.** Add `start_date` and `end_date` variables. Use them in `fct_orders` to filter dates. Run with different CLI values and confirm the compiled SQL changes.

**Exercise 11.2 - Selection.** Run `dbt list` for: all models tagged finance, all ancestors of `fct_orders`, all descendants of `stg_orders`, and all models excluding staging. Save the commands in a README.

**Exercise 11.3 - State.** Create a production-like manifest by running `dbt parse` on a clean branch, then modify one model and run `dbt build -s state:modified+ --defer --state <dir>`. Which nodes run?

**Exercise 11.4 - Selector.** Create `selectors.yml` with a `daily_finance` selector and run it.

**Exercise 11.5 - Hooks.** Add a post-hook to `rpt_revenue_daily` that logs a row count. Verify it runs.

**Exercise 11.6 - Versions.** Create version 1 and version 2 of `dim_customers`, set `latest_version: 2`, and update one downstream model to pin version 1. Compile both.

**Answers.** 11.1: Use `{{ var('start_date') }}`; `--vars` overrides. 11.2: `dbt list -s tag:finance`; `dbt list -s +fct_orders`; `dbt list -s stg_orders+`; `dbt list -s resource_type:model --exclude staging`. 11.3: Modified model plus descendants; deferred upstream refs point to state. 11.4: Use `--selector daily_finance`. 11.5: Look for the log line in stdout. 11.6: `ref('dim_customers', version=1)` compiles to the v1 relation.

## 11.11 Interview check

- What is the difference between `--select` and `--exclude`?
- How does `state:modified` work, and what are its limitations?
- What does `--defer` do?
- How do you design a slim CI pipeline?
- When would you use model versions?
- What is the difference between `private`, `protected`, and `public` access?
- How do hooks interact with failures?
- What is dbt State, and how is it different from `state:modified`?

# 12. Orchestration and CI/CD

## 12.1 Local, CI, and production

A mature setup has three environments:

| Environment | Purpose | Data | Trigger |
|---|---|---|---|
| Development | Iterate on models | Small/dev schemas | Developer |
| CI | Validate a pull request | Isolated schema, production manifest | PR |
| Production | Serve consumers | Production schemas | Schedule/event |

The same code should run in all three; only configuration, credentials, and data differ.

## 12.2 Git workflow

A simple, effective workflow:

1. Branch from `main`: `feature/add-refunds`.
2. Make changes; run `dbt build -s state:modified+` locally.
3. Open a PR; CI runs `dbt build` in an isolated schema.
4. Review SQL, tests, docs, and lineage impact.
5. Merge; production deploys on a schedule or on merge.
6. Tag releases if you need reproducibility.

Rules:

- Never commit `target/`, `dbt_packages/`, `logs/`, `.env`, or `profiles.yml`.
- Pin dbt and package versions.
- Require tests for new models.
- Review changes to incremental logic and contracts carefully.
- Use `dbt list -s state:modified+` in the PR description.

## 12.3 GitHub Actions: a complete slim CI example

`.github/workflows/dbt-ci.yml`:

```yaml
name: dbt CI

on:
  pull_request:
    branches: [main]

jobs:
  dbt-build:
    runs-on: ubuntu-latest
    env:
      DATABRICKS_HOST: ${{ secrets.DATABRICKS_HOST }}
      DATABRICKS_HTTP_PATH: ${{ secrets.DATABRICKS_HTTP_PATH }}
      DATABRICKS_TOKEN: ${{ secrets.DATABRICKS_TOKEN }}
      DBT_PROFILES_DIR: .
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt

      - name: Write profile
        run: |
          cat > profiles.yml <<EOF
          dbt_dbx:
            target: ci
            outputs:
              ci:
                type: databricks
                catalog: analytics_lab
                schema: ci_pr_${{ github.event.number }}
                host: ${{ secrets.DATABRICKS_HOST }}
                http_path: ${{ secrets.DATABRICKS_HTTP_PATH }}
                token: ${{ secrets.DATABRICKS_TOKEN }}
                threads: 8
          EOF

      - name: Download production manifest
        run: |
          mkdir -p state
          # Replace with your artifact source (dbt platform, S3, GitHub release)
          # curl -o state/manifest.json "${{ secrets.PROD_MANIFEST_URL }}"

      - name: dbt deps
        run: dbt deps

      - name: dbt build (modified +)
        run: |
          dbt build --select state:modified+ --defer --state state --fail-fast

      - name: Upload artifacts
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: dbt-artifacts
          path: target/
```

Notes:

- Use GitHub secrets or an OIDC integration; never hard-code tokens.
- A service principal is better than a personal token.
- `state:modified+` requires a production manifest; without it, build everything (fine for small projects).
- Add a step to clean up the CI schema after the PR (a scheduled cleanup or a TTL policy).
- If you use dbt platform, its CI job can handle deferral and artifacts for you.

## 12.4 Production deployment

Options:

| Orchestrator | How it runs dbt | Best for |
|---|---|---|
| dbt platform jobs | Native dbt scheduling, environments, CI, catalog | Teams wanting managed dbt |
| Databricks Workflows | `dbt` task (task type) or shell task | Teams already on Databricks |
| Airflow | BashOperator, PythonOperator, Cosmos | Complex cross-system DAGs |
| Dagster | dbt assets integration | Asset-oriented orchestration |
| Prefect | Shell/Python tasks | Python-centric orchestration |
| Cron + VM | `dbt build` in a script | Small teams, prototypes (not ideal) |

Production checklist:

- Separate credentials and catalog/schema.
- Run `dbt build`, not just `dbt run`.
- Alert on failure (Slack, email, PagerDuty).
- Capture artifacts (`manifest.json`, `run_results.json`).
- Set retries for transient warehouse errors.
- Prevent overlapping runs on the same tables.
- Run source freshness before or alongside the build.
- Publish docs/catalog after deployment.
- Back up snapshots and critical tables.

## 12.5 Databricks Workflows

Databricks has a native dbt task type. A typical workflow:

1. Sync the Git repo to a Databricks Git folder.
2. Create a job with a `dbt` task pointing to the project directory.
3. Select commands: `dbt deps`, `dbt build`.
4. Choose a SQL warehouse or job cluster.
5. Add notifications and retries.
6. Schedule or trigger on file arrival.

Benefits: no external orchestrator, Unity Catalog integration, job compute. Limitations: less flexible than Airflow for cross-system dependencies.

## 12.6 Airflow example

Using `BashOperator`:

```python
from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

with DAG(
    "dbt_daily",
    start_date=datetime(2024, 1, 1),
    schedule="0 6 * * *",
    catchup=False,
) as dag:
    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command="cd /opt/dbt/dbt_dbx && dbt build --target prod",
        env={
            "DATABRICKS_TOKEN": "{{ conn.databricks.password }}",
        },
    )
```

Better: use Astronomer Cosmos to render each dbt model as an Airflow task with lineage and selective runs.

## 12.7 Scheduling patterns

- **Daily batch**: source freshness -> staging -> marts -> tests -> docs. Most common.
- **Hourly incremental**: only recent partitions; avoid full marts if not needed.
- **Event-driven**: trigger on new files/streams; streaming tables or Auto Loader.
- **Backfill**: isolated runs with event-time bounds; do not collide with scheduled runs.
- **Blue/green**: build into a new schema, validate, swap views/aliases; complex but safe for critical marts.

## 12.8 Monitoring and alerting

Monitor:

- Run status and duration (`run_results.json`).
- Test failures and warnings.
- Source freshness.
- Row counts/volume anomalies.
- Warehouse cost and queuing.
- Downstream BI freshness.

Alert on:

- Failed production build.
- Freshness SLA breach.
- Test failure on a critical model.
- Run duration above threshold.
- Cost anomaly.

Use dbt artifacts, the dbt platform UI, Elementary, or Databricks system tables. Alert fatigue is real: route only actionable failures to humans.

## 12.9 Exercises

**Exercise 12.1 - Local CI simulation.** Create a branch, modify a model, and run `dbt build -s state:modified+ --defer --state <prod_manifest>` against a CI schema.

**Exercise 12.2 - GitHub Actions.** Add the workflow above to a GitHub repo (use a test Databricks workspace/catalog). Open a PR and confirm the job runs.

**Exercise 12.3 - Databricks Workflow.** Create a Databricks job with a dbt task that runs `dbt build`. Trigger it manually and inspect the run.

**Exercise 12.4 - Alerting.** Configure a failure notification (email/Slack) for your job. Force a test failure and confirm the alert.

**Exercise 12.5 - Cost review.** Compare warehouse usage for a full build versus a `state:modified+` build. Record the difference.

**Answers.** 12.1: Only modified nodes and descendants run; upstream refs are deferred. 12.2: Ensure the service principal has warehouse/catalog permissions. 12.3: The dbt task needs the project files in a Git folder or workspace path. 12.4: Use the orchestrator's notification settings. 12.5: Expect a large reduction when few models change.

## 12.10 Interview check

- What is slim CI, and what does it require?
- How do you deploy dbt to production?
- How do you handle secrets in CI?
- What do you alert on?
- How do you prevent two production runs from colliding?
- What is the difference between `dbt run` and `dbt build` in production?
- How do you roll back a bad deployment?

# 13. Performance and Cost Optimization

## 13.1 Where time and money go

A dbt run's cost is dominated by:

1. **Warehouse compute** for model SQL and tests.
2. **Data scanned** (full table scans, missing partition filters).
3. **Shuffles/joins** in Spark.
4. **Small files** and table maintenance.
5. **Idle warehouses** and oversized compute.
6. **Redundant rebuilds** (running everything every time).
7. **Tests** that scan large tables.

Optimize in that order. A prettier DAG does not reduce cost if every model scans a billion rows.

## 13.2 Modeling for performance

- **Filter early**: push date filters into staging or source CTEs.
- **Select only needed columns**: wide tables cost I/O and memory.
- **Avoid views on views on views**: each layer re-executes.
- **Pre-aggregate** where the grain allows.
- **Use incremental** for large append-only facts.
- **Partition/cluster** on common filter columns.
- **Avoid exploding joins**: check cardinality before joining.
- **Use `QUALIFY`/window functions** instead of self-joins where possible.
- **Materialize reusable intermediates** as views, not ephemeral monsters.

## 13.3 Databricks tuning

| Lever | Effect |
|---|---|
| Warehouse size | More compute per query; scale up for heavy transforms |
| Serverless | Automatic scaling; startup latency |
| Photon | Faster SQL/Spark; enable where supported |
| Liquid clustering | Better data skipping for selective filters |
| Partitioning | Prunes data for date filters |
| `OPTIMIZE` | Compacts files; can be scheduled |
| Predictive optimization | Managed maintenance; avoid duplicate manual optimize |
| `ANALYZE TABLE` | Statistics for cost-based optimization |
| Cache | Speeds repeated BI queries |
| File size | Aim for ~100-256 MB files (guideline, not law) |

## 13.4 dbt-level tuning

- `threads`: match warehouse concurrency; more is not always faster.
- `--select` / `state:modified+`: build only what changed.
- `dbt build` interleaves tests; if tests are expensive, run them selectively.
- Disable unnecessary models in dev (`enabled: false` or `--exclude`).
- Use `--empty` for schema-only CI (where supported).
- Avoid `--full-refresh` on huge models unless necessary.
- Limit `store_failures` to failing tests and clean up tables.
- Use `dbt retry` instead of rerunning everything.
- Cache parsing with partial parse (v1) or the Rust parser (v2).

## 13.5 Test cost

Tests are queries too. A `unique` test on a billion-row table scans it. Strategies:

- Add `where` filters for recent partitions.
- Test at the staging layer where data is smaller.
- Use `limit` for exploratory tests, not production correctness.
- Use unit tests for logic instead of scanning production data.
- Run heavy tests less frequently (weekly) and cheap tests every run.
- Use dbt's `warn_if`/`error_if` thresholds to avoid noise.
- In v2, `--batch-tests` can combine compatible tests into fewer queries.

## 13.6 Measuring

Artifacts to inspect:

- `run_results.json`: per-node execution time, status, adapter response.
- `manifest.json`: graph and configs.
- `catalog.json`: table stats.
- Databricks query history: duration, bytes read, warehouse.
- `system.query.history`: cost attribution by user/tag.
- `system.billing.usage`: DBU consumption.

A simple performance review:

1. Find the 10 slowest nodes.
2. For each, check bytes scanned, shuffle, and join cardinality.
3. Decide: filter earlier, change materialization, partition/cluster, or split the model.
4. Measure again; keep a before/after table.

## 13.7 Cost guardrails

- Set warehouse auto-stop (5-10 minutes) for dev.
- Use serverless for sporadic workloads; provisioned for steady high concurrency.
- Separate dev/CI/prod warehouses; restrict prod access.
- Tag queries/models by team/domain for chargeback.
- Alert on long-running queries.
- Review full refreshes and backfills before running.
- Clean up CI schemas automatically.
- Avoid `SELECT *` in tests and models.
- Use dbt State or state selection to avoid redundant builds.

## 13.8 Exercises

**Exercise 13.1 - Slowest nodes.** Run `dbt build` and parse `run_results.json` to list the five slowest nodes. Identify one optimization for each.

**Exercise 13.2 - Partition pruning.** Create a table partitioned by `order_date`. Run a query filtered on `order_date` and compare bytes scanned with an unfiltered query (Databricks query history).

**Exercise 13.3 - Threads.** Run the same build with `--threads 2` and `--threads 8`. Compare duration and warehouse queuing.

**Exercise 13.4 - State selection.** Measure a full build versus `state:modified+`. Record cost/time.

**Exercise 13.5 - Test cost.** Add a `where` filter to a large test and compare runtime.

**Answers.** 13.1: Look for full scans, exploding joins, and unnecessary tables. 13.2: Partition pruning should reduce bytes read dramatically. 13.3: More threads may help or hurt depending on warehouse size and DAG shape. 13.4: Slim builds usually win when few models change. 13.5: Filtered tests scan less data.

## 13.9 Interview check

- How do you find the most expensive model in a dbt run?
- When does increasing `threads` hurt?
- How does partitioning reduce cost?
- What is the difference between `OPTIMIZE` and `ZORDER`?
- How do you keep tests cheap?
- How would you reduce a $10k/month dbt bill?
- What metrics would you put on a dashboard for dbt operations?

# 14. Governance, Security, and dbt Mesh

## 14.1 Governance goals

- **Correctness**: tests, contracts, reviews.
- **Discoverability**: docs, lineage, ownership.
- **Access control**: least privilege, PII protection.
- **Auditability**: who changed what, when.
- **Accountability**: owners and SLAs.
- **Interoperability**: stable interfaces across teams.

dbt supports all of these, but none are automatic. Governance is a set of habits enforced by tooling.

## 14.2 Ownership and groups

Use `groups` and `meta` to record ownership:

```yaml
groups:
  - name: finance
    owner:
      name: Finance Analytics
      email: finance-analytics@example.com

models:
  - name: fct_orders
    group: finance
    meta:
      owner: finance-analytics
      sla: "daily by 07:00 UTC"
      tier: "gold"
```

Expose ownership in docs and catalog. Review it quarterly; stale owners are worse than none.

## 14.3 Access control

### Databricks/Unity Catalog

- Grant `USE CATALOG`/`USE SCHEMA` broadly only where appropriate.
- Grant `SELECT` on gold marts to BI groups.
- Do not grant `MODIFY` on production tables to analysts.
- Use service principals for dbt jobs, not personal accounts.
- Use row filters/column masks for sensitive data.
- Audit grants with `SHOW GRANTS` and system tables.

### dbt access levels

```yaml
models:
  - name: fct_orders
    group: finance
    access: public
```

- `private`: same group only.
- `protected`: same project (default).
- `public`: cross-project/mesh.

Public models are interfaces. Treat them like APIs: contracts, tests, docs, versioning.

## 14.4 Contracts and interfaces

Use contracts for public marts and cross-team dependencies. A contract:

- Locks column names and types.
- Makes breaking changes visible in CI.
- Enables safe downstream refs in mesh.

Not every model needs a contract. Over-contracting staging slows iteration.

## 14.5 PII and sensitive data

Patterns:

1. **Tag** columns/tables (`pii: true`, `data_classification`).
2. **Mask** columns with Unity Catalog mask functions.
3. **Filter** rows with row filters (region, tenant).
4. **Minimize** data: do not select PII into marts unless needed.
5. **Hash/tokenize** identifiers where analytics only needs joins.
6. **Audit** access and queries.
7. **Document** data handling in the model description.

Example mask function:

```sql
CREATE OR REPLACE FUNCTION analytics_lab.security.mask_email(email STRING)
RETURNS STRING
RETURN concat('***@', split_part(email, '@', 2));
```

Apply via dbt config as shown in Chapter 10.

## 14.6 dbt Mesh

dbt Mesh lets domain teams own separate dbt projects and share public models:

- Each project has its own repo, schedule, and owners.
- Cross-project refs use `dependencies.yml`.
- Public models are governed interfaces.
- The platform provides discovery and lineage across projects.

When to use mesh:

- Multiple teams with distinct domains and release cadences.
- A monorepo is becoming a bottleneck.
- You need clear ownership boundaries.

When not to:

- Small team, single domain.
- You cannot invest in contracts, docs, and coordination.
- The overhead exceeds the coordination cost.

## 14.7 Project health checks

Use `dbt_project_evaluator` and custom checks:

- Every model has a description and owner.
- Every source has freshness (where applicable).
- Every fact/dimension has PK tests.
- No duplicate sources or models.
- Naming conventions are followed.
- No models with zero downstream consumers.
- No direct source references in marts.
- Public models have contracts.

Treat failures as a prioritized backlog.

## 14.8 Security of the dbt project itself

- Secrets never in Git; use environment variables/secret managers.
- Restrict who can merge to `main`.
- Pin packages and review upgrades.
- Run `dbt deps` in CI from a lock file.
- Scan for accidental PII in seeds and tests.
- Limit `store_failures` tables; they can contain sensitive rows.
- Protect production credentials; use a service principal with least privilege.
- Log and monitor access to artifacts.

## 14.9 Exercises

**Exercise 14.1 - Ownership.** Add groups and owners to three models. Generate docs and confirm ownership appears (where supported).

**Exercise 14.2 - Contract.** Make `fct_orders` public and add a contract. Break a column type intentionally and confirm CI fails.

**Exercise 14.3 - PII.** Tag an email column, create a mask function, and apply it. Query the table as a non-privileged user and confirm the mask.

**Exercise 14.4 - Row filter.** Create a region filter function and apply it to a table. Verify with a test user.

**Exercise 14.5 - Evaluator.** Install `dbt_project_evaluator` and run it. List the top five project health issues.

**Answers.** 14.1: Ownership appears in docs/catalog metadata. 14.2: The contract failure lists the mismatched type. 14.3: The mask function must be owned/granted correctly. 14.4: Row filters require supported materializations and UC. 14.5: Typical issues: missing descriptions, missing tests, duplicate sources, naming violations.

## 14.10 Interview check

- How do you implement least privilege for a dbt project?
- What is the difference between a contract and a test?
- How do you protect PII in a gold table?
- When would you use dbt Mesh?
- How do you make a model a stable interface for other teams?
- What would you monitor for governance violations?
- How do you handle a breaking change to a public model?
