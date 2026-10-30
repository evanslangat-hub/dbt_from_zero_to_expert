---
title: "dbt from Zero to Expert"
subtitle: "A Hands-On Learning Guide for VS Code + Databricks"
author: "Complete tutorial, lab workbook, and interview preparation"
date: "Edition 1.0 | October 2026 | dbt Core 1.12 and dbt v2 aware"
---

# How to Use This Guide

This is a complete, hands-on path from "I have never used dbt" to "I can design, build, test, deploy, govern, and explain a production dbt project on Databricks." It is written for your environment: **Windows + VS Code + Databricks + dbt-databricks**, with examples that run against Unity Catalog.

The guide is intentionally both a tutorial and a reference. Read Chapters 1-11 in order, do the labs, then use the later chapters as a field manual. Every chapter ends with exercises; Part IX is a full capstone; Part X contains 100+ interview questions with answers, cheat sheets, a glossary, and a study plan.

## The environment this guide targets

| Item | Target used in this book | Notes |
|---|---|---|
| Operating system | Windows 10/11, PowerShell | Commands are PowerShell-friendly |
| Editor | VS Code | dbt extension, Databricks extension, Python, YAML |
| Warehouse | Databricks (Unity Catalog, SQL warehouse) | Works with serverless or pro SQL warehouse |
| dbt engine | dbt Core 1.12.x + dbt-databricks 1.12.x | The version found in your project |
| Newer engine | dbt v2 (Rust/Fusion) | Covered in Chapter 17; syntax is largely compatible |
| Language | SQL + Jinja + limited Python models | PySpark for Python models |
| Catalog placeholder | `analytics_lab` | Replace with your own catalog, for example `clearpay` |
| Schemas | `bronze`, `silver`, `gold`, plus per-developer schemas | Medallion layout |

> **Version note.** dbt Labs now ships two major lines: **dbt v1.x** (the Python-based engine, including the 1.12 release) and **dbt v2** (the Rust-based engine formerly called Fusion, installed with `pip install dbt`). Most project syntax is shared. This guide teaches the concepts and code that work on both, calls out differences, and uses your installed 1.12 line for the labs so that everything runs today.

## How each chapter is organized

Each chapter follows the same rhythm:

1. **Why it matters** - the mental model and the business problem.
2. **How dbt works** - the mechanics, configuration, and SQL/Jinja.
3. **Do it** - copy-paste examples for Databricks.
4. **Production notes** - performance, cost, security, and failure modes.
5. **Exercises** - short tasks, with answers or expected results.
6. **Interview check** - the questions an interviewer is likely to ask about that topic.

## The 12-week learning path

| Weeks | Level | Focus | Deliverable |
|---|---|---|---|
| 1-2 | Beginner | Chapters 1-4: concepts, setup, models, DAG, materializations, staging/marts | A working project with 6 models and tests |
| 3-4 | Beginner+ | Chapters 5-8: Jinja, packages, tests, sources, seeds, snapshots, docs | Reusable macros, source freshness, SCD2 snapshot |
| 5-6 | Intermediate | Chapters 9-11: incremental models, microbatch, Databricks features, selection/state | Incremental fact table and slim CI selection |
| 7-8 | Intermediate+ | Chapters 12-14: orchestration, CI/CD, performance, governance | GitHub Actions pipeline and cost review |
| 9-10 | Advanced | Chapters 15-17: Semantic Layer, AI features, dbt v2/Fusion | Metrics layer and an AI-assisted workflow |
| 11-12 | Expert | Chapters 18-20: capstone, interview drills, teach-back | Capstone shipped, 100+ questions answered |

If you only have one hour per day, do one section plus its exercises. If you have a full week, do a chapter per day and reserve the weekend for the capstone.

## Conventions used

- `analytics_lab` is a placeholder catalog. Replace it with your catalog (`clearpay` in your current profile) or create a dedicated learning catalog.
- `dbt_dbx` is the project name in examples. Yours may differ; the commands are otherwise identical.
- Code blocks marked `sql`, `yaml`, `bash`, `powershell`, `jinja`, or `python` are complete unless marked "fragment."
- **Exercise** boxes are tasks. **Answer** boxes are deliberately short so you can check yourself without reading a full solution.
- Commands assume the virtual environment is activated. On Windows: `.\.venv\Scripts\Activate.ps1`.
- Where a command is specific to dbt v2, it is labelled **(v2)**.

## What you need before Chapter 1

- A Databricks workspace you can sign in to.
- Permission to use a SQL warehouse (serverless is ideal for learning) and to create a schema in a catalog.
- A Databricks personal access token (PAT) or OAuth set up (Chapter 2 walks through both).
- Python 3.10-3.13 recommended. Python 3.14 works with dbt Core 1.12 but some third-party packages may lag; if you hit installation problems, create the venv with 3.12 or 3.13.
- Git and a GitHub account (free) for the CI/CD chapters.
- VS Code installed.

## Contents at a glance

**Part I - Foundations**

1. Analytics Engineering, dbt, and the Databricks Lakehouse
2. Installing and Connecting: Databricks, Python, dbt, VS Code

**Part II - Core dbt**

3. Models, refs, sources, the DAG, and materializations
4. Building a Layered Project: staging, intermediate, marts

**Part III - Reusability**

5. Jinja and Macros
6. Packages and the dbt Ecosystem

**Part IV - Trust**

7. Testing, Unit Tests, and Contracts
8. Sources, Seeds, Snapshots, and Documentation

**Part V - Scale**

9. Incremental Models and Microbatch

**Part VI - Databricks**

10. The Databricks Adapter in Depth

**Part VII - Advanced Engineering**

11. Configuration, Selection, State, and Deployment Patterns
12. Orchestration and CI/CD
13. Performance and Cost Optimization
14. Governance, Security, and dbt Mesh

**Part VIII - Intelligence**

15. The dbt Semantic Layer and Metrics
16. AI in dbt: Wizard, Copilot, MCP, and Agent Skills
17. dbt v2 / Fusion: What Changes and How to Migrate

**Part IX - Capstone**

18. Capstone: Build the ClearPay Lakehouse End to End

**Part X - Mastery**

19. Interview Questions and Answers (100+)
20. Cheat Sheets, Glossary, Resources, and a 30-Day Plan

# PART I - FOUNDATIONS

# 1. Analytics Engineering, dbt, and the Databricks Lakehouse

## 1.1 The problem dbt solves

Every company that uses data eventually builds the same pipeline: extract data from applications, load it into a warehouse, and transform it into tables that analysts, dashboards, and machine-learning models can trust. The extract and load parts are largely commoditized. The transform part is where organizations drown.

Before dbt, transformation logic usually lived in one of four places:

| Where logic lived | Typical failure |
|---|---|
| GUI ETL tools | Logic is hidden in a proprietary canvas; hard to review, test, or version |
| Stored procedures | Thousands of lines of imperative SQL; no dependency graph; no tests |
| Scheduled scripts | Ordering is manual; reruns duplicate data; no documentation |
| Analyst spreadsheets | No lineage, no governance, no reproducibility |

dbt (data build tool) turns transformation into **software engineering**: SQL files in Git, a dependency graph, automated tests, documentation, environments, code review, and CI/CD. It does not extract or load data. It transforms data **inside** the warehouse, using the warehouse's own compute.

The simplest definition:

> dbt compiles and runs `SELECT` statements in dependency order, persists the results as views/tables/incremental models, tests the results, and publishes metadata about everything it built.

## 1.2 ETL versus ELT

Traditional ETL transforms data before loading it into the warehouse. Modern ELT loads raw data first and transforms it in the warehouse.

| | ETL | ELT with dbt |
|---|---|---|
| Transform engine | External tool/server | Warehouse (Databricks SQL/Spark) |
| Raw data | Often discarded | Preserved in a bronze/raw layer |
| Reprocessing | Re-run the ETL job | Re-run SQL against raw history |
| Logic ownership | ETL developers | Analytics engineers, in Git |
| Testing | Tool-specific | Native dbt tests plus warehouse constraints |
| Scaling | ETL server | Warehouse elasticity |

ELT is possible because cloud warehouses separate storage from compute. Databricks' lakehouse is a good example: Delta tables live in cloud storage, while SQL warehouses and clusters provide compute on demand.

## 1.3 What dbt is - and is not

**dbt is:**

