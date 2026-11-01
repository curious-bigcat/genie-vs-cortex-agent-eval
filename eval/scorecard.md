# Scorecard (running)

Snowflake Cortex Agent (CoWork, `SC_RISK_AGENT` VERSION$2) vs Databricks Agent Bricks, **default configs**: Snowflake model `auto` (claude-opus-5-5), Agent Bricks template default claude-sonnet-4-5. Both run with no instructions and the same two tools (structured data + contract search). Each platform runs all questions in a single session. Q01–Q31 were sent through the APIs, as two sessions per platform (Q01–Q10, then Q11–Q31) (Snowflake `DATA_AGENT_RUN`, Agent Bricks `/api/invocations`); latency is measured end to end per call.

Scoring: **Correct** Y/P/N · **Grounded** 1–5 · **Relevant** 1–5 · Latency in seconds. Tool calls and latency come from the traces.

\* Avg grounded excludes runs with no answer.

## Summary
| System | Answered | Correct (Y) | Partial (P) | Wrong (N) | Accuracy | Avg grounded | Avg relevant | Median latency | Median tool calls |
|---|---|---|---|---|---|---|---|---|---|
| Snowflake Cortex Agent | 31 | 22 | 8 | 1 | 71% (Y) / 84% (Y + ½P) | 4.7 | 4.7 | 22.8 | 2 |
| Databricks Agent Bricks | 31 | 12 | 0 | 19 | 39% | 2.6 | 3.6 | 48.4 | 1 |

