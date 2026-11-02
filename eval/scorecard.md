# Scorecard

Findings and Databricks shortcomings: [`observations.md`](observations.md). Architecture: [`../docs/architecture.png`](../docs/architecture.png).

Snowflake Cortex Agent (`SC_RISK_AGENT`) vs Databricks Agent Bricks, **both on Claude Opus 5.5**. Same data, documents and 31 questions; auto-generated semantic layers (Semantic View Autopilot, Genie-generated metric view); no agent instructions; same two tools on each side (structured data + contract search).

- **Snowflake:** orchestration model `auto`, which resolved to `claude-opus-5-5` (pin `claude-opus-5-5` to reproduce).
- **Databricks:** Agent Bricks template with `MODEL = "system.ai.claude-opus-5-5"` and `set_default_openai_api("responses")` (required for Opus 5.5; see README Step 3.4).
- **Run:** through the APIs (Snowflake `DATA_AGENT_RUN`, Agent Bricks `/api/invocations`), two sessions per platform (Q01–Q10, then Q11–Q31). Latency is end to end per call.

Scoring: **Correct** Y/P/N against `questions.md` (±0.5% for money) · **Grounded** 1–5 · **Relevant** 1–5 · tool calls and latency (seconds) from the traces.

## Summary
| System | Answered | Correct (Y) | Partial (P) | Wrong (N) | Accuracy | Avg grounded | Avg relevant | Median latency | Median tool calls |
|---|---|---|---|---|---|---|---|---|---|
| Snowflake Cortex Agent | 31 | 22 | 8 | **1** | 71% (Y) / 84% (Y + ½P) | 4.7 | 4.7 | **22.8** | 2 |
| Databricks Agent Bricks | 31 | **24** | 2 | 5 | **77% (Y)** / 81% (Y + ½P) | 4.6 | 4.7 | 80.9 | 2 |

| Tier | Snowflake Y/P/N | Databricks Y/P/N |
|---|---|---|
| 1. Simple lookups (Q01–Q06) | **6/0/0** | 5/0/1 |
| 2. Ambiguous metrics (Q07–Q12) | **2/3/1** | 1/1/4 |
| 3. Look-alike names (Q13–Q18) | 3/3/0 | **6/0/0** |
| 4. Analytical / no-signal (Q19–Q24) | 6/0/0 | 6/0/0 |
| 5. Data + contracts (Q25–Q31) | 6/1/0 | 6/1/0 |

**Key findings**
- Accuracy is close on the same model. Snowflake has fewer wrong answers (1 vs 5) and is about 3.5× faster.
- Snowflake's partials: it led with the `IS_LATE` flag or supplier region, then gave the correct figure as the alternative.
- Databricks' failures come from trusting Genie's metric-view measures (no grace period, lag clamped at 0). Its wins come from Opus 5.5 rejecting Genie's wrong results (the `'PO'` filter returning 0, exposure counted as all spend) and re-querying, at the cost of more tool calls and latency.

