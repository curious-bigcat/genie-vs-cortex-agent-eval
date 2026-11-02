# Genie vs Cortex: Supply Chain Risk Agent Comparison

A reproducible, side-by-side test of a **Databricks Agent Bricks agent** (with a Genie Agent as its data tool) and a **Snowflake Cortex Agent**, on one use case:

> *"A major supplier missed delivery dates. Determine the financial exposure, check the contract breach terms, and estimate the penalty we can claim."*

Both agents use **Claude Opus 5.5**, the same data and contracts, the same 31 questions, auto-generated semantic layers and **no instructions**.

![Architecture: Snowflake Cortex Agent vs Databricks Agent Bricks](docs/architecture.png)

## Why this project

Databricks changed its agent products within months of launching them:

| Product | Launched | Change |
|---|---|---|
| Supervisor Agent | GA February 2026 | Moved to **legacy** in the October 2026 release notes |
| Knowledge Assistant | 2025–2026 | Moved to **legacy** in the October 2026 release notes |
| Supervisor API | Beta April 2026 | **End of life** September 30, 2026 |

For new agents, Databricks now recommends writing your own agent loop and deploying it with the **Agent Bricks CLI**. Customers who built on the declarative products have to migrate to a code-first project they own and maintain.

This project tests that recommended path against Snowflake Cortex Agent on the same use case, and documents what it takes and where it falls short.