- A compiler: Jinja + SQL becomes executable SQL.
- An orchestrator of one project: it understands dependencies and runs nodes in DAG order.
- A testing framework: generic tests, singular tests, unit tests, contracts.
- A documentation generator: a searchable site plus machine-readable artifacts.
- A metadata engine: `manifest.json`, `run_results.json`, `catalog.json`, lineage.
- A collaboration workflow: Git, pull requests, environments, CI/CD.

**dbt is not:**

- An ingestion tool (use Fivetran, Airbyte, Databricks Auto Loader, Kafka, etc.).
- A storage engine (Delta Lake, Iceberg, Parquet do that).
- A general-purpose scheduler (dbt platform has jobs; many teams use Airflow, Dagster, or Databricks Workflows).
- A BI tool (though the Semantic Layer serves metrics to BI tools).
- Magic: a bad model is still bad; dbt makes it visible and testable.

## 1.4 The dbt mental model

Learn these five sentences and most of dbt becomes predictable:

1. **A model is a `SELECT` statement saved as a `.sql` file.** dbt wraps it in DDL/DML depending on the materialization.
2. **`ref()` declares a dependency.** It returns the correct relation name for the current target and adds an edge to the DAG.
3. **The materialization decides how the result is persisted** (view, table, incremental, ephemeral, materialized view, streaming table).
4. **A test is a query that returns bad rows.** Zero rows = pass.
5. **Configuration is inherited and overridden** from project to folder to model, with in-file config taking precedence.

Everything else - macros, packages, snapshots, metrics, exposures - is an extension of those five ideas.

## 1.5 How a dbt run actually works

When you run `dbt run`, roughly this happens:

1. **Parse**: dbt reads `dbt_project.yml`, models, YAML properties, macros, packages, and profiles. It renders Jinja where needed and builds a manifest of nodes and dependencies.
2. **Compile**: each selected model's Jinja is rendered into SQL. `ref()` and `source()` are resolved to fully qualified relation names.
3. **Graph**: dbt topologically sorts selected nodes, respecting dependencies.
4. **Execute**: dbt opens connections (up to `threads`) and runs the materialization for each node. Models at the same DAG level can run in parallel.
5. **Record**: dbt writes artifacts to `target/`, including compiled SQL, run results, and timing.
6. **Test** (if `dbt build` or `dbt test`): tests run after their parent nodes; failures can warn or error.

Two consequences are worth memorizing:

- **Selection happens before execution.** `dbt run -s +fct_orders` selects the fact table and all ancestors, then runs them in order.
- **A failed parent skips its children by default.** In dbt 1.12 you can opt into `on_error: continue` for specific models, but the default is to stop downstream work.

## 1.6 Databricks essentials for dbt developers

You do not need to be a Spark expert, but you must understand the objects dbt touches.

### Workspace, compute, and storage

| Object | What it is | How dbt uses it |
|---|---|---|
| Workspace | The Databricks UI/API home for notebooks, jobs, repos | Where you inspect tables, run SQL, manage jobs |
| SQL warehouse | Serverless or provisioned SQL compute | Default `http_path` in `profiles.yml`; runs models and tests |
| All-purpose cluster | Interactive Spark cluster | Optional per-model compute; required for some Python model modes |
| Job cluster | Ephemeral cluster created for a job | Python models or Databricks Workflows |
| Unity Catalog | Governance layer for data and AI assets | Catalogs, schemas, tables, volumes, grants, tags, lineage |
| Delta Lake | Transactional table format | Default table format for dbt-databricks models |

### The three-level namespace

Unity Catalog uses `catalog.schema.table`:

```sql
select *
from clearpay.silver.fct_orders
limit 10;
```

In dbt:

- `catalog` maps to the `catalog` field in your profile (older adapters call it `database`).
- `schema` is the target schema plus optional custom schema logic.
- `identifier` is the model alias (defaults to the file name).

Your current profile uses catalog `clearpay` and schema `bronze`. The examples in this guide use `analytics_lab`; substitute your catalog.

### Medallion architecture

A practical layering for Databricks:

| Layer | Purpose | Typical materialization | Example |
|---|---|---|---|
| Bronze | Raw ingestion, append-only, minimal cleaning | View or streaming table over raw files | `bronze.orders_raw` |
| Silver | Cleaned, conformed, deduplicated, joined | View/table/incremental | `silver.stg_orders`, `silver.int_orders_enriched` |
| Gold | Business-ready facts, dimensions, marts | Table/incremental/materialized view | `gold.fct_orders`, `gold.dim_customers` |

dbt does not require the medallion pattern, but it maps cleanly to dbt's staging/intermediate/marts convention. Chapter 4 builds it.

### Delta Lake in one minute

Delta Lake adds a transaction log (`_delta_log`) to Parquet files. That enables:

- ACID transactions and time travel (`VERSION AS OF`, `TIMESTAMP AS OF`).
- `MERGE`, `UPDATE`, `DELETE` (important for incremental models and snapshots).
- Schema evolution and enforcement.
- Efficient metadata operations and `OPTIMIZE`/`ZORDER`/liquid clustering.

dbt-databricks defaults to Delta for tables and incremental models. Some configs (`replace_where`, `delete+insert`, `microbatch`) require Delta.

## 1.7 Where dbt fits in the modern data stack

```text
Sources            Ingestion              Storage              Transformation        Consumption
SaaS APIs   ->     Fivetran/Airbyte  ->   Delta/UC       ->    dbt models        ->   BI, notebooks,
Operational DBs    Auto Loader/Kafka      Bronze/Silver/Gold     tests, metrics         Semantic Layer,
Files/Events       Custom pipelines       (Unity Catalog)        docs, lineage          ML, apps
```

dbt sits at the transformation and definition layer. The Semantic Layer (Chapter 15) extends it into a metrics layer. dbt Mesh (Chapter 14) extends it across teams and projects. AI features (Chapter 16) extend it into an agentic development workflow.

## 1.8 The analytics engineer role

An analytics engineer sits between data engineering and analytics. The role typically owns:

- Modeling raw data into clean, documented, tested marts.
- Defining business logic once (revenue, active customers, churn) and reusing it.
- Maintaining data quality tests and incident response for transformation failures.
- Reviewing SQL like software: style, performance, contracts, lineage.
- Partnering with analysts on metric definitions and with data engineers on ingestion.
- Owning the dbt project's structure, CI/CD, and documentation.

Skills that make an expert:

| Skill | Why it matters |
|---|---|
| SQL fluency (window functions, joins, CTEs, dedup) | The daily work |
| Dimensional modeling | Stable, understandable marts |
| Jinja/macros | DRY logic without hiding it |
| Testing and data quality | Trust |
| Warehouse performance | Cost and latency |
| Git/CI/CD | Safe change |
| Databricks/Unity Catalog | Governance and operations |
| Communication | Metrics are a social contract |

## 1.9 A first look at a dbt project

```text
dbt_dbx/
├── dbt_project.yml          # project identity and config
├── profiles.yml             # connection (often in ~/.dbt/)
├── packages.yml             # external packages
├── models/
│   ├── staging/             # 1:1 with sources
│   ├── intermediate/        # reusable business logic
│   └── marts/               # facts, dimensions, wide tables
├── macros/                  # reusable Jinja
├── tests/                   # singular tests
├── seeds/                   # small CSVs
├── snapshots/               # SCD2 history
├── analyses/                # compiled but not materialized
├── target/                  # artifacts (generated)
├── logs/                    # logs (generated)
└── README.md
```

That is the whole surface area. The sophistication comes from how you use it.

## 1.10 Exercises

**Exercise 1.1 - Concepts.** In your own words, explain the difference between dbt and an ingestion tool, and between dbt and a scheduler.

**Exercise 1.2 - Mental model.** A model `fct_orders` selects from `stg_orders`, which selects from `source('raw', 'orders')`. Draw the DAG. Which node runs first? What happens to `fct_orders` if `stg_orders` fails?

**Exercise 1.3 - Databricks.** Write the fully qualified name of a table called `fct_orders` in schema `gold` in catalog `clearpay`. Then write the `ref()` call that would produce it if the model file is `fct_orders.sql`.

**Exercise 1.4 - Materialization intuition.** For each case, choose view, table, incremental, or materialized view: (a) a lightweight rename of a source, (b) a dashboard table rebuilt nightly, (c) a billion-row event table where only new events arrive, (d) an aggregation that Databricks should refresh automatically.

