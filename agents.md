# Multi-Agent Architectures: Databricks vs. Snowflake

## 1. Platform Architectural Breakdown

### Databricks (Agent Bricks, Genie & Lakebase Stack)

Databricks approaches multi-agent systems with an open, code-first developer platform. Orchestration logic can be implemented in frameworks like LangGraph, AutoGen, or the OpenAI Agents SDK, while leveraging Databricks-managed platform services:

- **Structured Data:** Genie One / Genie Agents act as sub-agents or tools. Rather than relying strictly on rigid YAML models, Genie uses lakehouse metadata, table lineage, and curated Genie Ontologies in Unity Catalog to dynamically convert natural language to optimized SQL queries.
- **Unstructured Data:** Databricks AI Search and `ai_parse_document()` ingest PDFs, Office documents, and contracts into vector indexes, allowing specialized RAG sub-agents to retrieve and cite grounding text.
- **Operational Actions (MCP):** Databricks natively provides an MCP Catalog and server support. Agents can consume built-in MCP tools (Genie spaces, Unity Catalog functions, Vector Search) and external third-party MCP servers (Salesforce, ServiceNow, Jira).
- **Agent State & Memory:** Managed via Lakebase, which stores multi-turn session states and agent memory directly inside the Lakehouse.
- **Governance & Runtime:** Managed through Unity AI Gateway (rate limits, guardrails, and On-Behalf-Of credential delegation) running on Databricks Apps or serverless Agent Runtime.

### Snowflake (Cortex Agents & Horizon Stack)

Snowflake prioritizes a declarative, warehouse-native system where an agent is a managed schema object (`CREATE AGENT`) running entirely inside Snowflake's trust boundary:

- **Structured Data:** Cortex Analyst performs text-to-SQL over Semantic Views / Semantic Data Models. It requires explicit schema definitions, verified queries, and defined metrics, yielding deterministic calculations.
- **Unstructured Data:** Cortex Search performs hybrid vector/keyword search over documents stored directly in Snowflake internal/external stages.
- **Operational Actions (MCP):** Snowflake features a Snowflake-Managed MCP Server. Agents can invoke external MCP servers using OAuth 2.0 or expose Cortex Agents themselves as MCP endpoints to client applications (e.g., Claude Desktop, custom microservices).
- **Compute & Execution:** Operates on an internal reasoning loop (Plan → Tool Call → Reflect/Respond) with isolated Python sandbox execution (Code Execution Tool) and pre-built UDFs.
- **Governance & Runtime:** Bound to Snowflake Horizon with role-based access control (RBAC), row/column policies, and credit budget caps.

## 2. Side-by-Side Comparison

| Capability | Databricks Agent Bricks Architecture | Snowflake Cortex Agent Architecture |
|---|---|---|
| **Orchestrator Execution** | Code-first (LangGraph / OpenAI Agents SDK) deployed on Agent Runtime / Databricks Apps. | Managed schema object (`CREATE AGENT`) with built-in reasoning loop. |
| **Structured Layer** | Genie Agents / Genie MCP Server (Unity Catalog ontology). | Cortex Analyst (YAML Semantic Data Models & Views). |
| **Unstructured Layer** | Databricks AI Search & Vector Search via Delta tables. | Cortex Search Services indexed directly on Snowflake Stages. |
| **Tool Protocol** | MCP Catalog (Unity Catalog-governed MCP clients & servers). | Built-in MCP Connectors & Snowflake-managed MCP Servers. |
| **State Persistence** | Persistent sessions and semantic memory backed by Lakebase. | Native Agent Threads, logging tables, and external state stores. |
| **Observability** | MLflow Tracing and Mosaic AI LLM-as-a-judge. | Snowflake Trail, TruLens integration, and event logging tables. |

## 3. Comprehensive Multi-Agent Use Case

### Scenario: Autonomous Supply Chain Risk & SLA Remediation

A multi-facility enterprise needs to detect supply chain disruptions, determine contract breach liability, and execute supplier mitigations automatically.

### Workflow Decomposition

1. **Trigger / User Query:**
   > "A major supplier missed delivery dates for plant components. Determine the financial exposure, check contract breach terms, and open mitigation tickets in Jira."

2. **Orchestrator Planning:** Breaks the workflow into structured queries (inventory impact), unstructured lookups (vendor agreements), and external operations (ERP & Jira).