Sources: [Databricks October 2026 release notes](https://docs.databricks.com/gcp/en/release-notes/product/2026/october), [Supervisor API (deprecated)](https://docs.databricks.com/aws/en/agents/agent-bricks/supervisor-api).

## Results

| | Snowflake Cortex Agent | Databricks Agent Bricks |
|---|---|---|
| Correct / partial / wrong (3 runs × 31 questions) | **75** / 16 / **2** | 71 / 12 / 10 |
| Fully correct | **81%** | 76% |
| Questions answered wrong in any run | **2** | 6 |
| Median latency per run | **23–31 s** | 65–81 s |
| Ownership score (1–5) | **4.4** | 2.4 |
| Build effort score (1–5) | **4.5** | 2.0 |
| Code to maintain | **None** | Agent project + notebook |

> **Read next:** [`eval/observations.md`](eval/observations.md) covers the Databricks Genie and Agent Bricks shortcomings found in these runs: silent metric-view errors, Opus 5.5 breaking the template, about 7 setup surfaces, slow workarounds. It also lists where each platform did well.
> Full per-question scores: [`eval/scorecard.md`](eval/scorecard.md).

## Repo layout
```
data/output/            shared dataset: 6 CSVs, 14 contract PDFs (use as-is)
setup/snowflake/        01_db_and_data.sql, 02_cortex_search.sql
setup/databricks/       databricks_setup.ipynb
eval/questions.md       31 questions with expected answers
eval/scorecard.md       scores from the reference run
eval/observations.md    Databricks shortcomings and other findings
docs/architecture.png   architecture and results diagram
```

## What's being tested

| | Snowflake | Databricks |
|---|---|---|
| Agent | Cortex Agent (CoWork + REST) | Agent Bricks CLI agent on Agent Runtime |
| Data tool | Cortex Analyst on a **Semantic View Autopilot** semantic view | Genie Agent on a **Genie-generated** metric view |
| Contract tool | Cortex Search | UC function over a Vector Search index |
| Model | `claude-opus-5-5` | `system.ai.claude-opus-5-5` |

**Rules:** no hand-built semantic layer, and no business definitions, instructions, SQL examples or synonyms. Each platform gets only this description: *"Supply chain performance for Contoso Manufacturing in 2025: suppliers, plants, components, purchase orders, daily inventory and downtime events."* Record any manual fix you make.

**Seeded traps** in the data:

| Trap | Correct behaviour |
|---|---|
| `is_late` flag is unreliable | Late = more than the contract's grace days after the promised date |
| Region on both plant and supplier | Use plant region |
| Planned vs unplanned downtime | Count unplanned only |
| Look-alike suppliers (ACME SUPPLIES / ACME SUPPLY CO, NORTHWIND / NORTHWINDS) | Pick the right one, or ask |
| Flat inventory for C-12 and C-25 | Say there's no trend |
| Amendments for SUP-101 and SUP-104 | The amendment overrides the original |
| Force majeure for SUP-105 (March 2025) | Exclude it from the penalty |

## Quick start

| Step | Snowflake (about 3 surfaces) | Databricks (about 7 surfaces) |
|---|---|---|
| 1 | Run `01_db_and_data.sql` | Run notebook sections 0–1 (tables) |
| 2 | Semantic View Autopilot (UI) | Metric view with Genie Code (UI) |
| 3 | Run `02_cortex_search.sql` | Notebook section 3 (parse, chunk, Vector Search, UC function) |
| 4 | Create the agent (UI) | Genie Agent (UI) |
| 5 | | Agent Bricks CLI: install, init, add tools, edit model, deploy, grants |
| 6 | Run the questions | Run the questions |

Your values, used below:

| Placeholder | Meaning |
|---|---|
| `<REPO_PATH>` | Absolute path to this repo |
| `<your_catalog>` | Unity Catalog catalog you can create objects in |
| `<WORKSPACE_URL>` | Databricks workspace root URL, for example `https://adb-123.4.azuredatabricks.net` |
| `<PROFILE>` | Databricks CLI profile name |
| `<GENIE_AGENT_ID>` | Your Genie Agent's ID, from its URL `.../genie/spaces/<GENIE_AGENT_ID>` |

## Setup: Snowflake
Run as ACCOUNTADMIN in Snowsight.

1. **Data:** in `setup/snowflake/01_db_and_data.sql`, uncomment `PUT` and set `<REPO_PATH>`, or upload `data/output/csv/*.csv` to `@RAW.DATA_STAGE`. Then run the script. Row counts should be 12 / 5 / 40 / 3000 / 18250 / 150.
2. **Semantic View Autopilot:**
   - Snowsight → **Workspaces** → **Add new** → **Semantic View**.
   - Location and name: `SUPPLY_CHAIN_EVAL.ANALYTICS.SV_SUPPLY_CHAIN`.
   - Description: the text above.
   - Tables: all six in `RAW`, with every column selected and sample values and AI descriptions turned on.
   - **Create and save**, then **Save and run**. **Apply all** the suggestions and make no other edits.
3. **Contracts:** `PUT` `data/output/contracts/*.pdf` to `@DOCS.CONTRACTS_STAGE`, then run `02_cortex_search.sql`. You should get 14 documents.
4. **Agent:** **AI & ML** → **Agents** → **Create agent**.
   - Name: `SUPPLY_CHAIN_EVAL.ANALYTICS.SC_RISK_AGENT`.
   - Orchestration model: `claude-opus-5-5`. If it isn't listed, run `ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';`.
   - Leave both instruction fields **empty**.
   - Tool **Cortex Analyst:** semantic view `SV_SUPPLY_CHAIN`, warehouse `SC_EVAL_WH`, name `supply_chain_data`, description from **Generate with Cortex**.
   - Tool **Cortex Search:** service `DOCS.CONTRACTS_SEARCH`, ID column `RELATIVE_PATH`, title column `DOC_NAME`, max 5 results, name `contract_search`. Description: *Supplier Master Supply Agreements (MSA) and amendments. Use for grace period, liquidated damages %, liability cap, force majeure and termination terms. Filter by SUPPLIER_ID (e.g. SUP-101) when known. Not for numbers from data.*
   - Save, then add the agent to Snowflake Intelligence (CoWork).

## Setup: Databricks

**Notebook:** import `setup/databricks/databricks_setup.ipynb` and attach serverless compute. Set `CATALOG` in section 0, then run it top to bottom.

| Section | What you do | Done when |
|---|---|---|
| 0–1 | Upload `data/output/csv/` and `contracts/` to the volume, then load the tables | Row counts 12 / 5 / 40 / 3000 / 18250 / 150 |
| 2 **[UI]** | Catalog Explorer → Create → **Metric view** → Genie Code; paste the prompt; save as-is | `mv_supply_chain` exists |
| 3 | Parse, chunk, Vector Search index, `search_contracts` UC function | SUP-101 amendment ranks in the top 3 |
| 4 **[UI]** | Create Genie Agent `SC Risk Analyst (eval)` with no instructions | Note its `<GENIE_AGENT_ID>` |

**Agent Bricks agent** (terminal on your laptop; Python 3.12):
```bash
# install and sign in (one time)
curl -LsSf https://astral.sh/uv/install.sh | sh && source $HOME/.local/bin/env
curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sudo sh
uv tool install --python 3.12 databricks-agentbricks
databricks auth login --host "<WORKSPACE_URL>" --profile <PROFILE>
agentbricks login --profile <PROFILE>

# scaffold and add the two tools
agentbricks init sc-risk-agent --framework openai && cd sc-risk-agent
agentbricks tools add genie-agent <GENIE_AGENT_ID> --name supply_chain_data
agentbricks tools add uc-function <your_catalog>.supply_chain_eval.search_contracts --name contract_search --auth app
```

Edit `agent/agent.py`; these are the only two code changes:
```python
MODEL = resolve_model_service() or "system.ai.claude-opus-5-5"   # was claude-sonnet-4-5
set_default_openai_api("responses")                              # in configure(); was "chat_completions"
```
The Responses API is required for Opus 5.5. With `chat_completions`, its reasoning blocks fail to parse (`ResponseTextDeltaEvent.delta – Input should be a valid string`).

```bash
agentbricks doctor . && agentbricks deploy    # prints the app URL
```

- **Manual grants:** under **Compute → Apps**, give the app's service principal `USE CATALOG`, `USE SCHEMA` and `SELECT` on `<your_catalog>.supply_chain_eval`, plus `SELECT` on `contract_chunks_idx`.
- **If deploy fails:** check `agentbricks deployments logs agent-bricks-sc-risk-agent`.

## Run the evaluation
1. Ask the questions in [`eval/questions.md`](eval/questions.md) in order, in **one chat session per agent**: CoWork for Snowflake, the app's chat UI for Databricks.
2. Score each answer:

   | Column | Scale |
   |---|---|
   | Correct | **Y** = matches expected (±0.5% for money), **P** = partly right, **N** = wrong |
   | Grounded | 1–5: 5 = every number traces to SQL, results or a cited clause |
   | Relevant | 1–5 |
   | Tool calls and latency | From the traces (see below) |


**Tool calls and latency per question**

- **Snowflake:** run in Snowsight. Each SQL tool call shows up as two spans, so divide SQL spans by 2.
  ```sql
  WITH e AS (SELECT * FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS(
               'SUPPLY_CHAIN_EVAL', 'ANALYTICS', 'SC_RISK_AGENT', 'CORTEX AGENT')) WHERE RECORD_TYPE = 'SPAN')
  SELECT MIN(START_TIMESTAMP) AS started,
         MAX(IFF(RECORD:name = 'AgentV2RequestResponseInfo', RECORD_ATTRIBUTES:"ai.observability.record_root.input"::STRING, NULL)) AS question,
         DATEDIFF('ms', MIN(START_TIMESTAMP), MAX(TIMESTAMP)) / 1000 AS latency_s,
         COUNT_IF(RECORD_ATTRIBUTES:"snow.ai.observability.agent.tool.id" IS NOT NULL) AS tool_spans,
         LISTAGG(DISTINCT RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.model"::STRING, ',') AS model
  FROM e GROUP BY RECORD_ATTRIBUTES:"ai.observability.record_id" ORDER BY started;
  ```
- **Databricks:** from the `sc-risk-agent` project folder, run `agentbricks tracing list`, then `agentbricks tracing get <trace_id>` for each trace's duration and tool spans.