**Answers.** 1.1: dbt transforms data already in the warehouse; ingestion moves data in; a scheduler triggers work, while dbt understands dependencies and executes a project. 1.2: source -> `stg_orders` -> `fct_orders`; `stg_orders` runs first; by default `fct_orders` is skipped when `stg_orders` errors. 1.3: `clearpay.gold.fct_orders`; `{{ ref('fct_orders') }}`. 1.4: (a) view, (b) table or materialized view, (c) incremental, (d) materialized view (or streaming table for ingestion).

## 1.11 Interview check

- What does dbt actually execute? How does it know the order?
- Why is ELT more common than ETL today?
- What is the difference between `ref()` and `source()`?
- What is stored in `manifest.json`, and why would a platform team care?
- When would you *not* use dbt?
- Explain the medallion architecture and its trade-offs.

# 2. Installing and Connecting: Databricks, Python, dbt, VS Code

This chapter gets you from zero to a green `dbt debug` and a first model. Do not skip the permission checks; most "dbt is broken" issues are authentication, catalog, or compute issues.

## 2.1 Prerequisites and permissions

### Databricks side

You need:

1. A workspace URL, for example `https://dbc-xxxx.cloud.databricks.com`.
2. A SQL warehouse (serverless or pro). Note its **HTTP path** from **SQL Warehouses > your warehouse > Connection details**.
3. A catalog and a schema where you can create objects.
4. A personal access token (PAT) or OAuth login.

Minimum Unity Catalog privileges for a development schema:

| Privilege | Object | Why |
|---|---|---|
| `USE CATALOG` | Catalog | See the catalog |
| `USE SCHEMA` | Schema | See objects |
| `CREATE TABLE`, `CREATE VIEW` | Schema | Create models |
| `SELECT` | Tables/views | Read sources and upstream models |
| `MODIFY` | Tables | Incremental writes, snapshots |
| `CREATE SCHEMA` | Catalog | Optional, if dbt should create per-developer schemas |

Ask your Databricks admin for a development catalog (or a schema in an existing catalog) and a SQL warehouse. In a personal/free workspace you are usually the metastore admin and already have access.

### Local side

- Python 3.10-3.13 (3.12 is a safe default). Check with `python --version`.
- Git.
- VS Code.
- PowerShell (default on Windows).

## 2.2 Create the Databricks objects (SQL editor)

Run these in the Databricks SQL editor, adjusting names. If your admin already created a catalog, skip the catalog statement.

```sql
-- A learning catalog. Skip if you must use an existing catalog.
CREATE CATALOG IF NOT EXISTS analytics_lab;

-- Schemas for the medallion layers and a landing area for raw data.
CREATE SCHEMA IF NOT EXISTS analytics_lab.bronze;
CREATE SCHEMA IF NOT EXISTS analytics_lab.silver;
CREATE SCHEMA IF NOT EXISTS analytics_lab.gold;

-- Optional: a schema for dbt seeds and snapshots.
CREATE SCHEMA IF NOT EXISTS analytics_lab.utility;

-- Verify.
SHOW SCHEMAS IN analytics_lab;
```

If you are using an existing catalog (for example `clearpay`), replace `analytics_lab` everywhere. Do not create objects in a production schema while learning.

### A source dataset you can use

Databricks workspaces commonly expose the `samples` catalog. Check:

```sql
SHOW CATALOGS LIKE 'samples';
SHOW SCHEMAS IN samples;
SELECT * FROM samples.tpch.orders LIMIT 5;
```

If `samples.tpch` exists, you have a ready-made retail dataset: `orders`, `lineitem`, `customer`, `part`, `supplier`, `nation`, `region`. If it does not, use any small CSV you own and load it into `analytics_lab.bronze`, or use the seed files in Chapter 8.

If you want raw tables that look like an ingestion landing zone, create them with CTAS:

```sql
CREATE OR REPLACE TABLE analytics_lab.bronze.orders_raw AS
SELECT * FROM samples.tpch.orders;

CREATE OR REPLACE TABLE analytics_lab.bronze.customer_raw AS
SELECT * FROM samples.tpch.customer;

CREATE OR REPLACE TABLE analytics_lab.bronze.lineitem_raw AS
SELECT * FROM samples.tpch.lineitem;
```

> In a shared workspace, `samples` may be read-only but readable. If not, ask your admin or load your own CSV.

## 2.3 Create and activate a virtual environment

From your project folder (`C:\Users\THINKBOOK\Documents\dbt_dbx`):

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
```

If PowerShell blocks activation:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

Then activate again. You should see `(.venv)` in the prompt.

## 2.4 Install dbt-databricks

For the dbt Core 1.12 line:

```powershell
pip install "dbt-databricks>=1.12,<1.13"
dbt --version
```

Expected output includes `dbt-core`, `dbt-databricks`, and `dbt-spark`. If you want the newest engine instead, see Chapter 17: `pip install dbt` installs dbt v2, which is a different distribution. Do not install both into the same environment.

`dbt-databricks` brings in `dbt-core`, the Databricks adapter, and the Spark adapter. Pin versions in `requirements.txt` for reproducibility:

```text
dbt-databricks==1.12.8
```

Then:

```powershell
pip install -r requirements.txt
```

## 2.5 Authenticate to Databricks

### Option A: Personal access token (simplest for learning)

1. In Databricks: click your avatar > **Settings** > **Developer** > **Access tokens** > **Generate new token**.
2. Copy the token once.
3. Store it in an environment variable, never in Git:

```powershell
# Current session only:
$env:DATABRICKS_TOKEN = "dapi-xxxxxxxxxxxxxxxx"

# Persist for your Windows user (new terminals):
[Environment]::SetEnvironmentVariable("DATABRICKS_TOKEN", "dapi-xxxxxxxxxxxxxxxx", "User")
```

4. Your `profiles.yml` references it with `{{ env_var('DATABRICKS_TOKEN') }}`.

### Option B: OAuth (recommended for humans)

```yaml
dev:
  type: databricks
  catalog: analytics_lab
  schema: bronze
  host: dbc-xxxx.cloud.databricks.com
  http_path: /sql/1.0/warehouses/xxxxxxxxxxxxxxxx
  auth_type: oauth
  threads: 4
```

`dbt debug` or the first run opens a browser for consent. OAuth tokens expire, so you may re-authenticate periodically.

### Option C: Service principal (CI/CD)

Create a Databricks service principal, grant it access to the catalog/schema/warehouse, and store its client ID/secret in your CI secret store. Use `auth_type: oauth` with client credentials or a service-principal token. Never commit secrets.

### Where does `profiles.yml` live?

dbt looks in this order:

1. `--profiles-dir` if passed.
2. `DBT_PROFILES_DIR` environment variable.
3. The current directory.
4. `~/.dbt/`.

For a single project, keeping `profiles.yml` in the project root is convenient but risky: it must be gitignored. Many teams keep it in `~/.dbt/profiles.yml`. This guide shows it in the project for clarity, with `.gitignore` protection.

## 2.6 Understand `profiles.yml`

A minimal, correct profile for Unity Catalog:

```yaml
dbt_dbx:
  target: dev
  outputs:
    dev:
      type: databricks
      catalog: analytics_lab
      schema: bronze
      host: dbc-xxxx.cloud.databricks.com
      http_path: /sql/1.0/warehouses/xxxxxxxxxxxxxxxx
      token: "{{ env_var('DATABRICKS_TOKEN') }}"
      threads: 4
      connect_timeout: 600
      connect_retries: 3
```

Key fields:

| Field | Meaning | Common mistake |
|---|---|---|
| `type` | Adapter name | Using `databricks` with the wrong package installed |
| `catalog` | Unity Catalog catalog | Using a Hive Metastore database name |
| `schema` | Default target schema | Expecting it to be the full three-part name |
| `host` | Workspace hostname, no `https://` | Including `https://` or a trailing path |
| `http_path` | SQL warehouse or cluster path | Copying the cluster path for a warehouse |
| `token` | PAT or OAuth | Hard-coding a token; committing it |
| `threads` | Parallel connections | Setting it higher than the warehouse can handle |

> **Your current project.** The `dbt_project.yml` name is `dbt_dbx` but model configs are nested under `databricks_dbt`. dbt only applies config under the project name, so those bronze/silver/gold settings are currently ignored. Either rename the key to `dbt_dbx` or change `name:` to `databricks_dbt`. This is a classic silent misconfiguration; Chapter 3 explains config resolution.

## 2.7 Create the project

If starting fresh:

```powershell
dbt init dbt_dbx
```