## Per-question log
| Q | System | Answer (short) | Expected | Correct | Grounded | Relevant | Tool calls | Latency | Failure | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| Q01 | Snowflake | 2,636 by delivery date; 2,645 by order date | 2,645 or 2,636 | Y | 5 | 5 | 2 | 18.8 | – | Both definitions, explained |
| Q01 | Databricks Agent Bricks | 2,636 by delivery date; 2,645 by order date | 2,645 or 2,636 | Y | 5 | 5 | 3 | 161.3 | – | Rejected Genie's 0 (metric view filter `record_type = 'PO'`), re-queried |
| Q02 | Snowflake | 234 open | 234 | Y | 5 | 5 | 1 | 13.6 | – | |
| Q02 | Databricks Agent Bricks | 234 open, with status breakdown | 234 | Y | 5 | 5 | 1 | 50.4 | – |  |
| Q03 | Snowflake | 1.36 days (219 POs); also 23.5-day lead time | 1.36 | Y | 5 | 5 | 2 | 22.1 | – | Signed lag; offered the lead-time reading |
| Q03 | Databricks Agent Bricks | Leads 23.5-day lead time; 2.3 days late (early = 0) | 1.36 | N | 3 | 3 | 1 | 52.8 | wrong_metric | Never gave the signed average (1.36); noted it would be lower |
| Q04 | Snowflake | PLT-01 Austin Assembly ~$2.10M (25 events, 315.5 h); ranking | PLT-01 | Y | 5 | 5 | 1 | 17.2 | – | |
| Q04 | Databricks Agent Bricks | PLT-01 Austin Assembly ~$2.10M (25 events) | PLT-01 | Y | 5 | 5 | 1 | 80.9 | – |  |
| Q05 | Snowflake | 5 calendar days (MSA-SUP-103) | 5 days, s.5.1 | Y | 5 | 5 | 2 | 23.5 | – | Contract search; clause quoted |
| Q05 | Databricks Agent Bricks | 5 calendar days (MSA-SUP-103 s.5.1) | 5 days, s.5.1 | Y | 5 | 5 | 2 | 50.7 | – | Section cited |
| Q06 | Snowflake | USD 120,000 per contract year; 2.5% rate | $120,000, s.8.1 | Y | 5 | 5 | 2 | 23.7 | – | Explained how the cap applies |
| Q06 | Databricks Agent Bricks | USD 120,000 per contract year (s.8.1) | $120,000, s.8.1 | Y | 5 | 5 | 2 | 31.2 | – | Section cited |
| Q07 | Snowflake | Leads with 564 (flag); also 504 (grace rule) and recommends 504 for damages | 504 or 513 | P | 4 | 4 | 1 | 25.6 | wrong_metric (led with the trap) | Gave and recommended the right figure, but the headline is the flag. Minor: "60 flagged but within grace" oversimplifies (the flag is wrong both ways) |
| Q07 | Databricks Agent Bricks | 1,394 (any lag); threshold table >3d 592 / >5d 451; 'likely 450–600' | 504 or 513 | N | 3 | 4 | 2 | 100.3 | wrong_metric | Raised the grace period but didn't apply each supplier's contract (504) |
| Q08 | Snowflake | $12.45M total; unplanned $8.50M / planned $3.94M; only unplanned counts per contract | $8,503,350 (or total + unplanned with explanation) | Y | 5 | 5 | 1 | 17.6 | – | Meets the rubric's alternative: total + unplanned + reason |
| Q08 | Databricks Agent Bricks | $12.45M total; unplanned $8.50M; only unplanned recoverable | $8,503,350 (or total + unplanned with explanation) | Y | 5 | 5 | 1 | 88.3 | – | Meets the rubric's alternative |
| Q09 | Snowflake | Headline APAC suppliers $18.86M (2025); APAC plants $7.27M (2025) + $0.11M (2026) = $7.38M | $7,381,727 (plant region) | P | 5 | 4 | 2 | 32.3 | wrong_attribution (led with supplier region) | Correct plant-region figure given; grace rule + unplanned only; all figures verified |
| Q09 | Databricks Agent Bricks | APAC suppliers $18.86M (grace rule + unplanned); plant region mentioned without a figure | $7,381,727 (plant region) | N | 4 | 4 | 7 | 158.9 | wrong_attribution (supplier region) | Correct for supplier region (trap value, 2025) |
| Q10 | Snowflake | Headline APAC suppliers 289 (flag) / 278 (grace); by plant EMEA 236 vs AMER 235 | EMEA (plant region) | P | 4 | 4 | 2 | 28.7 | wrong_attribution (led with supplier region) | Gave the plant-region answer (EMEA), but by flag; grace rule gives EMEA 214 vs AMER 202 |
| Q10 | Databricks Agent Bricks | Leads APAC suppliers (273 contract-late); by plant EMEA 208 | EMEA (plant region) | P | 4 | 4 | 3 | 111.7 | wrong_attribution (led with supplier region) | Gave the plant-region answer (EMEA) with the grace rule |
| Q11 | Snowflake | Leads 74.5% (flag); table gives 75.6% (3-day grace) | 75.64% | P | 5 | 4 | 2 | 29.5 | wrong_metric (led with the flag) | Grace-rule figure given but not chosen; flagged the 3-order mismatch |
| Q11 | Databricks Agent Bricks | 47.6% (Genie `on_time_delivery_rate`) | 75.64% | N | 3 | 3 | 2 | 59.8 | wrong_metric | Trusted Genie's measure (no grace period) |
| Q12 | Snowflake | $3,009,346 (50 orders, flag) | $2,541,813.52 | N | 3 | 4 | 2 | 16.0 | wrong_metric (IS_LATE) | No grace rule and no caveat; consistent with its Q11 choice |
| Q12 | Databricks Agent Bricks | $7,239,643 (no grace; caveated) | $2,541,813.52 | N | 3 | 3 | 2 | 61.0 | wrong_metric | Flagged the missing grace period but didn't correct it |
| Q13 | Snowflake | Both: SUP-101 $11.56M, SUP-110 $4.39M; LD + caps | SUP-101 $11,555,037; SUP-110 $4,386,445 | Y | 5 | 5 | 3 | 35.7 | – | Contract definition and amendment applied |
| Q13 | Databricks Agent Bricks | Both: SUP-101 $11.34M, SUP-110 $4.39M (2025); rejected Genie's spend figure | SUP-101 $11,555,037; SUP-110 $4,386,445 | Y | 5 | 5 | 5 | 142.9 | – | 2026 shown separately |
| Q14 | Snowflake | Leads 48 (flag); contract rule 42, recommends 42 | 42 | P | 5 | 4 | 2 | 20.3 | wrong_metric (led with the flag) | Entity correct; separated it from SUP-101 |
| Q14 | Databricks Agent Bricks | 42 (contract rule) | 42 | Y | 4 | 5 | 0 | 16.7 | – | Answered from the previous turn's data |
| Q15 | Snowflake | NORTHWINDS $3,668,150; LD capped at $110k; also NORTHWIND | $3,668,150.38 | Y | 5 | 5 | 5 | 35.8 | – | Exact |
| Q15 | Databricks Agent Bricks | NORTHWINDS $3,668,150.38 | $3,668,150.38 | Y | 5 | 5 | 3 | 98.4 | – | Exact |
| Q16 | Snowflake | Leads 47 (flag); contract 40; also gave NORTHWINDS | 40 | P | 4 | 4 | 1 | 17.5 | wrong_metric (led with the flag) | Typo resolved to SUP-102 |
| Q16 | Databricks Agent Bricks | NORTHWIND 40 (38 + 2); also NORTHWINDS 43 | 40 | Y | 5 | 5 | 3 | 70.1 | – | Typo resolved |
| Q17 | Snowflake | Leads 47,832 (flag); contract 48,104 | 48,104 units | P | 4 | 4 | 3 | 21.9 | wrong_metric (led with the flag) | Recommends the contract figure |
| Q17 | Databricks Agent Bricks | 48,104 units (179 POs) | 48,104 units | Y | 5 | 5 | 2 | 61.5 | – |  |
| Q18 | Snowflake | 2.0%, $90k cap, no amendment | 2.0% | Y | 5 | 5 | 1 | 17.8 | – |  |
| Q18 | Databricks Agent Bricks | 2.0%, $90k cap | 2.0% | Y | 5 | 5 | 1 | 24.0 | – |  |
| Q19 | Snowflake | Flat 500; flags likely placeholder | Flat | Y | 5 | 5 | 1 | 16.8 | – |  |
| Q19 | Databricks Agent Bricks | Flat 500; flags likely data problem | Flat | Y | 5 | 5 | 3 | 104.7 | – |  |
| Q20 | Snowflake | Flat 500; same default as C-12 | Flat | Y | 5 | 5 | 1 | 15.4 | – |  |
| Q20 | Databricks Agent Bricks | Flat 500 | Flat | Y | 5 | 5 | 3 | 105.3 | – |  |
| Q21 | Snowflake | 164 | 164 | Y | 5 | 5 | 1 | 15.3 | – |  |
| Q21 | Databricks Agent Bricks | 164 | 164 | Y | 5 | 5 | 2 | 65.1 | – |  |
| Q22 | Snowflake | C-29 (164); next C-05 107 | C-29 | Y | 5 | 5 | 5 | 29.8 | – |  |
| Q22 | Databricks Agent Bricks | C-29 (164) | C-29 | Y | 5 | 5 | 2 | 67.4 | – |  |
| Q23 | Snowflake | SUP-101 (52 flag / 50 grace) | SUP-101 | Y | 5 | 5 | 1 | 18.2 | – |  |
| Q23 | Databricks Agent Bricks | SUP-101 (50, contract rule) | SUP-101 | Y | 5 | 5 | 3 | 108.7 | – |  |
| Q24 | Snowflake | SUP-101 $11.56M, SUP-104 $4.46M, SUP-110 $4.39M | SUP-101, SUP-104, SUP-110 | Y | 5 | 5 | 2 | 31.2 | – |  |
| Q24 | Databricks Agent Bricks | SUP-101, SUP-104, SUP-110 (force majeure applied) | SUP-101, SUP-104, SUP-110 | Y | 5 | 5 | 5 | 129.3 | – |  |
| Q25 | Snowflake | $400,000 (amendment 8%, cap) | $400,000 | Y | 5 | 5 | 3 | 30.9 | – |  |
| Q25 | Databricks Agent Bricks | $400,000 (amendment 8%, cap) | $400,000 | Y | 4 | 5 | 0 | 28.2 | – | From earlier-turn exposure; § cited |
| Q26 | Snowflake | ~$176,300 (4% of 2025 delivered-year $4.41M) | $178,320.42 | P | 5 | 4 | 2 | 29.3 | definition (contract year) | Excluded a 2026 delivery (−1.1%, outside tolerance); amendment applied correctly |
| Q26 | Databricks Agent Bricks | ~$176,300 (2025 deliveries only) | $178,320.42 | P | 5 | 4 | 2 | 101.9 | definition (contract year) | Same choice as Snowflake (−1.1%) |
| Q27 | Snowflake | $107,710.89 (force majeure applied) | $107,710.89 | Y | 5 | 5 | 3 | 31.6 | – | Exact; caught force majeure T9 |
| Q27 | Databricks Agent Bricks | ~$107,711 (force majeure applied) | $107,710.89 | Y | 5 | 5 | 2 | 103.3 | – |  |
| Q28 | Snowflake | $110,000 (cap, $45 over) | $110,000 | Y | 5 | 5 | 4 | 32.5 | – |  |
| Q28 | Databricks Agent Bricks | $110,000 (cap) | $110,000 | Y | 5 | 5 | 1 | 105.1 | – |  |
| Q29 | Snowflake | SUP-101, SUP-111; full 12-supplier table | SUP-101, SUP-111 | Y | 5 | 5 | 5 | 48.9 | – |  |
| Q29 | Databricks Agent Bricks | SUP-101, SUP-111 | SUP-101, SUP-111 | Y | 5 | 5 | 3 | 51.2 | – |  |
| Q30 | Snowflake | ~$1.30M (~$1,299K) | $1,304,732.41 | Y | 4 | 5 | 0 | 16.3 | – | Within 0.5%; summed from rounded figures |
| Q30 | Databricks Agent Bricks | $1,299,233.62 | $1,304,732.41 | Y | 4 | 5 | 0 | 31.9 | – | Within 0.5% |
| Q31 | Snowflake | SUP-101, breach terms, $400,000 | $400,000 | Y | 5 | 5 | 1 | 22.8 | – | Plus termination check |
| Q31 | Databricks Agent Bricks | SUP-101 $11.34M; terms with § refs; $400,000; termination right (<70% every quarter) | $400,000 | Y | 5 | 5 | 1 | 104.8 | – | Went beyond the question |

