# PART VIII - INTELLIGENCE

# 15. The dbt Semantic Layer and Metrics

## 15.1 Why a semantic layer

Without a semantic layer, every dashboard, notebook, and analyst defines "revenue" slightly differently. The result is the classic meeting where three numbers claim to be revenue.

A semantic layer defines metrics **once**, in code, and serves them consistently to BI tools, APIs, and AI agents. dbt's implementation is built on **MetricFlow**, which translates metric requests into SQL against your dbt models.

The stack:

```text
dbt models (facts/dimensions)
        |
Semantic models (entities, dimensions, measures/simple metrics)
        |
Metric definitions (simple, ratio, derived, cumulative, conversion)
        |
MetricFlow query planner
        |
BI tools / APIs / AI agents / exports
```

## 15.2 Semantic model concepts

| Concept | Meaning | Example |
|---|---|---|
| Semantic model | A dbt model annotated with semantic metadata | `fct_orders` |
| Entity | A join key with a type | `order` (primary), `customer` (foreign) |
| Dimension | A way to group/filter | `order_date`, `market_segment` |
| Measure / simple metric | An aggregation over a column | `sum(order_total)` |
| Metric | A business calculation | revenue, AOV, conversion rate |
| Time spine | A table of dates used for time-based calculations | one row per day |

Entity types:

- **Primary**: one row per entity in this model, unique and non-null.
- **Unique**: unique but may be a subset, may contain nulls.
- **Foreign**: many rows can reference the same entity.
- **Natural**: a real-world key (for example, a national ID).

Dimensions:

- **Categorical**: group-by attributes (country, segment).
- **Time**: dates/timestamps with a granularity (day, month, year).

## 15.3 The v1.12 semantic model syntax

dbt 1.12 introduced a new YAML specification that nests semantic metadata under the model. A complete example:

```yaml
version: 2

models:
  - name: fct_orders
    description: "One row per order."
    semantic_model:
      enabled: true
      name: orders

    agg_time_dimension: order_date

    columns:
      - name: order_id
        entity:
          type: primary
          name: order

      - name: customer_id
        entity:
          type: foreign
          name: customer

      - name: order_date
        granularity: day
        dimension:
          type: time
          name: order_date

      - name: order_status
        dimension:
          type: categorical
          name: order_status

      - name: payment_method_name
        dimension:
          type: categorical
          name: payment_method

    metrics:
      - name: order_revenue
        description: "Sum of order totals."
        type: simple
        label: "Order Revenue"
        agg: sum
        expr: order_total

      - name: order_count
        description: "Number of orders."
        type: simple
        label: "Order Count"
        agg: count
        expr: order_id

      - name: average_order_value
        description: "Revenue divided by order count."
        type: simple
        label: "Average Order Value"
        agg: average
        expr: order_total
```

A customer dimension model:

```yaml
models:
  - name: dim_customers
    semantic_model:
      enabled: true
    columns:
      - name: customer_id
        entity:
          type: primary
          name: customer
      - name: market_segment
        dimension:
          type: categorical
          name: market_segment
      - name: first_order_date
        granularity: day
        dimension:
          type: time
          name: first_order_date
```

Key rules:

- Each dbt model can define one semantic model.
- Entity names are the join keys; use the same entity name across models to join.
- Dimensions are scoped to the primary entity of their semantic model.
- `agg_time_dimension` is the default time dimension for simple metrics.
- Avoid double underscores in semantic model names.

> **Version note.** Older projects (pre-1.12) use top-level `semantic_models:` with `measures:` and `dimensions:`. The concepts are the same; the YAML shape differs. If you are on 1.11 or earlier, use the older syntax or upgrade. dbt 1.12 also supports Apache Ossie documents as an alternative semantic spec.

## 15.4 Metric types

| Type | Definition | Example |
|---|---|---|
| Simple | Aggregation over one column | `sum(order_total)` |
| Ratio | Numerator / denominator | revenue / orders |
| Derived | Expression over other metrics | revenue - refunds |
| Cumulative | Accumulates over time | cumulative revenue |
| Conversion | Funnel/conversion | visit -> purchase |

### Simple metric

```yaml
metrics:
  - name: order_revenue
    type: simple
    agg: sum
    expr: order_total
```

### Ratio metric (top-level)

```yaml
metrics:
  - name: average_order_value
    type: ratio
    numerator: order_revenue
    denominator: order_count
    label: "Average Order Value"
```