The wizard asks for:

- project name (`dbt_dbx`)
- database/catalog (`analytics_lab`)
- schema (`bronze`)
- host
- http path
- authentication method
- threads

It writes `dbt_project.yml`, a starter model, and a profile. If you already have the project, skip this.

### Project anatomy

```text
dbt_dbx/
├── analyses/            # SQL compiled but not materialized
├── macros/              # Jinja macros
├── models/
│   ├── staging/
│   │   └── _sources.yml
│   ├── intermediate/
│   └── marts/
├── seeds/               # CSV files
├── snapshots/           # SCD2 snapshots
├── tests/               # singular tests
├── dbt_project.yml
├── packages.yml
├── profiles.yml         # or ~/.dbt/profiles.yml
├── requirements.txt
├── .gitignore
└── README.md
```

A good `.gitignore`:

```gitignore
.venv/
target/
dbt_packages/
logs/
profiles.yml
.env
*.log
__pycache__/
```

## 2.8 Configure `dbt_project.yml`

A clean starter configuration:

```yaml
name: dbt_dbx
version: "1.0.0"
config-version: 2
profile: dbt_dbx

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

clean-targets:
  - target
  - dbt_packages

models:
  dbt_dbx:
    staging:
      +materialized: view
      +schema: silver
      +tags: ["staging"]
    intermediate:
      +materialized: view
      +schema: silver
      +tags: ["intermediate"]
    marts:
      +materialized: table
      +schema: gold
      +tags: ["marts"]

seeds:
  dbt_dbx:
    +schema: utility
    +quote_columns: false

snapshots:
  dbt_dbx:
    +target_schema: silver
    +tags: ["snapshot"]
```

Important details:

- `name` must match the profile key and the top-level key under `models:`.
- `config-version: 2` is the modern format.
- `+` prefixes are required in `dbt_project.yml` to distinguish config from folder names.
- `+schema: silver` does **not** replace the target schema by default; it becomes `<target_schema>_silver` unless you override `generate_schema_name`. Many teams prefer one schema per layer; Chapter 3 shows the custom macro.
- Materializing staging as views is a good default: it keeps raw logic close to sources and avoids storing redundant data.

## 2.9 Connect and verify

```powershell
dbt debug
```

Expected: connection OK, profile OK, project OK. If the profile is in the project root and dbt cannot find it, run:

```powershell
dbt debug --profiles-dir .
```

Then check warehouse permissions and the catalog:

```powershell
dbt run-operation current_catalog
```

If you do not have that macro yet, use a simple model (next section).

## 2.10 Your first model

Create `models/staging/stg_orders.sql`:

```sql
select
    o_orderkey      as order_id,
    o_custkey       as customer_id,
    o_orderstatus   as order_status,
    o_totalprice    as order_total,
    o_orderdate     as order_date,
    o_orderpriority as order_priority,
    o_clerk         as clerk,
    o_comment       as comment
from {{ source('bronze', 'orders_raw') }}
```

Create `models/staging/_sources.yml`:

```yaml
version: 2

sources:
  - name: bronze
    catalog: analytics_lab
    schema: bronze
    tables:
      - name: orders_raw
        description: Raw orders landed from the source system.
        loaded_at_field: _ingested_at
        freshness:
          warn_after: {count: 12, period: hour}
          error_after: {count: 24, period: hour}
```

If your raw table has no `_ingested_at`, remove the freshness block for now; Chapter 8 covers source freshness properly.

Create a schema file with tests, `models/staging/_staging.yml`:

```yaml
version: 2

models:
  - name: stg_orders
    description: "One row per order, renamed and cast from the raw orders table."
    columns:
      - name: order_id
        description: "Primary key."
        data_tests:
          - unique
          - not_null
      - name: customer_id
        data_tests:
          - not_null
      - name: order_status
        data_tests:
          - accepted_values:
              values: ["O", "P", "F"]
```

Run:

```powershell
dbt run --select stg_orders
dbt test --select stg_orders
```

Verify in Databricks:

```sql
SELECT * FROM analytics_lab.silver.stg_orders LIMIT 10;
```

If `+schema: silver` is configured as above and `generate_schema_name` is default, the table may actually be `analytics_lab.bronze_silver.stg_orders`. Run `dbt show --select stg_orders --limit 5` or check the run log for the exact relation. Chapter 3 fixes schema naming.

## 2.11 VS Code setup

Install these extensions:

| Extension | Publisher | Purpose |
|---|---|---|
| dbt | dbt Labs (`dbtLabsInc.dbt`) | Parse, IntelliSense, lineage, run/test, compiled SQL |
| Databricks | Databricks | Browse catalogs, run SQL, manage clusters |
| Python | Microsoft | Virtual env and Python models |
| YAML | Red Hat | YAML validation (see conflict note) |
| SQLFluff | SQLFluff | Linting (optional; `dbt lint` exists in v2) |
| GitLens | GitKraken | Git history (optional) |

Recommended settings (`.vscode/settings.json`):

```json
{
  "files.associations": {
    "*.sql": "jinja-sql",
    "*.yml": "yaml"
  },
  "editor.formatOnSave": true,
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/Scripts/python.exe",
  "dbt.perspective": "sql"
}
```

Notes:

- The official dbt extension is the one that understands `ref()`, sources, macros, and lineage. Avoid installing several dbt extensions at once; they can conflict over language servers.
- If the Red Hat YAML extension flags dbt-only keys, disable it for the workspace or add the dbt schema.
- The dbt extension works with both v1 and v2; features such as column-level lineage and strict static analysis require `static_analysis: strict` on v2.
- The extension can run `dbt run`, `dbt build`, and `dbt test`, preview compiled SQL, and show lineage. Use the command palette (`Ctrl+Shift+P`) and search "dbt".

### Databricks in VS Code

The Databricks extension lets you:

- Browse Unity Catalog tables and schemas.
- Run SQL against a warehouse.
- Attach notebooks and sync files (not required for dbt).
- Configure a cluster/warehouse for Python development.

For dbt work, the SQL warehouse connection in `profiles.yml` is what matters; the extension is a convenience for inspection.

## 2.12 First-run troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Could not find profile named 'dbt_dbx'` | Profile name/key mismatch or wrong directory | Match `profile:` in `dbt_project.yml`; run with `--profiles-dir` |
| `Catalog 'x' does not exist` | Wrong catalog or no `USE CATALOG` | Check `SHOW CATALOGS`; ask for grants |
| `Schema 'x' does not exist` | Target schema missing and no create permission | Create schema or grant `CREATE SCHEMA` |
| `Invalid access token` | Expired PAT, env var not set in this terminal | Re-set `$env:DATABRICKS_TOKEN`; test with `dbt debug` |
| `http_path` error | Cluster path used instead of warehouse path | Copy the SQL warehouse HTTP path |
| `ModuleNotFoundError: dbt` | venv not activated | Activate `.venv`; check `dbt --version` |
| `dbt-databricks requires Python <3.14` (or similar) | Python too new for a dependency | Use Python 3.12/3.13 venv |
| Tables land in an unexpected schema | Default `generate_schema_name` concatenates | Override the macro (Chapter 3) |
| Model config in `dbt_project.yml` ignored | Key does not match project `name` | Fix the top-level key |
| `Database Error: PERMISSION_DENIED` | Missing `SELECT`/`MODIFY`/`CREATE` | Ask admin; check UC grants |
| `dbt run` hangs at connect | Warehouse starting or network/proxy | Increase `connect_timeout`; check warehouse state |
| YAML parse error on `data_tests` | Older dbt expects `tests:` | 1.12 supports `data_tests`; check version |
| `dbt docs serve` port busy | Another process uses 8080 | `dbt docs serve --port 8081` |

## 2.13 A repeatable environment checklist

Before every new project:

1. `python --version` and `dbt --version` inside the venv.
2. `dbt debug` passes.
3. `dbt deps` succeeds (if packages are used).
4. `dbt parse` succeeds.
5. A trivial `dbt run --select <one_model>` succeeds.
6. `dbt test --select <one_model>` succeeds.
7. `git status` shows no secrets, `target/`, or `dbt_packages/`.
8. CI uses a pinned `requirements.txt` and a service principal.

## 2.14 Exercises

**Exercise 2.1 - Connect.** Create a `profiles.yml` for catalog `analytics_lab`, schema `bronze`, using an environment variable for the token. Run `dbt debug` and fix any errors.

