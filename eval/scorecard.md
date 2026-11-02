# Scorecard

Findings and Databricks shortcomings: [`observations.md`](observations.md). Architecture: [`../docs/architecture.png`](../docs/architecture.png).

Snowflake Cortex Agent (`SC_RISK_AGENT`) vs Databricks Agent Bricks, **both on Claude Opus 5.5**. Same data, documents and 31 questions; auto-generated semantic layers (Semantic View Autopilot, Genie-generated metric view); no agent instructions; same two tools on each side (structured data + contract search).

- **Snowflake:** orchestration model `auto`, which resolved to `claude-opus-5-5` (pin `claude-opus-5-5` to reproduce).
- **Databricks:** Agent Bricks template with `MODEL = "system.ai.claude-opus-5-5"` and `set_default_openai_api("responses")` (required for Opus 5.5; see README Step 3.4).
- **Run:** through the APIs (Snowflake Cortex Agent REST `:run`, Agent Bricks `/api/invocations`). One chat session per agent; each question sent to both agents at the same moment. Latency is end to end per call.

Scoring: **Correct** Y/P/N against `questions.md` (±0.5% for money) · **Grounded** 1–5 (5 = figures match the data and contracts and sources are cited; 4 = correct figure present but not leading or slightly off; 2 = wrong figure) · **Relevant** 1–5 (5 = answers the question as asked; 4 = right answer but leads with another definition or includes noise; 3 = misses the intended reading) · tool calls from the agents' streamed tool-use events.

## Summary

| System | Answered | Correct (Y) | Partial (P) | Wrong (N) | Accuracy | Avg grounded | Avg relevant | Median latency (s) | Median tool calls |
|---|---|---|---|---|---|---|---|---|---|
| Snowflake Cortex Agent | 31 | **29** | 2 | **0** | **94% (Y) / 97% (Y + ½P)** | **4.9** | **4.9** | **31.2** | 1 |
| Databricks Agent Bricks | 31 | 24 | 5 | 2 | 77% (Y) / 85% (Y + ½P) | 4.6 | 4.7 | 65.2 | 2 |

| Tier | Snowflake Y/P/N | Databricks Y/P/N |
|---|---|---|
| 1. Simple lookups (Q01–Q06) | 6/0/0 | 6/0/0 |
| 2. Ambiguous metrics (Q07–Q12) | **5/1/0** | 3/1/2 |
| 3. Look-alike names (Q13–Q18) | **6/0/0** | 3/3/0 |
| 4. Analytical / no-signal (Q19–Q24) | 6/0/0 | 6/0/0 |
| 5. Data + contracts (Q25–Q31) | 6/1/0 | 6/1/0 |

**Key findings**
- Snowflake answered 29 of 31 fully correctly with no wrong answers, about 2× faster (median 31.2 s vs 65.2 s).
- Databricks' two wrong answers (Q09, Q10) group by supplier region and never offer the plant-region view; Snowflake gave both readings.
- Databricks' partials mostly come from filtering to 2025 deliveries or leading with "any lateness" instead of the contract grace period.
- Genie's metric view still returned 0 for purchase-order counts (`record_type = 'PO'`); the agent caught it on Q01 and re-queried the raw data, adding tool calls and latency (up to 8 tool calls on one question, against 5 for Snowflake).
- Q26 is partial on both: each filtered to deliveries dated 2025 (≈ $176,300 vs $178,320.42 expected).

## Per-question log