### Derived metric

```yaml
metrics:
  - name: net_revenue
    type: derived
    expr: order_revenue - refund_amount
    label: "Net Revenue"
```

### Cumulative metric

```yaml
metrics:
  - name: cumulative_revenue
    type: cumulative
    input_metric: order_revenue
    window: "7 days"   # optional; omit for unbounded
```

Cumulative and conversion metrics need a time spine. Configure it in `dbt_project.yml`:

```yaml
vars:
  metricflow_time_spine_model: ref('metricflow_time_spine')
```

The time spine model:

```sql
{{ config(materialized='table') }}

select
    date_day as date_day
from {{ ref('date_spine') }}
```

## 15.5 Filters and dimensions

Metrics can be filtered:

```yaml
metrics:
  - name: fulfilled_revenue
    type: simple
    agg: sum
    expr: order_total
    filter: "{{ Dimension('order__order_status') }} = 'F'"
```

Dimensions are referenced as `entity__dimension`, for example `order__order_status` or `customer__market_segment`.

## 15.6 Querying metrics

In the dbt platform/local CLI with Semantic Layer access:

```bash
dbt sl list metrics
dbt sl query --metrics order_revenue,order_count --group-by order__order_status
dbt sl query --metrics order_revenue --group-by order__order_date --order-by order__order_date
```

In self-hosted setups, MetricFlow commands may use `mf query` or the dbt CLI depending on installation. The important concept: you request metrics and dimensions; MetricFlow generates the SQL, including the joins.

Example generated query (conceptual):

```sql
select
    order_status,
    sum(order_total) as order_revenue,
    count(order_id) as order_count
from analytics_lab.gold.fct_orders
group by order_status
```

The value is not the SQL; it is the guarantee that every consumer gets the same definition.

## 15.7 Exports

Exports materialize metric results for tools that cannot query the Semantic Layer directly:

```yaml
exports:
  - name: daily_revenue_export
    config:
      export_as: table
      schema: gold
    metrics:
      - name: order_revenue
      - name: order_count
    dimensions:
      - order__order_date
```

Run exports with the platform's export command or schedule. Exports are useful for BI tools without a native Semantic Layer connector.

## 15.8 Testing metrics

- Add data tests to the underlying models (keys, relationships, ranges).
- Unit-test metric logic where supported.
- Reconcile metric totals to the source of truth.
- Check dimension join coverage (orphan foreign keys).
- Test time spine completeness.
- Monitor query latency and failures.

A metric is only as trustworthy as its models. The Semantic Layer does not replace data quality.

## 15.9 Databricks and BI integration

The Semantic Layer can serve:

- Tableau, Power BI, Excel, Google Sheets, Hex, Mode, and custom APIs.
- AI agents through the dbt MCP server.
- Exports to Delta tables for tools without connectors.

On Databricks, the Semantic Layer queries the gold models through a SQL warehouse. Ensure the service principal has `SELECT` on the semantic models and warehouse access, and that metrics use models with stable grains and tested keys.

## 15.10 Semantic Layer design practices

1. Model facts and dimensions first; metrics come after.
2. Define entities consistently across models (`customer`, `order`, `product`).
3. Use one primary entity per semantic model.
4. Keep metric names business-facing (`revenue`, not `sum_order_total`).
5. Document definitions, including exclusions and time zones.
6. Prefer simple metrics as building blocks; compose ratio/derived metrics.
7. Test joins and grains; fan-out silently inflates metrics.
8. Version breaking metric changes like API changes.
9. Limit the number of metrics; too many is as bad as none.
10. Reconcile with finance/BI before publishing.

## 15.11 Exercises

**Exercise 15.1 - Semantic model.** Add a semantic model to `fct_orders` with a primary entity `order`, a foreign entity `customer`, time dimension `order_date`, and simple metrics `order_revenue` and `order_count`.

**Exercise 15.2 - Dimension model.** Add a semantic model to `dim_customers` with a primary entity `customer` and a categorical dimension `market_segment`.

**Exercise 15.3 - Ratio.** Create `average_order_value` as a ratio of `order_revenue` to `order_count`.

**Exercise 15.4 - Filter.** Create `fulfilled_revenue` filtered to `order_status = 'F'`.

**Exercise 15.5 - Query.** Use `dbt sl` (or MetricFlow) to query revenue by market segment for the last 90 days.