**Exercise 2.2 - Permissions.** In Databricks SQL, run `SHOW GRANTS ON SCHEMA analytics_lab.bronze`. Which privileges do you have? Which are missing for creating a table? For reading a source?

**Exercise 2.3 - First model.** Create `stg_customers.sql` from `customer_raw` with at least five renamed columns. Add `unique` and `not_null` tests on the customer key. Run `dbt build --select stg_customers`.

**Exercise 2.4 - Inspect artifacts.** After the run, open `target/compiled/dbt_dbx/models/staging/stg_customers.sql` and `target/run_results.json`. What SQL did dbt execute? How long did it take?

**Exercise 2.5 - VS Code.** Open the model in VS Code, preview compiled SQL, and open the lineage view. Confirm the source -> staging edge is visible.

**Answers.** 2.2: You need `USE CATALOG`, `USE SCHEMA`, `SELECT` on the source, and `CREATE TABLE`/`CREATE VIEW` plus `MODIFY` for writes. 2.3: Use `{{ source('bronze', 'customer_raw') }}`; tests go under `columns:`. 2.4: The compiled file shows the rendered SQL with the fully qualified source; `run_results.json` contains status, timing, and adapter response. 2.5: The official dbt extension's lineage view requires the project to parse; check the Problems panel if it does not.

## 2.15 Interview check

- Walk me through `dbt debug` and what it validates.
- What is the difference between `catalog`, `schema`, and `target`?
- How do you keep Databricks credentials out of Git?
- Why might a dbt model land in an unexpected schema?
- What happens if two developers run dbt into the same schema at the same time?
- How would you set up dbt for a new developer in under 30 minutes?

# PART II - CORE dbt

# 3. Models, refs, sources, the DAG, and Materializations

## 3.1 The anatomy of a model

Every model file is a SQL `SELECT` with optional Jinja:

```sql
{{ config(
    materialized = 'table',
    tags = ['marts', 'finance']
) }}

with orders as (
    select * from {{ ref('stg_orders') }}
),

final as (
    select
        order_id,
        customer_id,
        order_date,
        order_total
    from orders
)

select * from final
```

Rules:

- The file must contain one final `SELECT` (or a set of statements ending in a `SELECT` for some adapters).
- Do not end with a semicolon in a model file; dbt wraps the SQL.
- `config()` can appear anywhere, but convention is at the top.
- The file name becomes the relation name unless `alias` is configured.
- Folders do not affect the relation name by default, only configuration inheritance and organization.

## 3.2 `ref()`: the most important function in dbt

```sql
select * from {{ ref('stg_orders') }}
```

`ref()` does three jobs:

1. Resolves the correct relation for the current target (`analytics_lab.silver.stg_orders`, a dev schema, etc.).
2. Adds a dependency edge to the DAG.
3. Enables lineage, documentation, and selection.

Never hard-code a model's schema/table in another model. `ref()` is what makes environments portable and DAG ordering correct.

`ref()` also accepts a version (Chapter 11):

```sql
select * from {{ ref('dim_customers', version=2) }}
```

## 3.3 `source()`: declaring raw data

Sources are declared in YAML:

```yaml
version: 2

sources:
  - name: bronze
    catalog: analytics_lab
    schema: bronze
    description: "Raw landing tables loaded by ingestion."
    tables:
      - name: orders_raw
        identifier: orders_raw
        description: "One row per order, append-only."
        loaded_at_field: _ingested_at
        freshness:
          warn_after: {count: 12, period: hour}
          error_after: {count: 24, period: hour}
```

Use them:

```sql
select * from {{ source('bronze', 'orders_raw') }}
```

Benefits:

- Lineage starts at the source, not at a hard-coded table.
- Freshness checks work.
- Source tests and descriptions work.
- You can swap environments (dev/prod catalogs) without editing models.

`source()` returns a relation object; you can call `.identifier` or use it in `adapter.get_relation` if needed.

### Source vs staging

A common debate: should staging models select directly from sources, or should ingestion create views first? Best practice:

- Sources point at raw tables.
- Staging models are the only place that references sources.
- Staging models rename, cast, deduplicate, and standardize.
- Marts never reference sources directly.

This gives you one place to change when a source schema changes.

## 3.4 The DAG

dbt builds a directed acyclic graph from `ref()` and `source()` edges. You can inspect it:

```powershell
dbt list --select stg_orders+
dbt list --select +fct_orders
dbt list --select @fct_orders
dbt ls --resource-type model
```

Graph operators:

| Operator | Meaning | Example |
|---|---|---|
| `+model` | All ancestors | `+fct_orders` |
| `model+` | All descendants | `stg_orders+` |
| `+model+` | Ancestors and descendants | `+fct_orders+` |
| `@model` | Model, ancestors, and descendants | `@fct_orders` |
| `n+model` | Ancestors up to n levels | `2+fct_orders` |

The DAG is why dbt can run independent branches in parallel. It is also why changing a staging model can rebuild a large part of the project; use selectors and state (Chapter 11) to control scope.

## 3.5 Materializations

A materialization is the strategy dbt uses to persist a model. Choose based on freshness, query cost, data volume, and who consumes the table.

| Materialization | What dbt does | Best for | Avoid when |
|---|---|---|---|
| `view` | `CREATE VIEW` each run | Light transforms, staging, always-fresh data | Heavy joins/aggregations queried often |
| `table` | `CREATE TABLE AS` each run | Marts, dashboards, moderate data | Huge tables rebuilt often |
| `incremental` | First run table; later DML (merge/append/replace) | Large event/fact tables | Small tables; logic that must fully recompute |
| `ephemeral` | No relation; inlined as CTE | Lightweight reuse in one or two models | You need to query it, test it directly, or use contracts |
| `materialized_view` | Databricks managed MV; auto-refresh | Aggregations serving dashboards | Complex unsupported SQL; need row-level control |
| `streaming_table` | Databricks streaming table (Lakeflow) | Ingestion/append-only streams | Non-streaming sources, complex updates |

Databricks-specific notes:

- `materialized_view` and `streaming_table` require Unity Catalog and a serverless SQL warehouse (per Databricks docs).
- `streaming_table` is provided by dbt-databricks, not core dbt.
- MVs and streaming tables support `partition_by`, `liquid_clustered_by` (1.11+), `tblproperties`, `databricks_tags`, and schedules.
- Python models support only `table` and `incremental`.

### Choosing a materialization: a decision tree

1. Is the model consumed directly by a BI tool or many downstream models?
   - Yes -> table, incremental, or materialized view.
   - No -> view or ephemeral.
2. Is the source append-only and huge?
   - Yes -> incremental (merge/append) or streaming table.
3. Does the warehouse support automatic refresh with acceptable latency?
   - Yes -> materialized view.
4. Is the transformation trivial and cheap?
   - Yes -> view.
5. Is the logic reused in only one or two models and never queried directly?
   - Yes -> ephemeral (sparingly).

## 3.6 Configuring materializations

Three places, in increasing specificity:

**Project file** (applies to a folder):

```yaml
models:
  dbt_dbx:
    staging:
      +materialized: view
    marts:
      +materialized: table
```

**Properties file** (applies to a model):

```yaml
models:
  - name: fct_orders
    config:
      materialized: incremental
      unique_key: order_id
```

**In the model file** (highest precedence):

```sql
{{ config(materialized='incremental', unique_key='order_id') }}
```

Precedence: in-file > properties YAML > project file. CLI flags can override some configs at runtime.

## 3.7 Configuration inheritance and the `+` prefix

In `dbt_project.yml`, `+` means "this is a config, not a subfolder":

```yaml
models:
  dbt_dbx:          # project name
    staging:        # folder
      +materialized: view
      +tags: ["staging"]
```

Without `+`, dbt treats `materialized` as a folder name and silently ignores it (or errors in v2 strict mode). This is one of the most common beginner mistakes.

### The project-name trap

Config only applies under the project's `name`. If `name: dbt_dbx` but config is under `databricks_dbt`, nothing applies. Your current project has exactly this mismatch. Fix it before building further.

### Config scopes

| Config | Can be set in project | Can be set on model | Notes |
|---|---|---|---|
| `materialized` | Yes | Yes | Model wins |
| `schema` | Yes | Yes | Often combined with `generate_schema_name` |
| `tags` | Yes | Yes | Model tags merge with folder tags |
| `enabled` | Yes | Yes | Disable a model without deleting it |
| `meta` | Yes | Yes | Arbitrary metadata for tooling |
| `grants` | Yes | Yes | Databricks/UC privileges |
| `contract` | No | Yes | Model-level only |
| `unique_key` | Yes | Yes | Incremental |
| `incremental_strategy` | Yes | Yes | Incremental |

