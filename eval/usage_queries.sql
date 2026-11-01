-- =============================================================================
-- usage_queries.sql  |  Tool calls and latency per question, from the agent traces
-- =============================================================================

-- ===================== SNOWFLAKE (run in Snowsight) ==========================
-- One row per question asked to SC_RISK_AGENT (no ACCOUNT_USAGE lag).
-- Each SQL tool call shows up as two spans (SystemExecuteSQLTool + SqlExecution), so divide SQL spans by 2.
WITH e AS (SELECT * FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS(
             'SUPPLY_CHAIN_EVAL', 'ANALYTICS', 'SC_RISK_AGENT', 'CORTEX AGENT')) WHERE RECORD_TYPE = 'SPAN')
SELECT MIN(START_TIMESTAMP) AS started,
       MAX(IFF(RECORD:name = 'AgentV2RequestResponseInfo', RECORD_ATTRIBUTES:"ai.observability.record_root.input"::STRING, NULL)) AS question,
       DATEDIFF('ms', MIN(START_TIMESTAMP), MAX(TIMESTAMP)) / 1000 AS latency_s,
       COUNT_IF(RECORD_ATTRIBUTES:"snow.ai.observability.agent.tool.id" IS NOT NULL) AS tool_spans,
       LISTAGG(DISTINCT IFF(RECORD_ATTRIBUTES:"snow.ai.observability.agent.tool.id" IS NOT NULL, RECORD:name::STRING, NULL), ', ') AS tools,
       LISTAGG(DISTINCT RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.model"::STRING, ',') AS model
FROM e GROUP BY RECORD_ATTRIBUTES:"ai.observability.record_id" ORDER BY started;

-- ===================== DATABRICKS (run in a terminal) ========================
-- Agent Bricks writes MLflow traces to the experiment in agent.toml ([tracing]); find its ID in the MLflow UI.
-- Replace <EXPERIMENT_ID> and <PROFILE> (your Databricks CLI profile):
--   databricks api get "/api/2.0/mlflow/traces?experiment_ids=<EXPERIMENT_ID>&max_results=100" -p <PROFILE>
-- Gives execution_time_ms and status per trace. For tool calls, run
--   databricks api get "/api/2.0/mlflow/get-trace-artifact?request_id=<TRACE_ID>" -p <PROFILE>
-- and count the TOOL spans. Or use: agentbricks tracing list / agentbricks tracing get <TRACE_ID>
