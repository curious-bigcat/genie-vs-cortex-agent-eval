# Evaluation questions and expected answers

Ask the questions in order, in **one chat session per agent** (Snowflake Cortex Agent, Databricks Agent Bricks agent). Compare each answer with **Expected**.

- **Wrong if trap hit:** the value you get if the agent falls into the seeded trap.
- **Tolerance:** ±0.5% for money values.
- **Q36:** run it after the governance setup.


## Tier 1: Simple lookups

| # | Question | Expected | Wrong if trap hit | Check |
|---|---|---|---|---|
| Q01 | How many purchase orders were delivered in 2025? | 2,645 (all delivered; all orders were placed in 2025) **or** 2,636 (delivery date in 2025; 9 arrived Jan 2026) | — | Either is correct if the definition is stated. There is no 2024 data: any claim about 2024 orders is a hallucination |
| Q02 | How many purchase orders are still open? | 234 | — | Open POs only |
| Q03 | What was the average delivery lag in days for NORTHWIND (SUP-102)? | 1.36 | — | — |
| Q04 | Which plant had the highest unplanned downtime cost? | PLT-01 | — | Unplanned downtime only |
| Q05 | What is the delivery grace period in the GLOBEX COMPONENTS contract? | 5 days | — | source: MSA-SUP-103 s.5.1 |
| Q06 | What is the liability cap in the WAYNE METALS agreement? | $120,000.00 | — | source: MSA-SUP-106 s.8.1 |

## Tier 2: Ambiguous metrics

| # | Question | Expected | Wrong if trap hit | Check |
|---|---|---|---|---|
| Q07 | How many late deliveries were there in 2025? | 513 (all delivered) **or** 504 (delivery date in 2025) | 573 | Must use grace-days rule, NOT IS_LATE flag |
| Q08 | What was the total downtime cost in 2025? | $8,503,350.00 (unplanned) — or $12,447,450 total **if** it also gives unplanned and explains why that's the relevant figure | $12,447,450.00 | Unplanned downtime only |
| Q09 | What is the financial exposure in APAC? | $7,381,727.25 | $19,073,857.48 | Region = plant region |
| Q10 | Which region had the most late deliveries? | EMEA | — | Region = plant region |
| Q11 | What is the on-time delivery rate for INITECH PARTS? | 75.64% | — | Must use grace-days rule, NOT IS_LATE flag |
| Q12 | What was the value of late deliveries from STARK INDUSTRIAL? | $2,541,813.52 | — | Must use grace-days rule, NOT IS_LATE flag |

## Tier 3: Look-alike supplier names

| # | Question | Expected | Wrong if trap hit | Check |
|---|---|---|---|---|
| Q13 | What is the financial exposure for Acme? | Ask to clarify, OR give both: SUP-101=$11,555,037.15; SUP-110=$4,386,445.23 | — | Look-alike supplier names | Clarifying question counts as correct |
| Q14 | How many late deliveries did ACME SUPPLY CO have? | 42 | 179 | Look-alike supplier names |
| Q15 | What is the financial exposure for Northwinds? | $3,668,150.38 | $3,191,459.41 | Look-alike supplier names |
| Q16 | How many late POs did Nortwind have? | 40 | — | Look-alike supplier names | Clarifying question counts as correct |
| Q17 | How many units were delivered late by Acme Supplies? | 48,104 units | 12,893 units | Look-alike supplier names |
| Q18 | What liquidated damages percentage applies to Acme Supply Co? | 2.0% | — | Look-alike supplier names; source: MSA-SUP-110 s.7.1 |

## Tier 4: Analytical / no-signal

| # | Question | Expected | Wrong if trap hit | Check |
|---|---|---|---|---|
| Q19 | Is there a trend in on-hand inventory for component C-12 over 2025? | FLAT - no trend / no seasonality (constant 500) | — | Should say flat / no trend |
| Q20 | Does component C-25 show any seasonality in inventory levels? | FLAT - no trend / no seasonality (constant 500) | — | Should say flat / no trend |
| Q21 | How many plant-days was component C-29 below safety stock? | 164 | — | — |
| Q22 | Which component spent the most plant-days below safety stock? | C-29 | — | — |
| Q23 | Which supplier had the most late deliveries with promised dates in Q3 2025? | SUP-101 | — | Must use grace-days rule, NOT IS_LATE flag |
| Q24 | Who are the top 3 suppliers by financial exposure? | SUP-101, SUP-104, SUP-110 | — | Unplanned downtime only |

## Tier 5: Data + contracts (multi-step)

| # | Question | Expected | Wrong if trap hit | Check |
|---|---|---|---|---|
| Q25 | What liquidated damages can we claim from ACME SUPPLIES (SUP-101) for 2025? | $400,000.00 | $250,000.00 | Amendment overrides original; source: MSA-SUP-101-AMENDMENT-1 |
| Q26 | What liquidated damages can we claim from INITECH PARTS? | $178,320.42 | $267,480.63 | Amendment overrides original; source: MSA-SUP-104-AMENDMENT-1 |
| Q27 | What liquidated damages can we claim from STARK INDUSTRIAL? | $107,710.89 | $199,845.68 | Force majeure excludes March 2025; source: MSA-SUP-105 s.9.3 |
| Q28 | What liquidated damages can we claim from NORTHWINDS? | $110,000.00 | — | source: MSA-SUP-111 |
| Q29 | Which suppliers' claimable penalties are limited by their liability cap? | SUP-101, SUP-111 | — | Amendment overrides original |
| Q30 | What is the total claimable liquidated damages across all suppliers for 2025? | $1,304,732.41 | — | Amendment overrides original |
| Q31 | A major supplier missed delivery dates for plant components. Identify the supplier with the highest financial exposure, the contract breach terms, and the penalty we can claim. | $400,000.00 | — | Amendment overrides original; source: MSA-SUP-101-AMENDMENT-1 |

## Governance (ask as the restricted EMEA user)

| # | Question | Expected | Wrong if trap hit | Check |
|---|---|---|---|---|
| Q36 | List late deliveries by plant. | Only EMEA plants (PLT-02, PLT-05) | — | Run as restricted EMEA user |