## 3.8 Schemas, databases, and aliases

By default, dbt creates relations in the target schema from `profiles.yml`. `+schema` customizes it.

### Default behavior

`generate_schema_name` in dbt-core does this:

- If a custom schema is configured: `<target_schema>_<custom_schema>`.
- If not: `<target_schema>`.

So with target schema `bronze` and `+schema: silver`, you get `bronze_silver`, not `silver`. Many teams find this surprising.

### Override for clean layer schemas

Create `macros/generate_schema_name.sql`:

```sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

Now `+schema: silver` produces `analytics_lab.silver`. In development, you may want per-developer isolation instead:

```sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if target.name == 'prod' -%}
        {%- if custom_schema_name is none -%}{{ default_schema }}
        {%- else -%}{{ custom_schema_name | trim }}{%- endif -%}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim if custom_schema_name else 'default' }}
    {%- endif -%}
{%- endmacro %}
```

Result in dev: `dev_jane_silver`; in prod: `silver`. This prevents developers from overwriting each other.

### Aliases

```sql
{{ config(alias='orders') }}
```

The relation becomes `<schema>.orders` instead of `<schema>.stg_orders`. Use aliases for stable public names or to match an existing table, not to hide model names.

### Databases/catalogs

To materialize in a different catalog:

```sql
{{ config(database='analytics_lab_metrics') }}
```

On Databricks, `database` is an alias for catalog in many contexts; prefer `catalog` in profiles and `database` in configs only if your adapter expects it. Chapter 10 clarifies.

## 3.9 Ephemeral models: use and abuse

```sql
{{ config(materialized='ephemeral') }}

select ...
```

dbt inlines the model as a CTE named `__dbt__cte__<model>` in downstream models. Pros: no storage, reusable logic. Cons: cannot be queried directly, cannot be tested easily, can make compiled SQL enormous, and does not support contracts.

Use ephemeral for tiny helpers used once or twice. Prefer views for anything you might need to debug.

## 3.10 Model properties: descriptions, tests, docs

```yaml
version: 2

models:
  - name: fct_orders
    description: "One row per order with payment and customer attributes."
    config:
      materialized: incremental
      unique_key: order_id
    columns:
      - name: order_id
        description: "Primary key."
        data_tests:
          - unique
          - not_null
      - name: customer_id
        description: "Foreign key to dim_customers."
        data_tests:
          - relationships:
              to: ref('dim_customers')
              field: customer_id
```

This YAML is not decoration: it drives tests, docs, and the catalog.

## 3.11 `target`, `this`, and other context

Inside a model or macro:

| Object | Meaning |
|---|---|
| `target.name` | Environment name (`dev`, `ci`, `prod`) |
| `target.schema` | Default schema |
| `target.catalog` / `target.database` | Catalog |
| `this` | The current model's relation object |
| `is_incremental()` | True if the model exists and this is not a full refresh |
| `var('name', default)` | Project/CLI variable |
| `env_var('NAME')` | Environment variable |
| `model.name` | Current model name |
| `model.path` | File path |
| `run_started_at` | Timestamp of the run |
| `invocation_id` | Unique run ID |

These are available in models and macros; not all are available in YAML (v2 expands YAML macro support).

## 3.12 Running and inspecting models

```powershell
dbt run                         # all models
dbt run -s stg_orders           # one model
dbt run -s staging              # everything in a folder
dbt run -s tag:finance          # by tag
dbt run -s +fct_orders          # ancestors + model
dbt run -s fct_orders+          # model + descendants
dbt build -s marts              # models + tests + seeds + snapshots in DAG order
dbt compile -s stg_orders       # render SQL without running
dbt show -s stg_orders --limit 5
dbt list -s stg_orders --output json
```

`dbt build` is usually preferred in CI and production because it interleaves tests with models: a failed test prevents downstream models from building.

## 3.13 Exercises

**Exercise 3.1 - Fix the config.** Your `dbt_project.yml` has `name: dbt_dbx` but model config under `databricks_dbt`. What happens? Fix it and verify with `dbt compile` or `dbt list --output json`.

**Exercise 3.2 - Schema logic.** With target schema `dev_alice`, `+schema: silver`, and the default macro, what schema is used? With the override macro from 3.8, what schema is used in dev and prod?

**Exercise 3.3 - Materializations.** Build `stg_orders` as a view and `fct_orders` as a table. Inspect Databricks: `SHOW CREATE TABLE`. What DDL did dbt run? Then change `fct_orders` to incremental and run twice; what changes?

**Exercise 3.4 - Ephemeral.** Create an ephemeral model `int_order_totals` used by `fct_orders`. Compile `fct_orders` and find the inlined CTE. What are two drawbacks?

**Exercise 3.5 - DAG.** Run `dbt list -s +fct_orders --output json` and count nodes. Which nodes are ancestors? Which would rebuild if `stg_orders` changed?

**Answers.** 3.1: No folder configs apply; models use defaults (view) and the target schema. 3.2: Default -> `dev_alice_silver`; override -> `dev_alice_silver` in dev (if implemented that way) and `silver` in prod. 3.3: View -> `CREATE VIEW`; table -> `CREATE TABLE AS`; incremental first run -> table, later runs -> merge/insert. 3.4: Look for `__dbt__cte__int_order_totals`; drawbacks: can't query/test directly, bloats downstream SQL. 3.5: Use the JSON output and follow `depends_on`.

## 3.14 Interview check

- Why does dbt discourage `select *` in marts?
- What is the difference between a source and a staging model?
- How do folder configs and model configs interact?
- When would you use ephemeral? What are the risks?
- How does dbt decide the order of execution?
- What is the difference between `dbt run` and `dbt build`?
- How do you change the schema of a single model?

# 4. Building a Layered Project: staging, intermediate, marts

## 4.1 The layered architecture

A scalable dbt project separates concerns:

| Layer | Prefix | Responsibility | Materialization |
|---|---|---|---|
| Staging | `stg_` | One source table per model; rename, cast, deduplicate, basic cleaning | View |
| Intermediate | `int_` | Joins, business logic, reusable transformations; not usually exposed to BI | View or ephemeral |
| Marts | `fct_`, `dim_`, `rpt_` | Facts, dimensions, wide tables for consumption | Table/incremental/MV |
| Utilities | `util_` | Date spines, mappings, helper models | View/table |

Rules of thumb:

- Staging models reference sources only.
- Intermediate models reference staging/intermediate only.
- Marts reference intermediate/staging and are the only layer BI should query.
- Each layer should be understandable without reading the layer below in detail.

## 4.2 Naming conventions

| Object | Convention | Example |
|---|---|---|
| Staging model | `stg_<source>__<entity>` (double underscore optional) | `stg_shopify__orders` |
| Intermediate | `int_<entity>_<verb>` | `int_orders_pivoted` |
| Fact | `fct_<process>` | `fct_orders` |
| Dimension | `dim_<entity>` | `dim_customers` |
| Report | `rpt_<audience>_<grain>` | `rpt_finance_daily` |
| Primary key | `<entity>_id` | `order_id` |
| Foreign key | `<referenced_entity>_id` | `customer_id` |
| Boolean | `is_` / `has_` | `is_refunded` |
| Timestamp | `_at` | `created_at` |
| Date | `_date` | `order_date` |
| Amount | `_amount` / `_total` | `order_total` |
| Count | `_count` | `item_count` |

Consistency beats cleverness. Document the convention in your README and enforce it in review.

## 4.3 The example domain

We will model a simplified payments/retail business:

- `orders_raw`: order header (TPCH `orders`).
- `customer_raw`: customer (TPCH `customer`).
- `lineitem_raw`: order lines (TPCH `lineitem`).
- A seed `payment_methods.csv` mapping codes to names.
- A seed `refunds.csv` with refund events.

Business questions:

1. Revenue by day, customer, and payment method.
2. Order count, average order value, refund rate.
3. Customer lifetime value and first/last order dates.
4. Which orders are late or high-risk?

## 4.4 Staging models

### `stg_orders`

```sql
{{ config(materialized='view') }}

with source as (
    select * from {{ source('bronze', 'orders_raw') }}
),