## Per-question log
| Q | System | Answer (short) | Expected | Correct | Grounded | Relevant | Tool calls | Latency | Failure | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| Q01 | Snowflake | 2,636 by delivery date; 2,645 by order date | 2,645 or 2,636 | Y | 5 | 5 | 2 | 18.8 | – | Both definitions, explained |
| Q01 | Databricks Agent Bricks | 0 delivered in 2025 | 2,645 or 2,636 | N | 1 | 2 | 1 | 36.7 | wrong_metric | Genie metric view filter bug (`record_type = 'PO'`, actual value 'PURCHASE_ORDER') |
| Q02 | Snowflake | 234 open | 234 | Y | 5 | 5 | 1 | 13.6 | – | |
| Q02 | Databricks Agent Bricks | 0 open | 234 | N | 1 | 2 | 1 | 47.5 | wrong_metric | Same filter bug |
| Q03 | Snowflake | 1.36 days (219 POs); also 23.5-day lead time | 1.36 | Y | 5 | 5 | 2 | 22.1 | – | Signed lag; offered the lead-time reading |
| Q03 | Databricks Agent Bricks | 2.3 days (early counted as 0) | 1.36 | N | 2 | 3 | 1 | 47.7 | wrong_metric | Lag clamped at 0; method stated |
| Q04 | Snowflake | PLT-01 Austin Assembly ~$2.10M (25 events, 315.5 h); ranking | PLT-01 | Y | 5 | 5 | 1 | 17.2 | – | |
| Q04 | Databricks Agent Bricks | PLT-01 Austin Assembly $2.10M | PLT-01 | Y | 4 | 4 | 1 | 50.4 | – | No breakdown or method |
| Q05 | Snowflake | 5 calendar days (MSA-SUP-103) | 5 days, s.5.1 | Y | 5 | 5 | 2 | 23.5 | – | Contract search; clause quoted |
| Q05 | Databricks Agent Bricks | 5 calendar days (MSA-SUP-103 s.5.1) | 5 days, s.5.1 | Y | 5 | 5 | 1 | 37.3 | – | Section cited and quoted |
| Q06 | Snowflake | USD 120,000 per contract year; 2.5% rate | $120,000, s.8.1 | Y | 5 | 5 | 2 | 23.7 | – | Explained how the cap applies |
| Q06 | Databricks Agent Bricks | USD 120,000 per contract year (s.8.1) | $120,000, s.8.1 | Y | 5 | 5 | 1 | 18.1 | – | Section cited and quoted |
| Q07 | Snowflake | Leads with 564 (flag); also 504 (grace rule) and recommends 504 for damages | 504 or 513 | P | 4 | 4 | 1 | 25.6 | wrong_metric (led with the trap) | Gave and recommended the right figure, but the headline is the flag. Minor: "60 flagged but within grace" oversimplifies (the flag is wrong both ways) |
| Q07 | Databricks Agent Bricks | 0 late; "all within grace periods" | 504 or 513 | N | 1 | 2 | 1 | 55.4 | wrong_metric + hallucinated_detail | Filter bug, then invented an explanation |
| Q08 | Snowflake | $12.45M total; unplanned $8.50M / planned $3.94M; only unplanned counts per contract | $8,503,350 (or total + unplanned with explanation) | Y | 5 | 5 | 1 | 17.6 | – | Meets the rubric's alternative: total + unplanned + reason |
| Q08 | Databricks Agent Bricks | $12.45M total | $8,503,350 | N | 2 | 3 | 1 | 49.4 | wrong_metric (planned + unplanned) | No breakdown; suggested the unplanned split as a follow-up |
| Q09 | Snowflake | Headline APAC suppliers $18.86M (2025); APAC plants $7.27M (2025) + $0.11M (2026) = $7.38M | $7,381,727 (plant region) | P | 5 | 4 | 2 | 32.3 | wrong_attribution (led with supplier region) | Correct plant-region figure given; grace rule + unplanned only; all figures verified |
| Q09 | Databricks Agent Bricks | $0 ("no unplanned downtime in APAC") | $7,381,727 | N | 1 | 2 | 1 | 49.6 | wrong_metric + hallucinated_detail | APAC plants have $1.64M unplanned downtime; ignored late deliveries |
| Q10 | Snowflake | Headline APAC suppliers 289 (flag) / 278 (grace); by plant EMEA 236 vs AMER 235 | EMEA (plant region) | P | 4 | 4 | 2 | 28.7 | wrong_attribution (led with supplier region) | Gave the plant-region answer (EMEA), but by flag; grace rule gives EMEA 214 vs AMER 202 |
| Q10 | Databricks Agent Bricks | APAC 601 (supplier region) | EMEA | N | 2 | 3 | 1 | 48.6 | wrong_metric + wrong_attribution | 601 = lag > 0 (grace ignored); offered plant region |
| Q11 | Snowflake | Leads 74.5% (flag); table gives 75.6% (3-day grace) | 75.64% | P | 5 | 4 | 2 | 29.5 | wrong_metric (led with the flag) | Grace-rule figure given but not chosen; flagged the 3-order mismatch |
| Q11 | Databricks Agent Bricks | 47.6% | 75.64% | N | 2 | 3 | 1 | 52.6 | wrong_metric | lag ≤ 0 (grace ignored); concluded 'significant performance issues' |
| Q12 | Snowflake | $3,009,346 (50 orders, flag) | $2,541,813.52 | N | 3 | 4 | 2 | 16.0 | wrong_metric (IS_LATE) | No grace rule and no caveat; consistent with its Q11 choice |
| Q12 | Databricks Agent Bricks | $7,239,643 | $2,541,813.52 | N | 2 | 3 | 1 | 47.3 | wrong_metric | Value of lag > 0 deliveries |
| Q13 | Snowflake | Both: SUP-101 $11.56M, SUP-110 $4.39M; LD + caps | SUP-101 $11,555,037; SUP-110 $4,386,445 | Y | 5 | 5 | 3 | 35.7 | – | Contract definition and amendment applied |
| Q13 | Databricks Agent Bricks | Both Acmes, but PO spend $29.39M / $13.48M + downtime | SUP-101 $11.56M; SUP-110 $4.39M | N | 2 | 3 | 1 | 48.4 | wrong_metric | Found both entities; exposure = all spend |
| Q14 | Snowflake | Leads 48 (flag); contract rule 42, recommends 42 | 42 | P | 5 | 4 | 2 | 20.3 | wrong_metric (led with the flag) | Entity correct; separated it from SUP-101 |
| Q14 | Databricks Agent Bricks | 114 | 42 | N | 2 | 3 | 1 | 47.8 | wrong_metric | lag > 0 |
| Q15 | Snowflake | NORTHWINDS $3,668,150; LD capped at $110k; also NORTHWIND | $3,668,150.38 | Y | 5 | 5 | 5 | 35.8 | – | Exact |
| Q15 | Databricks Agent Bricks | $11.82M spend + $657K downtime | $3,668,150.38 | N | 2 | 3 | 1 | 50.2 | wrong_metric | Breach count 43 correct, but exposure = spend |
| Q16 | Snowflake | Leads 47 (flag); contract 40; also gave NORTHWINDS | 40 | P | 4 | 4 | 1 | 17.5 | wrong_metric (led with the flag) | Typo resolved to SUP-102 |
| Q16 | Databricks Agent Bricks | 90 | 40 | N | 2 | 3 | 1 | 47.6 | wrong_metric | lag > 0; noted the look-alike name |
| Q17 | Snowflake | Leads 47,832 (flag); contract 48,104 | 48,104 units | P | 4 | 4 | 3 | 21.9 | wrong_metric (led with the flag) | Recommends the contract figure |
| Q17 | Databricks Agent Bricks | 78,521 units | 48,104 units | N | 2 | 3 | 1 | 47.2 | wrong_metric | lag > 0 |
| Q18 | Snowflake | 2.0%, $90k cap, no amendment | 2.0% | Y | 5 | 5 | 1 | 17.8 | – |  |
| Q18 | Databricks Agent Bricks | 2.0% (MSA-SUP-110), $90k cap | 2.0% | Y | 4 | 5 | 1 | 37.8 | – | Mislabelled the force majeure notice as a 'grace period' |
| Q19 | Snowflake | Flat 500; flags likely placeholder | Flat | Y | 5 | 5 | 1 | 16.8 | – |  |
| Q19 | Databricks Agent Bricks | Flat 500; 'well-managed' | Flat | Y | 4 | 4 | 1 | 49.2 | – | No data-quality caveat |
| Q20 | Snowflake | Flat 500; same default as C-12 | Flat | Y | 5 | 5 | 1 | 15.4 | – |  |
| Q20 | Databricks Agent Bricks | Flat 500 | Flat | Y | 4 | 4 | 1 | 47.2 | – |  |
| Q21 | Snowflake | 164 | 164 | Y | 5 | 5 | 1 | 15.3 | – |  |
| Q21 | Databricks Agent Bricks | 164 | 164 | Y | 5 | 5 | 1 | 33.1 | – |  |
| Q22 | Snowflake | C-29 (164); next C-05 107 | C-29 | Y | 5 | 5 | 5 | 29.8 | – |  |
| Q22 | Databricks Agent Bricks | Fasteners Part 29 (C-29), 164 | C-29 | Y | 5 | 5 | 1 | 53.0 | – |  |
| Q23 | Snowflake | SUP-101 (52 flag / 50 grace) | SUP-101 | Y | 5 | 5 | 1 | 18.2 | – |  |
| Q23 | Databricks Agent Bricks | SUP-101 (82, lag > 0) | SUP-101 | Y | 3 | 5 | 1 | 49.2 | – | Right supplier, wrong count definition |
| Q24 | Snowflake | SUP-101 $11.56M, SUP-104 $4.46M, SUP-110 $4.39M | SUP-101, SUP-104, SUP-110 | Y | 5 | 5 | 2 | 31.2 | – |  |
| Q24 | Databricks Agent Bricks | SUP-110, SUP-105, 'NORTHWIND (SUP-108)' by downtime only | SUP-101, SUP-104, SUP-110 | N | 1 | 3 | 1 | 52.2 | wrong_metric + wrong_entity | Downtime only; SUP-108 is SOYLENT |
| Q25 | Snowflake | $400,000 (amendment 8%, cap) | $400,000 | Y | 5 | 5 | 3 | 30.9 | – |  |
| Q25 | Databricks Agent Bricks | $400,000 (amendment, cap) on $29.89M 'exposure' | $400,000 | Y | 3 | 5 | 2 | 54.2 | – | Right answer because the cap binds; exposure = spend |
| Q26 | Snowflake | ~$176,300 (4% of 2025 delivered-year $4.41M) | $178,320.42 | P | 5 | 4 | 2 | 29.3 | definition (contract year) | Excluded a 2026 delivery (−1.1%, outside tolerance); amendment applied correctly |
| Q26 | Databricks Agent Bricks | $180,000 (cap) | $178,320.42 | N | 2 | 4 | 3 | 90.9 | wrong_metric | Spend-based exposure inflates it past the cap |
| Q27 | Snowflake | $107,710.89 (force majeure applied) | $107,710.89 | Y | 5 | 5 | 3 | 31.6 | – | Exact; caught force majeure T9 |
| Q27 | Databricks Agent Bricks | $500,000 (cap); force majeure partly applied | $107,710.89 | N | 2 | 4 | 3 | 124.1 | wrong_metric | Spend-based exposure |
| Q28 | Snowflake | $110,000 (cap, $45 over) | $110,000 | Y | 5 | 5 | 4 | 32.5 | – |  |
| Q28 | Databricks Agent Bricks | $110,000 (cap) | $110,000 | Y | 3 | 5 | 3 | 95.2 | – | Right answer because the cap binds; exposure = spend |
| Q29 | Snowflake | SUP-101, SUP-111; full 12-supplier table | SUP-101, SUP-111 | Y | 5 | 5 | 5 | 48.9 | – |  |
| Q29 | Databricks Agent Bricks | 4 suppliers analysed so far, all capped | SUP-101, SUP-111 | N | 2 | 3 | 0 | 22.6 | wrong_metric + incomplete | No tool call; answered from memory |
| Q30 | Snowflake | ~$1.30M (~$1,299K) | $1,304,732.41 | Y | 4 | 5 | 0 | 16.3 | – | Within 0.5%; summed from rounded figures |
| Q30 | Databricks Agent Bricks | $2,355,000 (all capped) | $1,304,732.41 | N | 2 | 4 | 9 | 153.2 | wrong_metric | Spend-based exposure caps every supplier |
| Q31 | Snowflake | SUP-101, breach terms, $400,000 | $400,000 | Y | 5 | 5 | 1 | 22.8 | – | Plus termination check |
| Q31 | Databricks Agent Bricks | SUP-101, breach terms, $400,000 | $400,000 | Y | 3 | 4 | 0 | 25.0 | – | Exposure = spend; answered from memory |

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
| O3 | Chunk headers; switching off `auto` for a like-for-like test (2) | 4 | Chunk headers; CLI install fixes; template demo tools; `record_type = 'PO'` metric view filter bug (unresolved); Opus 5.5 breaks the template (5) | 1 |
| O4 | Change the model in the spec, then commit a version and set it as default; earlier versions kept for rollback; every model tried worked | 5 | Edit `agent.py` and redeploy (~1 min); Opus 5.5 failed ~50% of calls (reasoning blocks); no versioning | 3 |
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
| Manual grants | 1 GRANT line (governance) | Deploy grants the tools it declares; USE CATALOG, USE SCHEMA, SELECT and index SELECT for the app SP are by hand |
| Wait points | Autopilot suggestions (a few minutes) | Vector index sync, first deploy (a few minutes), redeploy (~50 s) per change |
| Manual fixes during evaluation | Chunk headers | Chunk headers; CLI install and host URL fix; demo tool clean-up; Opus 5.5 incompatibility; metric view `record_type` filter bug (unresolved) |
| How a change is made | Edit the spec, then commit a version and set it as default (SQL or UI) | Edit code, then redeploy |

| Criterion | Snowflake | Score | Databricks | Score |
|---|---|---|---|---|
| B1 Ease (skills needed, number of surfaces) | SQL + Snowsight UI; one platform | 5 | Python, SQL, shell, CLI and app concepts; ~7 surfaces | 2 |
| B2 Speed to set up (steps, waits) | 3 scripts + 2 UI flows; one short wait | 4 | Notebook + 2 UI flows + CLI install + scaffold + deploy; several waits | 2 |
| B3 Manual intervention | 1 fix; no hand-wired grants for the agent | 4 | 5 fixes; hand-made app SP grants | 2 |
| B4 Coding required | No application code; SQL setup only | 5 | Python notebook + generated agent project you maintain | 2 |
| **Average** | | **4.5** | | **2.0** |

Note: the Databricks **Genie Agent** alone (Arm A, not run) skips the CLI and project. Its B1–B4 would sit between the two columns.