**Exercise 15.6 - Time spine.** Create a date spine and configure `metricflow_time_spine_model`. Build a cumulative revenue metric.

**Answers.** 15.1: Follow the YAML in 15.3. 15.3: Use `type: ratio`, `numerator`, `denominator`. 15.4: Use a `filter` with `Dimension('order__order_status')`. 15.5: Group by `customer__market_segment` and filter on `order__order_date`. 15.6: The spine must have one row per day and a `date_day` column.

## 15.12 Interview check

- What problem does a semantic layer solve?
- What is the difference between a measure and a metric?
- What are entities, and why are they necessary for joins?
- What is a time spine used for?
- How do you test a metric?
- How do you handle a metric definition change?
- How does the Semantic Layer interact with BI tools?

# 16. AI in dbt: Wizard, Copilot, MCP, and Agent Skills

## 16.1 The AI landscape in dbt

As of 2026, dbt Labs organizes AI into a few distinct capabilities:

| Capability | What it is | Where it runs |
|---|---|---|
| **dbt Wizard** | Agentic AI for the full development lifecycle: investigate, build, validate, ship | dbt platform Studio IDE, CLI, Desktop (beta) |
| **dbt Copilot** | Inline AI quick actions: generate SQL, docs, tests, semantic models; chat in Insights/Canvas | dbt platform |
| **dbt MCP server** | Standardized tools that expose dbt metadata, Semantic Layer, CLI, and APIs to AI agents | Local (self-hosted) or remote |
| **Agent skills** | Reusable instructions (`SKILL.md`) that teach a coding agent your project's conventions | Local project/package |
| **dbt VS Code extension** | LSP-powered editor features (completion, lineage, compiled SQL, errors) | VS Code / Cursor |
| **Databricks AI** | Assistant, Genie, AI/BI, AI functions, model serving | Databricks |

The important shift: AI is not just autocomplete. It is grounded in **project context** - lineage, tests, contracts, metrics, and warehouse metadata. An agent that knows your DAG can answer "what breaks if I change this model?" far better than a generic chatbot.

## 16.2 dbt Wizard

Wizard is the recommended agent for governed data development. It can:

- Investigate lineage and downstream impact.
- Generate or refactor SQL from natural language.
- Generate documentation, tests, metrics, and semantic models.
- Compile/run against the warehouse to validate changes.
- Show diffs before persisting changes.
- Work across multiple tasks/branches (Desktop).

### Install Wizard locally (Windows)

```powershell
irm https://public.cdn.getdbt.com/dbt-wizard/install/install-wizard.ps1 | iex
```

Then, in your project:

```powershell
wizard login
wizard "summarize this project and list models with no tests"
```

Useful commands:

| Command | Purpose |
|---|---|
| `wizard "prompt"` | Start an interactive session |
| `wizard exec "prompt"` | Run one prompt non-interactively |
| `wizard review --uncommitted` | Review uncommitted changes |
| `wizard review --base main` | Review a branch diff |
| `wizard resume --last` | Resume a session |
| `wizard apply TASK_ID` | Apply the latest diff |
| `wizard login` / `logout` | Authenticate |
| `wizard mcp add dbt` | Connect MCP tools |
| `wizard update` | Update |

Prerequisites:

- A built `target/` directory (`dbt parse`, `dbt compile`, or `dbt build`).
- Access to a supported AI provider (dbt-managed or BYOK).
- A dbt account for billing/authentication (Wizard usage is metered).

Wizard is warehouse-agnostic and works with dbt v1 and v2.

### Good Wizard prompts

Be specific about the outcome and constraints:

- "Add a `dim_products` model from `stg_products` with a surrogate key, tests for unique/non-null, and a description of the grain. Follow the existing marts conventions."
- "Refactor `int_orders_enriched` to remove the payment method join and create `int_orders_payment_methods`. Update downstream refs and tests."
- "Why is `fct_orders` failing the `relationships` test to `dim_customers`? Inspect the test failures and propose a fix. Do not change the test until you explain the root cause."
- "Generate a semantic model for `fct_orders` with the `order` primary entity and `customer` foreign entity, plus simple metrics for revenue and order count."
- "Review this branch for breaking changes to public models and missing tests."

### Guardrails