| Q | System | Answer (short) | Expected | Correct | Grounded | Relevant | Tool calls | Latency (s) | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Q01 | Snowflake | 2,636 purchase orders were delivered in 2025. | 2,645 (all delivered; all orders were placed in 2025) **or** 2,636 (delivery date in 2025; 9 arrived Jan 2026) | Y | 5 | 5 | 2 | 19.5 |  |
| Q01 | Databricks | 2,645 purchase orders were delivered in 2025. | 2,645 (all delivered; all orders were placed in 2025) **or** 2,636 (delivery date in 2025; 9 arrived Jan 2026) | Y | 5 | 5 | 4 | 129.6 | Rejected Genie's 0 (metric view filter `record_type = 'PO'`), re-queried |
| Q02 | Snowflake | 234 purchase orders are still open. | 234 | Y | 5 | 5 | 1 | 17.3 |  |
| Q02 | Databricks | 234 purchase orders are still open. | 234 | Y | 5 | 5 | 2 | 65.2 |  |
| Q03 | Snowflake | NORTHWIND (SUP-102) delivered an average of about 1.36 days after the promised date. | 1.36 | Y | 5 | 5 | 1 | 19.6 |  |
| Q03 | Databricks | NORTHWIND (SUP-102) delivered an average of 1.36 days late (about 1.4 days). | 1.36 | Y | 5 | 5 | 2 | 58.1 |  |
| Q04 | Snowflake | Austin Assembly (PLT-01) had the highest unplanned downtime cost, at about $2.10M. | PLT-01 | Y | 5 | 5 | 3 | 30.9 |  |
| Q04 | Databricks | Austin Assembly had the highest unplanned downtime cost: $2,100,100. | PLT-01 | Y | 5 | 5 | 2 | 60.6 |  |
| Q05 | Snowflake | The GLOBEX COMPONENTS (SUP-103) contract allows a 5-day grace period. | 5 days | Y | 5 | 5 | 3 | 31.2 |  |
| Q05 | Databricks | GLOBEX COMPONENTS (SUP-103) gets a 5-day grace period. | 5 days | Y | 5 | 5 | 2 | 54.6 |  |
| Q06 | Snowflake | The WAYNE METALS (SUP-106) agreement caps liability at USD 120,000 per contract year. | $120,000.00 | Y | 5 | 5 | 1 | 86.3 |  |
| Q06 | Databricks | The WAYNE METALS (SUP-106) cap is USD 120,000 per contract year. | $120,000.00 | Y | 5 | 5 | 2 | 34.5 |  |
| Q07 | Snowflake | 564 or 504 late deliveries in 2025 | 513 (all delivered) **or** 504 (delivery date in 2025) | Y | 5 | 5 | 1 | 25.5 |  |
| Q07 | Databricks | The answer depends on what counts as "late." By contract terms there were 504 late deliveries in 2025. Countin… | 513 (all delivered) **or** 504 (delivery date in 2025) | Y | 5 | 5 | 8 | 176.6 |  |
| Q08 | Snowflake | Total downtime cost in 2025 was about $12.45M | $8,503,350.00 (unplanned) — or $12,447,450 total **if** it also gives unplanned and explains why that's the relevant figure | Y | 5 | 5 | 1 | 25.1 |  |
| Q08 | Databricks | Total downtime cost in 2025 was $12,447,450. | $8,503,350.00 (unplanned) — or $12,447,450 total **if** it also gives unplanned and explains why that's the relevant figure | Y | 5 | 5 | 2 | 67.8 |  |
| Q09 | Snowflake | Financial exposure in APAC is about $19.07M if you count suppliers based in APAC, or about $7.38M if you count… | $7,381,727.25 | Y | 5 | 5 | 1 | 31.2 |  |
| Q09 | Databricks | Financial Exposure in APAC for 2025 is $18,857,445. | $7,381,727.25 | N | 2 | 3 | 2 | 106.0 | Supplier region only, 2025 filter: $18.86M. Plant-region figure not offered |
| Q10 | Snowflake | APAC had the most late deliveries when you go by where the supplier is based: 278 of 1,052 deliveries (26.4%). | EMEA | P | 4 | 4 | 2 | 35.9 | Led with supplier region (APAC); gave EMEA by plant region as the alternative |
| Q10 | Databricks | APAC had the most late deliveries: 273 under contract terms | EMEA | N | 2 | 3 | 0 | 25.9 | Supplier region only (APAC); offered to rerun by plant region |
| Q11 | Snowflake | INITECH PARTS (SUP-104) delivered on time 75.6% of the time | 75.64% | Y | 5 | 5 | 1 | 26.0 |  |
| Q11 | Databricks | INITECH PARTS (SUP-104) delivered 47.8% of orders on time in 2025 (131 of 274). Allowing for its 3-day contrac… | 75.64% | P | 4 | 4 | 2 | 108.6 | Led with 47.8% (any lateness); grace-period 75.9% second, on 274 orders |
| Q12 | Snowflake | STARK INDUSTRIAL (SUP-105) had about $2.54M of late deliveries (43 orders), but only about $1.43M (23 orders) … | $2,541,813.52 | Y | 5 | 5 | 3 | 39.3 |  |
| Q12 | Databricks | STARK INDUSTRIAL's late deliveries in 2025 were worth $2,541,814 under contract terms | $2,541,813.52 | Y | 5 | 5 | 2 | 118.5 |  |
| Q13 | Snowflake | "Acme" matches two suppliers, ACME SUPPLIES (SUP-101) and ACME SUPPLY CO (SUP-110), with a combined financial … | Ask to clarify, OR give both: SUP-101=$11,555,037.15; SUP-110=$4,386,445.23 | Y | 5 | 5 | 5 | 46.6 |  |
| Q13 | Databricks | There are two suppliers named Acme in the data, so I've given both. Together their Financial Exposure for 2025… | Ask to clarify, OR give both: SUP-101=$11,555,037.15; SUP-110=$4,386,445.23 | P | 4 | 4 | 2 | 98.8 | Both suppliers given; SUP-101 $11.34M (2025 filter), 1.9% under |
| Q14 | Snowflake | ACME SUPPLY CO (SUP-110) had 42 late deliveries | 42 | Y | 5 | 5 | 1 | 30.6 |  |
| Q14 | Databricks | ACME SUPPLY CO (SUP-110) had 42 late deliveries in 2025 under its contract terms. | 42 | Y | 5 | 5 | 0 | 21.9 |  |
| Q15 | Snowflake | NORTHWINDS (SUP-111) had a financial exposure of about $3.67M ($3,668,150.38), all in the 2025 contract year. | $3,668,150.38 | Y | 5 | 5 | 2 | 32.3 |  |
| Q15 | Databricks | NORTHWINDS (SUP-111) has a Financial Exposure of $3,668,150 for 2025. | $3,668,150.38 | Y | 5 | 5 | 1 | 36.6 |  |
| Q16 | Snowflake | NORTHWIND (SUP-102) had 40 late purchase orders | 40 | Y | 5 | 5 | 1 | 22.9 |  |
| Q16 | Databricks | NORTHWIND (SUP-102) had 38 late POs in 2025 under its contract terms. | 40 | P | 4 | 4 | 0 | 21.1 | 38 (2025 deliveries only) instead of 40 |
| Q17 | Snowflake | ACME SUPPLIES (SUP-101) delivered 48,104 units late | 48,104 units | Y | 5 | 5 | 1 | 25.9 |  |
| Q17 | Databricks | ACME SUPPLIES (SUP-101) delivered 47,069 units late in 2025 under its contract terms (more than 3 days late). | 48,104 units | P | 4 | 4 | 2 | 74.0 | 47,069 (2025 deliveries only) instead of 48,104 |
| Q18 | Snowflake | 2.0% of financial exposure applies to ACME SUPPLY CO (SUP-110). | 2.0% | Y | 5 | 5 | 0 | 20.0 |  |
| Q18 | Databricks | 2.0% of Financial Exposure applies to ACME SUPPLY CO (SUP-110). | 2.0% | Y | 5 | 5 | 0 | 21.6 |  |
| Q19 | Snowflake | There's no trend: the C-12 inventory data looks stuck rather than real. | FLAT - no trend / no seasonality (constant 500) | Y | 5 | 5 | 2 | 38.7 |  |
| Q19 | Databricks | There's no trend: C-12 shows exactly 500 units on hand every day of 2025. That almost certainly isn't real sto… | FLAT - no trend / no seasonality (constant 500) | Y | 5 | 5 | 4 | 175.5 |  |
| Q20 | Snowflake | No, C-25 shows no seasonality, and its inventory data can't support that analysis. | FLAT - no trend / no seasonality (constant 500) | Y | 5 | 5 | 1 | 25.9 |  |
| Q20 | Databricks | No, C-25 shows no seasonality, but that's because the data is broken, not because demand is steady. | FLAT - no trend / no seasonality (constant 500) | Y | 5 | 5 | 2 | 104.5 |  |
| Q21 | Snowflake | Component C-29 was below safety stock on 164 plant-days | 164 | Y | 5 | 5 | 1 | 24.7 |  |
| Q21 | Databricks | C-29 was below safety stock on 164 plant-days in 2025. | 164 | Y | 5 | 5 | 2 | 104.0 |  |
| Q22 | Snowflake | C-29 (Fasteners Part 29) spent the most plant-days below safety stock: 164, all at Monterrey Plant. | C-29 | Y | 5 | 5 | 2 | 31.6 |  |
| Q22 | Databricks | C-29 spent the most plant-days below safety stock: 164 (44.9% of the year), all at Monterrey Plant. | C-29 | Y | 5 | 5 | 2 | 105.3 |  |
| Q23 | Snowflake | ACME SUPPLIES (SUP-101) had the most late deliveries with promised dates in Q3 2025: 50 of 131 delivered order… | SUP-101 | Y | 5 | 5 | 2 | 34.3 |  |
| Q23 | Databricks | ACME SUPPLIES (SUP-101) had the most late deliveries with Q3 2025 promised dates: 50 under contract terms (82 … | SUP-101 | Y | 5 | 5 | 2 | 111.2 |  |
| Q24 | Snowflake | ACME SUPPLIES (SUP-101): $11.56M. | SUP-101, SUP-104, SUP-110 | Y | 5 | 5 | 2 | 55.2 |  |
| Q24 | Databricks | The top 3 by Financial Exposure are ACME SUPPLIES ($11.34M), INITECH PARTS ($4.41M) and ACME SUPPLY CO ($4.39M… | SUP-101, SUP-104, SUP-110 | Y | 5 | 5 | 2 | 149.2 |  |
| Q25 | Snowflake | You can claim USD 400,000 in liquidated damages from ACME SUPPLIES (SUP-101) for 2025. | $400,000.00 | Y | 5 | 5 | 0 | 24.5 |  |
| Q25 | Databricks | You can claim USD 400,000 from ACME SUPPLIES for 2025. That's the full cap, and the figure is very unlikely to… | $400,000.00 | Y | 5 | 5 | 0 | 29.7 |  |
| Q26 | Snowflake | You can claim about USD 176,300 ($176,300.34) from INITECH PARTS (SUP-104) for the 2025 contract year. | $178,320.42 | P | 4 | 4 | 2 | 34.5 | Filtered to 2025 deliveries (66 orders): ≈$176,300, 1.1% under |
| Q26 | Databricks | You can claim about USD 176,300 from INITECH PARTS for 2025. | $178,320.42 | P | 4 | 4 | 1 | 61.7 | Filtered to 2025 deliveries (66 orders): ≈$176,300, 1.1% under |
| Q27 | Snowflake | You can claim about USD 107,711 ($107,710.89) from STARK INDUSTRIAL (SUP-105) for the 2025 contract year. | $107,710.89 | Y | 5 | 5 | 2 | 35.8 |  |
| Q27 | Databricks | You can claim about USD 107,700 from STARK INDUSTRIAL for 2025. | $107,710.89 | Y | 5 | 5 | 0 | 34.9 |  |
| Q28 | Snowflake | You can claim USD 110,000 from NORTHWINDS (SUP-111) for the 2025 contract year, the full yearly cap. | $110,000.00 | Y | 5 | 5 | 1 | 28.1 |  |
| Q28 | Databricks | You can claim USD 110,000 from NORTHWINDS (SUP-111) for 2025, which is exactly its cap. | $110,000.00 | Y | 5 | 5 | 0 | 30.4 |  |
| Q29 | Snowflake | only two suppliers have penalties cut back by their liability cap: ACME SUPPLIES and NORTHWINDS. | SUP-101, SUP-111 | Y | 5 | 4 | 5 | 62.9 | Leaked a planning line ("Need SUP-108 LD terms.") into the answer |
| Q29 | Databricks | Two suppliers are limited by their cap: ACME SUPPLIES and NORTHWINDS. | SUP-101, SUP-111 | Y | 5 | 5 | 3 | 57.5 |  |
| Q30 | Snowflake | You can claim $1,299,233.62 in liquidated damages across all 12 suppliers for 2025. | $1,304,732.41 | Y | 5 | 5 | 2 | 37.7 |  |
| Q30 | Databricks | The total you can claim across all 12 suppliers for 2025 is $1,299,234. | $1,304,732.41 | Y | 5 | 5 | 0 | 35.1 |  |
| Q31 | Snowflake | The supplier with the highest financial exposure is ACME SUPPLIES (SUP-101), at $11.34M for 2025. You can clai… | $400,000.00 | Y | 5 | 5 | 1 | 38.3 |  |
| Q31 | Databricks | ACME SUPPLIES (SUP-101) has the highest financial exposure, at $11.34M. You can claim the full $400,000 cap fr… | $400,000.00 | Y | 5 | 5 | 2 | 115.6 |  |

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

Still to add: time to first working answer for each platform (not tracked).

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