renamed as (
    select
        o_orderkey::bigint            as order_id,
        o_custkey::bigint             as customer_id,
        o_orderstatus::string         as order_status,
        o_totalprice::decimal(18,2)   as order_total,
        o_orderdate::date             as order_date,
        o_orderpriority::string       as order_priority,
        o_clerk::string               as clerk,
        o_comment::string             as comment
    from source
)

select * from renamed
```

### `stg_customers`

```sql
{{ config(materialized='view') }}

with source as (
    select * from {{ source('bronze', 'customer_raw') }}
),

renamed as (
    select
        c_custkey::bigint       as customer_id,
        c_name::string          as customer_name,
        c_address::string       as address,
        c_nationkey::bigint     as nation_id,
        c_phone::string         as phone,
        c_acctbal::decimal(18,2) as account_balance,
        c_mktsegment::string    as market_segment,
        c_comment::string       as comment
    from source
)

select * from renamed
```

### `stg_lineitems`

```sql
{{ config(materialized='view') }}

with source as (
    select * from {{ source('bronze', 'lineitem_raw') }}
),

renamed as (
    select
        l_orderkey::bigint       as order_id,
        l_partkey::bigint        as part_id,
        l_suppkey::bigint        as supplier_id,
        l_linenumber::int        as line_number,
        l_quantity::decimal(18,2) as quantity,
        l_extendedprice::decimal(18,2) as extended_price,
        l_discount::decimal(18,4) as discount,
        l_tax::decimal(18,4)     as tax,
        l_returnflag::string     as return_flag,
        l_linestatus::string     as line_status,
        l_shipdate::date         as ship_date,
        l_commitdate::date       as commit_date,
        l_receiptdate::date      as receipt_date,
        l_shipinstruct::string   as ship_instruction,
        l_shipmode::string       as ship_mode
    from source
)

select * from renamed
```

### Deduplication pattern

If a source can contain duplicate keys, deduplicate explicitly:

```sql
with source as (
    select * from {{ source('bronze', 'orders_raw') }}
),

deduped as (
    select *
    from source
    qualify row_number() over (
        partition by o_orderkey
        order by _ingested_at desc
    ) = 1
)

select * from deduped
```

`QUALIFY` is supported by Databricks SQL. Always document which record wins and why.

## 4.5 Intermediate models

### `int_orders_enriched`

```sql
{{ config(materialized='view') }}

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

payments as (
    select * from {{ ref('seed_payment_methods') }}
)

select
    o.order_id,
    o.customer_id,
    c.customer_name,
    c.market_segment,
    o.order_date,
    o.order_status,
    o.order_priority,
    o.order_total,
    p.payment_method_name,
    p.is_refundable
from orders o
left join customers c on o.customer_id = c.customer_id
left join payments p on o.order_priority = p.payment_method_code
```

This is a learning example; mapping payment method to order priority is not realistic. In a real project you would join a payment table. The point is the pattern: one intermediate model per business concept, with clear joins.

### `int_order_line_totals`

```sql
{{ config(materialized='view') }}

with lineitems as (
    select * from {{ ref('stg_lineitems') }}
)

select
    order_id,
    count(*)                                   as line_count,
    sum(quantity)                              as total_quantity,
    sum(extended_price * (1 - discount))       as net_line_revenue,
    sum(extended_price * (1 - discount) * (1 + tax)) as gross_line_revenue
from lineitems
group by order_id
```

## 4.6 Mart models

### `fct_orders` (incremental)

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge',
    on_schema_change='sync_all_columns',
    tags=['marts', 'finance']
) }}

with orders as (
    select * from {{ ref('int_orders_enriched') }}
),

line_totals as (
    select * from {{ ref('int_order_line_totals') }}
),

joined as (
    select
        o.order_id,
        o.customer_id,
        o.order_date,
        o.order_status,
        o.order_priority,
        o.order_total,
        o.payment_method_name,
        o.is_refundable,
        coalesce(l.line_count, 0)             as line_count,
        coalesce(l.total_quantity, 0)         as total_quantity,
        coalesce(l.net_line_revenue, 0)       as net_line_revenue,
        coalesce(l.gross_line_revenue, 0)     as gross_line_revenue
    from orders o
    left join line_totals l on o.order_id = l.order_id
)

select * from joined

{% if is_incremental() %}
where order_date >= (
    select coalesce(max(order_date), '1900-01-01') from {{ this }}
)
{% endif %}
```

Notes:

- The `is_incremental()` block only applies after the first run.
- `merge` with `unique_key` upserts changed orders.
- The lookback here is "same or newer date"; Chapter 9 discusses late-arriving data and lookbacks.
- `on_schema_change` handles new columns in development; choose deliberately in production.

### `dim_customers`

```sql
{{ config(materialized='table', tags=['marts', 'customer']) }}

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select
        customer_id,
        min(order_date) as first_order_date,
        max(order_date) as most_recent_order_date,
        count(*)        as number_of_orders,
        sum(order_total) as lifetime_value
    from {{ ref('fct_orders') }}
    group by customer_id
)

select
    c.customer_id,
    c.customer_name,
    c.market_segment,
    c.account_balance,
    coalesce(o.first_order_date, null)       as first_order_date,
    coalesce(o.most_recent_order_date, null) as most_recent_order_date,
    coalesce(o.number_of_orders, 0)          as number_of_orders,
    coalesce(o.lifetime_value, 0)            as lifetime_value
from customers c
left join orders o on c.customer_id = o.customer_id
```

### `rpt_revenue_daily`

```sql
{{ config(materialized='table', tags=['marts', 'finance']) }}

select
    order_date,
    count(*)                         as order_count,
    count(distinct customer_id)      as customer_count,
    sum(order_total)                 as revenue,
    avg(order_total)                 as average_order_value,
    sum(case when order_status = 'F' then order_total else 0 end) as fulfilled_revenue
from {{ ref('fct_orders') }}
group by order_date
order by order_date
```

## 4.7 The YAML layer

`models/marts/_marts.yml`:

```yaml
version: 2

models:
  - name: fct_orders
    description: "Order-level fact with customer and line-item metrics."
    config:
      materialized: incremental
      unique_key: order_id
    columns:
      - name: order_id
        description: "Primary key."
        data_tests: [unique, not_null]
      - name: customer_id
        description: "FK to dim_customers."
        data_tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_id
      - name: order_total
        description: "Order total in USD."
        data_tests:
          - not_null
      - name: order_date
        data_tests: [not_null]

  - name: dim_customers
    description: "Customer dimension with lifetime metrics."
    columns:
      - name: customer_id
        data_tests: [unique, not_null]
```

Run:

```powershell
dbt build --select staging intermediate marts
```

Or, in production:

```powershell
dbt build --select +fct_orders +dim_customers +rpt_revenue_daily
```

## 4.8 Modeling best practices

1. **One purpose per model.** If the description needs "and", consider splitting.
2. **Explicit columns in marts.** Avoid `select *`; it breaks contracts and hides schema changes.
3. **Cast at the boundary.** Staging is where types become explicit.
4. **Deduplicate once.** Do not repeat `qualify` logic in five models.
5. **No business logic in staging.** Staging is mechanical.
6. **Name booleans as questions.** `is_active`, `has_refund`.
7. **Use consistent grains.** State the grain in the model description: "one row per order."
8. **Keep joins narrow.** Join on keys, then select only needed columns.
9. **Test keys and relationships.** At minimum: unique + not_null on PKs, relationships on FKs.
10. **Document assumptions.** A future engineer will thank you.

## 4.9 Common modeling anti-patterns

| Anti-pattern | Why it hurts | Better |
|---|---|---|
| `select *` in marts | Schema drift, wasted columns, broken contracts | Explicit column list |
| Giant 800-line model | Untestable, slow to iterate | Break into intermediate models |
| Business logic in staging | Mixes cleaning and semantics | Keep staging mechanical |
| Direct `source()` in marts | Bypasses staging contract | Reference staging only |
| Using `ref()` for a seed as if it were raw | Seeds are versioned data, not ingestion | Use seeds for small mappings only |
| Circular references | dbt cannot build a DAG | Extract shared logic |
| Duplicate logic in multiple models | Inconsistent metrics | Macro or intermediate model |
| No primary key tests | Silent duplicates | Test uniqueness |
| One schema for everything | Hard to govern and grant | Layer schemas |

## 4.10 Exercises