- Review every diff; never auto-apply to production.
- Ask for a plan before a multi-file refactor.
- Require the agent to run `dbt build -s ...` and show results.
- Keep changes small; large agent diffs are hard to review.
- Use Git branches and PRs; AI does not bypass code review.
- Do not paste secrets or sensitive data into prompts.

## 16.3 dbt Copilot

Copilot provides inline assistance in the dbt platform:

- Generate SQL for a model from a prompt.
- Generate documentation and tests for selected columns.
- Generate semantic models/metrics.
- Chat with data in Insights (powered by the Semantic Layer).
- Build visual models in Canvas (Enterprise+).

Copilot is configured separately from Wizard. Supported providers include dbt-managed OpenAI, BYOK OpenAI, and BYOK Azure OpenAI. Usage is metered in actions. AI features are enabled by default; admins can turn them off.

Copilot vs Wizard:

| | Copilot | Wizard |
|---|---|---|
| Scope | Inline quick actions, chat | Full-lifecycle agent |
| Best for | Generate a test/doc/metric quickly | Multi-step investigation, refactor, validation |
| Availability | Platform plans (Starter+) | Platform + CLI + Desktop |

If your organization has both, use Copilot for small inline tasks and Wizard for multi-file work.

## 16.4 The dbt MCP server

MCP (Model Context Protocol) is an open standard for connecting AI applications to tools and data. The dbt MCP server exposes:

- dbt CLI commands (self-hosted).
- Semantic Layer queries.
- Metadata discovery (models, lineage, tests, exposures).
- Administrative APIs.
- Codegen tools.
- dbt v2 tools.
- Product docs search.

Two flavors:

| Flavor | Runs | Use |
|---|---|---|
| Self-hosted | On your machine via `uvx dbt-mcp` | Development, local CLI, full toolset |
| Remote | dbt-hosted HTTP endpoint | Consumption, no install, read-only use cases |

### Local setup with VS Code

1. Install `uv` (which provides `uvx`): follow the uv docs for Windows.
2. Create `.vscode/mcp.json` in your project:

```json
{
  "servers": {
    "dbt": {
      "command": "uvx",
      "args": ["dbt-mcp"],
      "env": {
        "DBT_PROJECT_DIR": "${workspaceFolder}",
        "DBT_PROFILES_DIR": "${workspaceFolder}"
      }
    }
  }
}
```

3. Open the MCP panel in VS Code and start the server.
4. Ask your AI assistant (GitHub Copilot Chat, Claude, etc.) to use dbt tools.

Depending on your setup, you may also set `DBT_HOST`, `DBT_TOKEN`, `DBT_PROD_ENV_ID`, `DBT_ACCOUNT_ID`, and other variables. Refer to the dbt MCP environment variable reference for the full list.

### What MCP enables

- "Which models depend on `stg_orders`?"
- "Run `dbt build -s state:modified+` and summarize failures."
- "Query revenue by market segment using the Semantic Layer."
- "Find models with no tests and no description."
- "Explain why this job failed."

MCP is a read/write tool layer; treat it with the same permissions and review discipline as a human with CLI access.

## 16.5 Agent skills

Agent skills are reusable instructions stored in `SKILL.md` files. They teach a coding agent your conventions:

```text
skills/
└── dbt-modeling/
    └── SKILL.md
```

Example `SKILL.md`:

```markdown
# dbt modeling conventions

- Staging models are prefixed `stg_` and materialized as views.
- Marts are prefixed `fct_` or `dim_` and materialized as tables.
- Every primary key has `unique` and `not_null` tests.
- Use `decimal(18,2)` for money, `date` for dates.
- Never use `select *` in marts.
- Add a description stating the grain of every mart.
```

Enable skills:

```yaml
# dbt_project.yml
flags:
  ai_provider: claude   # wizard, claude, openai, codex, cursor, gemini
```

Include skills in your project's `skills/` directory or install a package that ships skills. `dbt deps` installs them into the agent's directory (for example `.claude/skills`); `dbt clean` removes them.

Skills are a lightweight way to make AI output consistent with your team's standards, without repeating instructions in every prompt.

## 16.6 AI in the VS Code extension

The dbt VS Code extension provides:

- Autocomplete for `ref`, sources, macros, and doc blocks.
- Go-to-definition and find references.
- Jinja syntax error detection.
- Compiled SQL preview and CTE preview.
- Lineage (visual and textual).
- Run/build/test commands.
- Column-level lineage and type checking with `static_analysis: strict` (v2).

