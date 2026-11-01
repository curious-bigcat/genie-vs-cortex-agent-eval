-- =============================================================================
-- 02_cortex_search.sql  |  Snowflake: parse contract PDFs, chunk, Cortex Search
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SC_EVAL_WH;
USE SCHEMA SUPPLY_CHAIN_EVAL.DOCS;

CREATE OR REPLACE STAGE CONTRACTS_STAGE
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');   -- required for AI_PARSE_DOCUMENT

-- Upload from local CLI (or Snowsight > stage > + Files):
-- PUT file:///<REPO_PATH>/data/output/contracts/*.pdf @SUPPLY_CHAIN_EVAL.DOCS.CONTRACTS_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
ALTER STAGE CONTRACTS_STAGE REFRESH;

-- 1) Parse
CREATE OR REPLACE TABLE CONTRACT_DOCS AS
SELECT RELATIVE_PATH,
       REPLACE(RELATIVE_PATH, '.pdf', '')                         AS DOC_NAME,
       REGEXP_SUBSTR(RELATIVE_PATH, 'SUP-[0-9]{3}')                AS SUPPLIER_ID,
       IFF(RELATIVE_PATH ILIKE '%AMENDMENT%', 'AMENDMENT', 'MSA')  AS DOC_TYPE,
       AI_PARSE_DOCUMENT(TO_FILE('@CONTRACTS_STAGE', RELATIVE_PATH), {'mode': 'LAYOUT'}):content::STRING AS DOC_TEXT
FROM DIRECTORY(@CONTRACTS_STAGE);

-- 2) Chunk (docs are short; chunks keep sections intact)
CREATE OR REPLACE TABLE CONTRACT_CHUNKS AS
-- Every chunk starts with a document header, so later chunks (e.g. section 8) stay findable by supplier
SELECT d.RELATIVE_PATH, d.DOC_NAME, d.SUPPLIER_ID, d.DOC_TYPE,
       c.INDEX AS CHUNK_INDEX,
       '[' || d.DOC_NAME || ' | ' || d.SUPPLIER_ID || ' | ' || s.SUPPLIER_NAME || ']\n' || c.VALUE::STRING AS CHUNK
FROM CONTRACT_DOCS d
LEFT JOIN SUPPLY_CHAIN_EVAL.RAW.DIM_SUPPLIER s ON s.SUPPLIER_ID = d.SUPPLIER_ID,
     LATERAL FLATTEN(SNOWFLAKE.CORTEX.SPLIT_TEXT_RECURSIVE_CHARACTER(d.DOC_TEXT, 'markdown', 1200, 150)) c;

-- 3) Search service
CREATE OR REPLACE CORTEX SEARCH SERVICE CONTRACTS_SEARCH
  ON CHUNK
  ATTRIBUTES SUPPLIER_ID, DOC_TYPE, DOC_NAME
  WAREHOUSE = SC_EVAL_WH
  TARGET_LAG = '1 day'
  AS SELECT CHUNK, SUPPLIER_ID, DOC_TYPE, DOC_NAME, RELATIVE_PATH, CHUNK_INDEX FROM CONTRACT_CHUNKS;

-- Validation: expect 14 docs; the SUP-101 amendment should rank in the top results
SELECT COUNT(*) AS DOCS FROM CONTRACT_DOCS;
SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW('SUPPLY_CHAIN_EVAL.DOCS.CONTRACTS_SEARCH',
  '{"query":"liquidated damages percentage ACME SUPPLIES","columns":["DOC_NAME","CHUNK"],"limit":3}')):results;