## Ownership

Scale: 1 = heavy burden, 5 = light. Scores are drafts based on the facts recorded during this evaluation.

| # | Criterion | How it's measured |
|---|---|---|
| O1 | Where the business logic lives | Places a business rule (grace period, unplanned only, plant region, exposure) is defined or would need fixing |
| O2 | Places to configure | Separate tools, UIs, files and services touched to build and change the agent |
| O3 | Manual fixes | Workarounds needed to get a working agent, including setup bugs found during the evaluation |
| O4 | Model choice and change | Whether the model can be chosen, steps to change it, versioning and rollback, failures on any model |
| O5 | Observability | Tracing each answer to its SQL, tools and timing without extra setup |

| Criterion | Snowflake | Score | Databricks Agent Bricks | Score |
|---|---|---|---|---|
| O1 | Semantic view (Autopilot) + agent spec, both in Snowflake | 4 | Genie metric view + Genie Agent space + `agent.py` / `agent.toml`; a rule fix touches the metric view or code | 2 |
| O2 | 3 SQL scripts, Autopilot UI, agent UI (one platform, ~3 surfaces) | 4 | Setup notebook, metric view prompt, Genie UI, Vector Search, CLI install (uv, Databricks CLI), Agent Bricks project, deploy + app grants (~7 surfaces) | 2 |
| O3 | Chunk headers (1) | 4 | Chunk headers; CLI install fixes; template demo tools; `record_type = 'PO'` metric view filter bug (unresolved); Opus 5.5 needs a switch to the Responses API (5) | 1 |
| O4 | Change the model in the spec, then commit a version and set it as default; earlier versions kept for rollback; every model tried worked | 5 | Edit `agent.py` and redeploy (~1 min); Opus 5.5 fails with the template's `chat_completions` API until switched to `responses` (found by debugging); no versioning | 3 |
| O5 | `GET_AI_OBSERVABILITY_EVENTS`: SQL, tools and timing per answer, no setup | 5 | MLflow traces set up automatically by the CLI; Genie's internal LLM tokens not exposed | 4 |
| **Average** | | **4.4** | | **2.4** |