This is not generative AI by itself, but it is the context layer that makes AI useful: the agent can see the project structure, compiled SQL, and lineage. The extension and Wizard are designed to work together.

## 16.7 Databricks AI capabilities

Databricks offers complementary AI features:

| Feature | Use in a dbt workflow |
|---|---|
| Databricks Assistant | Generate/explain SQL in the editor; useful for exploring sources before modeling |
| Genie | Natural-language Q&A over governed data; can sit on gold tables |
| AI/BI dashboards | Consume marts and metrics |
| Unity Catalog AI functions | Call LLMs from SQL for classification/extraction |
| Model Serving | Deploy ML models; dbt can prepare features |
| Vector search | Build RAG pipelines over documents |

A practical combination: dbt builds trusted gold tables and semantic models; Genie/BI serves them; the Databricks Assistant helps explore; dbt Wizard/MCP helps build and maintain the project.

## 16.8 AI-assisted development workflow

A disciplined loop:

1. **Understand**: ask the agent to summarize the model, its grain, upstream/downstream, and tests.
2. **Plan**: ask for a step-by-step plan and files to change. Review it.
3. **Implement**: let the agent edit in a branch, or apply changes yourself.
4. **Validate**: run `dbt build -s <selection>` and read the results. Do not trust "it should work."
5. **Review**: inspect the diff, tests, docs, and lineage impact.
6. **Ship**: PR, CI, human review.

Prompts that work well:

- Provide context: model names, business rules, constraints, target dialect.
- Ask for tests and documentation in the same request.
- Ask the agent to show the compiled SQL and explain assumptions.
- Constrain scope: "only touch these three files."
- Require validation: "run `dbt build -s ...` and paste the summary."

Prompts that fail:

- "Build me a data warehouse" (too broad).
- "Fix the tests" without showing failures.
- "Make it faster" without a baseline.
- "Use best practices" without defining them.

## 16.9 Security, privacy, and governance for AI

- AI providers may receive prompts, metadata, and query results you approve. Read the provider terms.
- Never send secrets, tokens, or PII in prompts.
- Use the least-privileged account for MCP/Wizard.
- Review generated SQL for correctness and cost (a Cartesian join is still a Cartesian join).
- Keep human review for production changes.
- Log AI-generated changes in PRs; disclose when material.
- Restrict MCP tools that can execute commands if your policy requires it.
- Prefer self-hosted MCP for development; use remote MCP for consumption.

## 16.10 Cost and access

- Wizard is metered by tokens/credits; Copilot by actions; MCP `text_to_sql` consumes Copilot actions.
- BYOK shifts billing to your provider but still requires configuration.
- Set spend limits and monitor usage.
- AI features are enabled by default on the platform; admins can disable them.
- CLI Wizard requires a dbt account and a built project.

## 16.11 Hands-on AI labs

**Lab 16.1 - Project Q&A.** Build the project, then ask Wizard or an MCP-connected assistant: "List the five models with the most downstream dependencies and explain the grain of each." Verify the answer against `dbt ls` and the YAML.

**Lab 16.2 - Generate a model + tests + docs.** Prompt: "Create `dim_products` from `stg_products` with a surrogate key, unique/not-null tests, a description of the grain, and a market segment dimension. Follow the existing marts conventions." Review the diff, run `dbt build -s dim_products`, fix anything the agent missed.

**Lab 16.3 - Impact analysis.** Ask: "What breaks if I rename `order_total` to `order_amount` in `fct_orders`?" Compare the answer to `dbt ls -s fct_orders+` and the docs lineage.

**Lab 16.4 - Incident triage.** Break a test intentionally. Ask the agent to diagnose using the test failure, the model SQL, and upstream data. Require a root cause before a fix.

**Lab 16.5 - Semantic model.** Ask the agent to generate a semantic model for `fct_orders`. Check entity names, grain, metric definitions, and tests. Query a metric.

**Lab 16.6 - MCP.** Configure the local MCP server in VS Code and ask: "Run `dbt build -s state:modified+` and summarize failures." Confirm it used the project's environment.

## 16.12 Exercises

**Exercise 16.1.** Write three prompts for common tasks: adding a test, refactoring a model, and explaining a failure. For each, list the context you must provide.

**Exercise 16.2.** Configure an agent skill with five project conventions. Test whether the agent follows them.

