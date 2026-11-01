# Databricks Genie: Constraints & Failure Patterns

Extracted from *TechUp Labs 2026* (Databricks lab: Genie Agents comparison).

---

## 1. Product Constraints

| Constraint | Detail |
|---|---|
| No model choice | Genie Agents don't let you choose the underlying LLM. Cortex Agents do (Configuration → Instructions → Model), giving control over cost vs capability. |
| Entity matching cap | Max **120 string columns** per Genie agent. |
| Mode switching | After the first question, a **new chat** is required to switch between Chat and Agent modes. |
| User-driven mode selection | End users self-assess complexity to pick Chat vs Agent; the author can't centrally control it. |
| Agent-local metadata | Display names, descriptions and synonyms edited in Genie apply **only to that agent**, not to Unity Catalog. |
| Fragmented config surfaces | Business logic can live in metric views, instructions (free text), SQL examples, synonyms, entity matching and the knowledge store. Only metric views are governed UC objects; the rest is agent-level config. |
| Dependencies | Requires Unity Catalog and a SQL warehouse. |
| Confusing naming | Genie Agents (formerly Genie Spaces; business users) vs Databricks AI Agents / Agent Bricks / Mosaic AI (code-first; developers). |

---

## 2. Failure Patterns

### 2.1 Ambiguous business logic
- **Pattern:** multiple valid ways to compute a metric.
- **Example:** "Closed won revenue" can come from `stage = 'Closed Won'` or from `is_won`. Region can be attributed to the customer or to the rep.
- **Failure:** without explicit context, Genie picks an interpretation that may not match the business definition, so it returns a wrong number confidently.

### 2.2 Undefined generic terms
- **Pattern:** vague terms like "total revenue" or "how are sales doing?"
- **Failure:** Genie assumes a definition (e.g. sums all opportunity amounts) instead of using the intended metric or asking for clarification.

### 2.3 Domain codenames and typos
- **Pattern:** internal codenames and TLAs with similar names (e.g. `TYTAN (BU-4471)` vs `TITANIUM (BU-4472)`).
- **Example prompt:** "How much revenue came from the **Titan** segment?"
- **Failure:** Genie may map "Titan" to the wrong segment, merge both, or need nudging. Getting it right depends on entity matching, synonyms and instructions being configured.

### 2.4 Failing to report "no signal"
- **Pattern:** analytical questions on flat or deterministic data (e.g. "Do any segments show seasonality?").
- **Failure:** it may invent trends instead of stating there is essentially no variability. This is especially likely in Chat mode.

### 2.5 Conflicting guidance
- **Pattern:** instructions contradict a metric view or example SQL.
  - Example: an instruction says closed won revenue includes the `Negotiation` stage, but the metric view defines it as `Closed Won` only.
- **Failure:** behavior becomes unpredictable. Genie may bypass the governed metric view (`MEASURE(...)`) and write a new `SUM(...)` against the raw table, breaking the single definition.
- Databricks itself warns that inconsistent instruction types (e.g. rounding rules in text vs SQL) lead to unpredictable results.

### 2.6 Chat-mode shallowness
- **Pattern:** complex "why / what-if" or multi-dimensional questions asked in Chat mode.
- **Failure:** Chat mode runs a single direct query and gives shallow answers. Agent mode is needed, but users must pick it themselves and restart the chat to switch.

### 2.7 Nondeterminism
- The same question can produce different SQL or answers across runs. This includes Genie's own help with building metric views.

---

## 3. Governance & Operational Weaknesses
- **Many places to look** to learn how a metric is computed, and most of them are free text, not versioned or governed objects.
- **Metric views don't create logic:** humans must still agree on definitions, edge cases and authoritative fields.
- **Setup demos well but isn't production-ready:** fast to stand up, but reliable use requires metric views, instruction tuning, and testing and validation.
- **High long-term iteration cost:** the many configuration options make it harder to maintain an agent as the business changes.

---

## 4. Snowflake Counterpoints (for sales conversations)
- Cortex Agents let the author **choose the model**.
- Business logic is centralized in a governed, versioned **semantic view**. Instructions are reserved for agent behavior.
- The author controls the model, tools and skills, which gives consistency and cost control for the teams using the agent.
- **Tradeoff:** more upfront semantic-view work, but a single place to maintain it.