Still to add: time to first working answer for each platform (not tracked), and O6 Governance once Q36 has been run.

## Build effort (ease, speed, manual intervention, coding)

Scale: 1 = hard / slow / heavy, 5 = easy / fast / light. Counts are taken from the setup files and README. Wall-clock time wasn't tracked, so speed is scored on step counts and wait points.

| Fact | Snowflake | Databricks Agent Bricks |
|---|---|---|
| Code you write or run | 97 SQL lines (3 scripts) | 88 notebook code lines (Python + SQL), plus `agent.py` edits |
| Languages | SQL only | Python, SQL, shell |
| Local tooling | None (Snowsight in the browser) | Python 3.12, `uv`, Databricks CLI (sudo install), `databricks-agentbricks` |
| UI steps | Autopilot wizard (~5 clicks), agent form (~6 fields), add to CoWork | Metric view (Genie Code prompt), Genie Agent space, app service principal grants |
| CLI commands | 0 | ~12 (install, login, init, 2 × tools add, doctor, dev, deploy, invoke) |
| Generated code to own | None | Full Agent Bricks project (`agent/`, `runtime/`, `tests/`, demo tools), versioned outside the platform |
| Manual grants | None | Deploy grants the tools it declares; USE CATALOG, USE SCHEMA, SELECT and index SELECT for the app SP are by hand |
| Wait points | Autopilot suggestions (a few minutes) | Vector index sync, first deploy (a few minutes), redeploy (~50 s) per change |
| Manual fixes during evaluation | Chunk headers | Chunk headers; CLI install and host URL fix; demo tool clean-up; Opus 5.5 Responses API switch; metric view `record_type` filter bug (unresolved) |
| How a change is made | Edit the spec, then commit a version and set it as default (SQL or UI) | Edit code, then redeploy |

| Criterion | Snowflake | Score | Databricks | Score |
|---|---|---|---|---|
| B1 Ease (skills needed, number of surfaces) | SQL + Snowsight UI; one platform | 5 | Python, SQL, shell, CLI and app concepts; ~7 surfaces | 2 |
| B2 Speed to set up (steps, waits) | 3 scripts + 2 UI flows; one short wait | 4 | Notebook + 2 UI flows + CLI install + scaffold + deploy; several waits | 2 |
| B3 Manual intervention | 1 fix; no hand-wired grants for the agent | 4 | 5 fixes; hand-made app SP grants | 2 |
| B4 Coding required | No application code; SQL setup only | 5 | Python notebook + generated agent project you maintain | 2 |
| **Average** | | **4.5** | | **2.0** |