**Exercise 16.3.** Compare a Wizard-generated model with a hand-written one. What did the agent get right or wrong? What would you change in the prompt?

**Exercise 16.4.** Identify three risks of giving an AI agent CLI access to your dbt project. Propose mitigations.

**Answers.** 16.1: Context includes model names, grain, business rules, dialect, constraints, and validation commands. 16.2: Use `SKILL.md` and `ai_provider`; test with a small task. 16.3: Likely issues: missing tests, generic descriptions, wrong materialization. 16.4: Destructive commands, secret exposure, unreviewed production changes; mitigate with least privilege, sandbox schemas, and human review.

## 16.13 Interview check

- What is the difference between dbt Wizard and dbt Copilot?
- What is MCP, and why is it useful for data teams?
- How do you keep AI-generated dbt code safe?
- What context does an AI agent need to be useful in dbt?
- How would you evaluate whether AI improved your team's productivity?
- What are the privacy risks of sending dbt metadata to an AI provider?

# 17. dbt v2 / Fusion: What Changes and How to Migrate

## 17.1 What dbt v2 is

dbt v2 is the Rust-based engine (the productionized Fusion engine) that powers both local dbt and the dbt platform. It is installed with a new PyPI name:

```powershell
pip install dbt
```

There are two distributions:

| Distribution | Package | When |
|---|---|---|
| dbt v2 | `dbt` | Recommended, full experience |
| dbt OSS | `dbt-oss` | Apache 2.0 runtime requirement |

dbt v1.x remains supported. Both produce compatible manifests (v12), so they can run side by side during migration.

## 17.2 Why it matters

- **Faster parsing/compilation** via Rust, especially on large projects.
- **Stricter validation**: unknown configs, YAML keys, CLI flags, and missing macros fail at parse time.
- **Static analysis**: SQL is parsed into a logical plan; column-level lineage and type checks.
- **Built-in LSP**: editor features without a separate language server.
- **New capabilities**: checks, batch tests, docs v2, model freshness, `dbt lint`, dbt State integration, local unit tests (experimental), agent skills.

## 17.3 Installing and switching

For a new environment:

```powershell
python -m venv .venv-dbt2
.\.venv-dbt2\Scripts\Activate.ps1
pip install dbt
dbt --version
```

Adapters: dbt v2 supports BigQuery, Databricks, Redshift, Snowflake, ClickHouse (private beta), Spark (beta), and DuckDB (CLI). For Databricks, use the v2-compatible `dbt-databricks` adapter (the docs state the dbt v2 Databricks adapter is the supported connection method for v2). Check the current compatibility matrix before migrating.

To test the v2 parser while staying on dbt 1.12:

```powershell
dbt parse --use-v2-parser
```

This is opt-in and low-risk; it catches compatibility issues without changing runtime behavior.

## 17.4 What breaks: strict validation

In v1, misspelled configs and unexpected keys were often ignored. In v2 they error. Common fixes:

- Remove deprecated configs and flags.
- Fix `dbt_project.yml` keys that do not match the project name.
- Move top-level YAML anchors under `anchors:`.
- Remove self-referential YAML anchors.
- Replace `--models`/`-m` with `--select`/`-s`.
- Define missing variables and macros (v2 fails at parse, not compile).
- Resolve all deprecation warnings before upgrading.

Run `dbt-autofix` (or the dbt migration agent skill) to automate many fixes. Review its changes; do not blind-merge.

## 17.5 Static analysis

dbt v2 adds a static analysis phase:

```yaml
# dbt_project.yml
models:
  dbt_dbx:
    +static_analysis: strict
```

Modes:

| Mode | Behavior |
|---|---|
| `baseline` (default) | Parses SQL, catches most errors as warnings |
| `strict` | Resolves column types and references; errors before execution; enables column-level lineage |

With strict mode:

- Column-level lineage in docs.
- Column go-to-definition and find references in the LSP.
- Nonexistent-column and type detection.
- `SELECT *` expansion.
- Warehouse-specific syntax checks.

Strict mode requires the project to be resolvable; fix parse errors first. It can be applied per model or project-wide.

## 17.6 New commands and features