3. **Structured Sub-Agent:**
   - **Databricks:** Genie Agent queries `gold_supply_chain.purchase_orders` and `inventory_levels` to compute downtime cost and missing unit counts.
   - **Snowflake:** Cortex Analyst runs SQL against the `SUPPLY_CHAIN_DEMO` semantic model to compute delayed shipments and average delivery lag.

4. **Unstructured Sub-Agent:**
   - **Databricks:** Vector Search searches vendor master service agreements (MSAs) for "Force Majeure" and late penalty clauses.
   - **Snowflake:** Cortex Search queries `SUPPLIER_EMAILS` and PDF contracts in stage storage to extract liability caps.

5. **Operational Execution (MCP Tool):** The agent calls an ERP MCP Server (e.g., SAP) to place a hold on pending vendor disbursements and calls an Atlassian Jira MCP Server to raise a Priority-1 SLA breach ticket with structured and unstructured evidence attached.

## 4. Implementation Blueprint

### Option A: Databricks Agent Bricks with MCP & Genie

```python
from agents import Agent, Runner
from databricks.sdk import WorkspaceClient

w = WorkspaceClient()

# 1. Structured sub-agent (Genie) via MCP
genie_supply_chain_tool = {
    "name": "genie_inventory_analyst",
    "type": "genie_space",
    "space_id": "01ef-supply-chain-space",
    "description": "Calculates unit shortages, delayed orders, and production costs from Delta tables."
}

# 2. Unstructured sub-agent (AI Search)
contracts_rag_tool = {
    "name": "search_vendor_contracts",
    "type": "vector_search",
    "endpoint": "vs-supplier-agreements",
    "description": "Searches supplier MSAs for liquidated damages, penalties, and SLA terms."
}

# 3. Operational tool via MCP Server
jira_mcp_tool = {
    "name": "jira_mcp_connector",
    "type": "mcp_server",
    "endpoint": "https://mcp-gateway.corp.net/jira/sse",
    "description": "Creates, assigns, and tags procurement remediation tickets."
}

# 4. Supervisor Agent Definition
supervisor = Agent(
    name="SupplyChainRemediationSupervisor",
    instructions="""
    You are an autonomous Supply Chain Risk Supervisor.
    1. Retrieve impacted orders and financial exposure using `genie_inventory_analyst`.
    2. Check the vendor MSA via `search_vendor_contracts` to find SLA penalties.
    3. If financial exposure > $10,000, invoke `jira_mcp_connector` to open an incident.
    4. Provide an executive summary with data citations and Jira issue links.
    """,
    tools=[genie_supply_chain_tool, contracts_rag_tool, jira_mcp_tool],
    model="databricks-meta-llama-3-3-70b-instruct"
)
```

### Option B: Snowflake Cortex Agent Definition

```sql
-- 1. Create the Cortex Agent bundle
CREATE OR REPLACE CORTEX AGENT supply_chain_remediation_agent
  MODEL = 'claude-3-5-sonnet'
  INSTRUCTIONS = 'You coordinate supply chain disruption remediation:
                  1. Query structured order delays via cortex_analyst_tool.
                  2. Search vendor breach terms via cortex_search_tool.
                  3. If breach conditions are met, create tickets via mcp_jira_tool.'
  TOOLS = (
    -- Structured Data Tool
    cortex_analyst_tool {
      TYPE = 'CORTEX_ANALYST',
      SEMANTIC_VIEW = 'supply_chain_db.analytics.sv_procurement_metrics'
    },
    -- Unstructured Search Tool
    cortex_search_tool {
      TYPE = 'CORTEX_SEARCH',
      SERVICE = 'supply_chain_db.docs.vendor_contracts_search',
      MAX_RESULTS = 5
    },
    -- External MCP Connector
    mcp_jira_tool {
      TYPE = 'MCP_CONNECTOR',
      SERVER_NAME = 'INTEGRATION_DB.PUBLIC.JIRA_MCP_SERVER',
      ALLOWED_TOOLS = ['create_issue', 'attach_log']
    }
  );

-- 2. Execute the multi-agent reasoning loop
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'supply_chain_remediation_agent',
  'Check delays for Acme Supplies, assess SLA penalty terms, and log an incident if penalties apply.'
);
```