**Exercise 4.1 - Build the layer.** Create `stg_orders`, `stg_customers`, `stg_lineitems`, `int_orders_enriched`, `int_order_line_totals`, `fct_orders`, `dim_customers`, and `rpt_revenue_daily`. Run `dbt build` and confirm all tests pass.

**Exercise 4.2 - Grain.** Write the grain statement for each mart model in one sentence. Add it to the YAML description.

**Exercise 4.3 - Dedup.** Add a duplicate row to `orders_raw` (same `o_orderkey`, newer `_ingested_at`) and rerun staging. Prove that the staging model returns one row. What happens to the incremental fact table?

**Exercise 4.4 - Refactor.** Move the payment-method join out of `int_orders_enriched` into a dedicated `int_orders_payment_methods` model. Why might this be better or worse?

**Exercise 4.5 - Test.** Add `relationships` tests from `fct_orders.customer_id` to `dim_customers.customer_id` and from `stg_lineitems.order_id` to `stg_orders.order_id`. Run tests.

**Exercise 4.6 - Query.** Write a query against `rpt_revenue_daily` for the last 30 days: revenue, orders, AOV, and a 7-day moving average.

**Answers.** 4.3: The fact table merges on `order_id`, so the deduplicated staging row replaces the target row; without a lookback, an older order date may not be reselected. 4.4: Dedicated intermediate models improve testability and reuse, but add nodes and storage if materialized; use views. 4.6: Use a window function: `avg(revenue) over (order by order_date rows between 6 preceding and current row)`.

## 4.11 Interview check

- What belongs in staging versus marts?
- How do you decide the grain of a fact table?
- Why avoid `select *` in a mart?
- How would you model a many-to-many relationship?
- What is a degenerate dimension?
- How do you handle late-arriving dimensions?
- Where do you put business logic that is reused by three marts?

# PART III - REUSABILITY

# 5. Jinja and Macros

## 5.1 Why Jinja

Jinja is a templating language that turns SQL into a program. In dbt it enables:

- Dynamic relation names via `ref()`/`source()`.
- Conditional SQL (`is_incremental()`).
- Loops over columns, dates, or lists.
- Reusable macros for logic that must be identical everywhere.
- Environment-specific behavior (`target.name`).

The goal is not clever code. The goal is **one definition of a business rule**, with SQL that remains readable.

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

Jinja delimiters:

| Syntax | Purpose |
|---|---|
| `{{ ... }}` | Output an expression |
| `{% ... %}` | Statement (if, for, set, macro) |
| `{# ... #}` | Comment |
| `{%- ... -%}` | Whitespace control |

Whitespace control matters when generating SQL. `{%-` strips whitespace before the tag; `-%}` strips after.

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

## 5.4 Filters and tests

Jinja filters transform values:

```jinja
{{ 'orders' | upper }}                 -- ORDERS
{{ ['a','b'] | join(', ') }}           -- a, b
{{ 3.14159 | round(2) }}               -- 3.14
{{ none | default('unknown') }}        -- unknown
{{ model.name | replace('stg_', '') }} -- orders
```

dbt adds filters such as `as_text`, `as_number`, `as_bool`, `as_native`, `fromjson`, `tojson`, `zip`, and `split`.

Tests (using `is`):

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
| `dbt_utils` | Only if the package is installed |

A useful pattern: guard introspection during parsing.

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

Macros can return SQL, values, or both. Use `{%- ... -%}` to keep generated SQL tidy.

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

## 5.7 A library of practical macros

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

Better: use `dbt_utils.generate_surrogate_key`, which handles nulls and types consistently.

### Cents to dollars

See 5.6.

### Grant access after build

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
{% macro date_spine(start_date, end_date, datepart='day') -%}
    select explode(sequence(
        to_date('{{ start_date }}'),
        to_date('{{ end_date }}'),
        interval 1 {{ datepart }}
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

In practice, use `dbt_utils.union_relations` so schemas are aligned by column name.

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
- `run_query` inside a model is usually a smell; prefer a variable or a model.
- Use it for metadata, grants, dynamic SQL, and operations.

`{% call statement(...) %}` is for executing side-effecting SQL:

```jinja
{% call statement('grant', fetch_result=false) %}
    grant select on {{ this }} to role analyst;
{% endcall %}
```

## 5.9 `adapter.dispatch`: cross-platform macros

If your project runs on multiple adapters (for example Databricks and Snowflake), dispatch lets each adapter provide its own implementation:

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

## 5.10 Macros in packages and namespacing

Call a package macro with its namespace:

```sql
{{ dbt_utils.generate_surrogate_key(['order_id']) }}
{{ dbt.dateadd('day', -7, 'current_date') }}
```

You can override a package macro by defining a macro with the same name in your project (for `dbt_utils`, this is discouraged; prefer wrapping).

## 5.11 Debugging Jinja

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
- Using `ref()` inside a macro that runs at parse time when `execute` is false.
- Quoting: `'{{ var("x") }}'` vs `{{ var("x") }}`.
- Trailing commas after a loop.
- Case sensitivity in `target.name` comparisons.

## 5.12 Exercises

**Exercise 5.1 - Cents.** Write `cents_to_dollars(column, scale=2)` and use it in `stg_payments` to convert an integer cents column to decimal dollars.

**Exercise 5.2 - Pivot.** Write a macro that pivots payment methods into columns. Use a list variable and a loop. Compile the model and inspect the SQL.

**Exercise 5.3 - Safe divide.** Write `safe_divide(numerator, denominator)` that returns `null` when the denominator is zero. Test it in a model with a zero denominator.

**Exercise 5.4 - Date spine.** Generate one row per day from 2024-01-01 to 2024-12-31 using a macro or `dbt_utils.date_spine`. Use it to fill missing dates in revenue.

**Exercise 5.5 - Dispatch.** Write a `date_add` macro that dispatches to `databricks__date_add` and `default__date_add`. Call it with `dbt run-operation` or in a model.

**Exercise 5.6 - Debug.** A macro produces SQL with a trailing comma before `from`. Diagnose using `{%-` whitespace control and `loop.last`.

**Answers.** 5.1: `({{ column_name }} / 100.0)::decimal(18, {{ scale }})`. 5.2: Build the `case` expressions in a loop and join with commas. 5.3: Use `nullif(denominator, 0)` or an `if`. 5.4: `dbt_utils.date_spine(datepart='day', start_date='2024-01-01', end_date='2025-01-01')`. 5.5: `adapter.dispatch('date_add', 'dbt_dbx')`. 5.6: Strip whitespace before the comma and only emit it when `not loop.last`.

## 5.13 Interview check

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
| `get_relations_by_pattern` | Introspect relations | Useful for dynamic staging |
| `deduplicate` | Deduplicate by key | `{{ dbt_utils.deduplicate(relation=ref('x'), partition_by='id', order_by='updated_at desc') }}` |
| `not_null_where` / `expression_is_true` | Generic tests | Data quality |

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

Useful tests: value ranges, row counts, column pair consistency, regex matches, freshness, quantiles, null proportions, uniqueness within a group.

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

Review the failures as a backlog, not a blocker for every PR.

## 6.8 Elementary: observability

Elementary is an observability package/platform that collects dbt artifacts, test results, run times, and data quality metrics into dashboards. It can alert on failures and anomalies. The open-source package works locally; the platform adds hosted dashboards and alerting.

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
| `dbt-labs/dbt_semantic_layer` (legacy) | Pre-1.6 metrics (superseded) |
| `Fivetran` source/transform packages | Prebuilt staging models for SaaS sources |

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

**Answers.** 6.2: The compiled SQL lists every column except `comment`. 6.3: Use the package-qualified test names. 6.4: Codegen produces descriptions like "The column `x`"; replace them. 6.5: The audit output shows rows only in A, only in B, and differing rows.

## 6.12 Interview check

- How do you install and pin a dbt package?
- What are the risks of third-party packages?
- When would you write a macro instead of using a package?
- How does `dbt_utils.star` interact with contracts?
- How do you audit a refactor?
- What does `dbt_project_evaluator` test?

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

You can also configure `warn_if` and `error_if` thresholds for custom tests:

```yaml
data_tests:
  - dbt_utils.expression_is_true:
      expression: "order_total >= 0"
      config:
        severity: warn
```

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
- In dbt v2, `dbt build` runs all unit tests first; local execution with DuckDB is experimental.

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
        filter: "order_date >= current_date - interval 7 days"
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
| No ownership | Failures have no owner | Tag tests/models with a team |

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