| Feature | Command/config | Notes |
|---|---|---|
| Checks | `dbt check` | Project standards enforced at parse/build |
| Batch tests | `dbt test --batch-tests` | Groups compatible tests into fewer queries |
| Docs v2 | `dbt docs generate`, `dbt docs serve` | Parquet artifacts, column lineage, DuckDB-WASM |
| Model freshness | `freshness` config, `dbt freshness` | Warn/error when model data is stale |
| Lint | `dbt lint [file] --fix` | SQLFluff-compatible |
| dbt State | `--manage-state`, `dbt state explain` | Reuse/skip/clone based on logic + freshness |
| Local unit tests | `compute: local` + env flag | Experimental DuckDB execution |
| Agent skills | `skills/`, `ai_provider` | `dbt deps` installs skills |
| Info schema | `--generate-info-schema` | Parquet metadata for agents/tools |
| `dbt login` | `dbt login` | Platform authentication |

### Checks

`checks/` contains SQL rules that enforce project standards:

```sql
-- checks/models_have_descriptions.sql
select *
from {{ ref('...') }}
where description is null
```

Exact check syntax depends on the current v2 release; the concept is a parse-time policy layer. Checks run automatically with `dbt build`; use `--skip-checks` to bypass.

## 17.7 Behavior changes to know

- `dbt build` runs all unit tests first (v1 ran them in lineage order).
- `dbt compile` continues compiling unrelated nodes after an error; downstream nodes are skipped.
- `get_relation()` prints the fully qualified name at parse time, not `None`.
- Project macros are available in YAML in v2 (not in v1).
- `config.get()` does not return `meta` values; use `config.meta_get()`/`meta_require()`.
- `dbt clean` will not delete files outside the project or in resource paths.
- Seeds with extra commas do not create extra columns.
- Threads: v2 manages Databricks/Snowflake parallelism automatically; `threads` is a cap.
- Duplicate docs blocks and package version conflicts error.
- Some deprecated flags are no-ops or errors.

## 17.8 Migration plan

1. **Inventory**: list custom macros, packages, materializations, and deprecated configs.
2. **Upgrade to 1.12** first if you are older; fix deprecations.
3. **Test the parser**: `dbt parse --use-v2-parser`.
4. **Create a v2 environment**: separate venv, install `dbt` and the compatible adapter.
5. **Run `dbt-autofix`** in a branch; review the diff.
6. **Run `dbt parse`, `dbt compile`, `dbt build`** on a dev schema.
7. **Enable `static_analysis: baseline`**, then `strict` where feasible.
8. **Validate packages** for v2 compatibility (`require-dbt-version` includes 2.0, or test them).
9. **Run CI in parallel** (v1 and v2) until confident.
10. **Switch production** when tests, performance, and artifacts match.

Do not migrate and refactor business logic in the same PR. Separate the engine upgrade from semantic changes.

## 17.9 When to stay on v1

Stay on v1.x if:

- A critical package or adapter is not v2-compatible.
- Your orchestration depends on a removed flag or artifact behavior.
- You cannot test the migration safely.
- You need a feature only available in v1 (rare going forward).

dbt v1 remains supported, but new capabilities will land in v2 first. Plan the migration rather than avoiding it.

## 17.10 Exercises

**Exercise 17.1 - Parser test.** Run `dbt parse --use-v2-parser` on your project. Fix every error and warning.

**Exercise 17.2 - Static analysis.** Enable `static_analysis: strict` on one mart. Fix the errors. What does column-level lineage show?

**Exercise 17.3 - Batch tests.** Run `dbt test --batch-tests` and compare the number of queries/runtime with a normal run.

**Exercise 17.4 - Lint.** Run `dbt lint` on a model. Fix three violations with `--fix` and review the diff.

**Exercise 17.5 - Migration plan.** Write a one-page plan for migrating your project to v2, including risks, owners, and rollback.

**Answers.** 17.1: Typical errors: unknown config keys, missing vars, invalid YAML anchors. 17.2: Strict mode requires explicit columns and resolvable references; docs show column lineage. 17.3: Expect fewer queries and lower test runtime on compatible tests. 17.4: Review auto-fixes; formatting changes can obscure logic changes. 17.5: Include a parallel-run period and a rollback to v1.

## 17.11 Interview check

- What is dbt v2, and how does it differ from dbt Core 1.x?
- What is static analysis, and why does it matter?
- How do you migrate a project safely?
- What breaks in strict validation?
- When would you use `--use-v2-parser`?
- How does dbt v2 change CI/CD?
