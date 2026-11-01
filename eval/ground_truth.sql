-- =============================================================================
-- ground_truth.sql  |  Portable (Snowflake + Databricks SQL) ground truth.
-- Purpose: (1) prove data parity across platforms, (2) cross-check
--          data/output/expected_answers.json.
-- Set context first:
--   Snowflake:  USE SCHEMA SUPPLY_CHAIN_EVAL.RAW;
--   Databricks: USE CATALOG <catalog>; USE SCHEMA <schema>;
-- Contract terms below are the EFFECTIVE (amended) terms. They come from the PDFs,
-- not from any table, so the agents must retrieve them from the documents.
-- =============================================================================
WITH terms AS (
  SELECT * FROM (VALUES
    ('SUP-101', 0.080, 400000), ('SUP-102', 0.040, 200000), ('SUP-103', 0.030, 150000),
    ('SUP-104', 0.040, 180000), ('SUP-105', 0.050, 500000), ('SUP-106', 0.025, 120000),
    ('SUP-107', 0.035, 175000), ('SUP-108', 0.045, 220000), ('SUP-109', 0.030, 160000),
    ('SUP-110', 0.020,  90000), ('SUP-111', 0.030, 110000), ('SUP-112', 0.055, 260000)
  ) AS t(supplier_id, penalty_pct, liability_cap)
),
po AS (
  SELECT p.*, s.contract_grace_days,
         CASE WHEN p.status = 'DELIVERED'
               AND DATEDIFF(day, p.promised_date, p.actual_delivery_date) > s.contract_grace_days
              THEN 1 ELSE 0 END AS late
  FROM fact_purchase_orders p JOIN dim_supplier s ON p.supplier_id = s.supplier_id
),
unpl AS (SELECT * FROM fact_downtime_events WHERE event_type = 'UNPLANNED'),
sup AS (
  SELECT s.supplier_id,
    (SELECT SUM(late) FROM po WHERE po.supplier_id = s.supplier_id) AS late_cnt,
    (SELECT SUM(CASE WHEN late = 1 THEN quantity ELSE 0 END) FROM po WHERE po.supplier_id = s.supplier_id) AS late_units,
    (SELECT COALESCE(SUM(CASE WHEN late = 1 THEN quantity * unit_price END), 0) FROM po WHERE po.supplier_id = s.supplier_id) AS dv,
    (SELECT COALESCE(SUM(downtime_hours * cost_per_hour), 0) FROM unpl WHERE unpl.supplier_id = s.supplier_id) AS dt,
    (SELECT COALESCE(SUM(CASE WHEN late = 1 AND NOT (promised_date BETWEEN DATE '2025-03-01' AND DATE '2025-03-31') THEN quantity * unit_price END), 0)
       FROM po WHERE po.supplier_id = s.supplier_id) AS dv_ex_fm,
    (SELECT COALESCE(SUM(CASE WHEN NOT (event_date BETWEEN DATE '2025-03-01' AND DATE '2025-03-31') THEN downtime_hours * cost_per_hour END), 0)
       FROM unpl WHERE unpl.supplier_id = s.supplier_id) AS dt_ex_fm
  FROM dim_supplier s
),
pen AS (
  SELECT sup.*, t.penalty_pct, t.liability_cap,
         CASE WHEN sup.supplier_id = 'SUP-105' THEN dv_ex_fm + dt_ex_fm ELSE dv + dt END AS exp_eff
  FROM sup JOIN terms t ON sup.supplier_id = t.supplier_id
)
SELECT 'delivered_po_count_total' AS ref, CAST(SUM(CASE WHEN status = 'DELIVERED' THEN 1 ELSE 0 END) AS DOUBLE) AS value FROM po
UNION ALL SELECT 'open_po_count_total', CAST(SUM(CASE WHEN status = 'OPEN' THEN 1 ELSE 0 END) AS DOUBLE) FROM po
UNION ALL SELECT 'late_po_count_total', CAST(SUM(late) AS DOUBLE) FROM po
UNION ALL SELECT 'late_po_count_flag_total', CAST(SUM(CASE WHEN is_late THEN 1 ELSE 0 END) AS DOUBLE) FROM po
UNION ALL SELECT 'unplanned_downtime_cost_total', CAST(ROUND(SUM(downtime_hours * cost_per_hour), 2) AS DOUBLE) FROM unpl
UNION ALL SELECT 'total_downtime_cost_total', CAST(ROUND(SUM(downtime_hours * cost_per_hour), 2) AS DOUBLE) FROM fact_downtime_events
UNION ALL SELECT CONCAT('late_po_count.', supplier_id), CAST(late_cnt AS DOUBLE) FROM sup
UNION ALL SELECT CONCAT('late_units.', supplier_id), CAST(late_units AS DOUBLE) FROM sup
UNION ALL SELECT CONCAT('delayed_order_value.', supplier_id), CAST(ROUND(dv, 2) AS DOUBLE) FROM sup
UNION ALL SELECT CONCAT('financial_exposure.', supplier_id), CAST(ROUND(dv + dt, 2) AS DOUBLE) FROM sup
UNION ALL SELECT CONCAT('penalty_effective.', supplier_id), CAST(ROUND(LEAST(exp_eff * penalty_pct, liability_cap), 2) AS DOUBLE) FROM pen
UNION ALL SELECT CONCAT('avg_delivery_lag_days.', supplier_id),
                 CAST(ROUND(AVG(DATEDIFF(day, promised_date, actual_delivery_date)), 2) AS DOUBLE)
          FROM po WHERE status = 'DELIVERED' GROUP BY supplier_id
UNION ALL SELECT CONCAT('on_time_rate.', supplier_id),
                 CAST(ROUND(1 - SUM(late) / SUM(CASE WHEN status = 'DELIVERED' THEN 1.0 ELSE 0 END), 4) AS DOUBLE)
          FROM po GROUP BY supplier_id
UNION ALL SELECT CONCAT('days_below_safety.', component_id),
                 CAST(SUM(CASE WHEN on_hand_qty < safety_stock_qty THEN 1 ELSE 0 END) AS DOUBLE)
          FROM fact_inventory_daily WHERE component_id IN ('C-29', 'C-12', 'C-25') GROUP BY component_id
UNION ALL SELECT CONCAT('inventory_stddev.', component_id), CAST(STDDEV(on_hand_qty) AS DOUBLE)
          FROM fact_inventory_daily WHERE component_id IN ('C-12', 'C-25') GROUP BY component_id
UNION ALL SELECT CONCAT('exposure_by_plant_region.', pl.plant_region),
                 CAST(ROUND(SUM(x.v), 2) AS DOUBLE)
          FROM (SELECT plant_id, quantity * unit_price AS v FROM po WHERE late = 1
                UNION ALL SELECT plant_id, downtime_hours * cost_per_hour FROM unpl WHERE supplier_id IS NOT NULL) x
          JOIN dim_plant pl ON x.plant_id = pl.plant_id GROUP BY pl.plant_region
UNION ALL SELECT CONCAT('exposure_by_supplier_region.', s.supplier_region),
                 CAST(ROUND(SUM(x.v), 2) AS DOUBLE)
          FROM (SELECT supplier_id, quantity * unit_price AS v FROM po WHERE late = 1
                UNION ALL SELECT supplier_id, downtime_hours * cost_per_hour FROM unpl WHERE supplier_id IS NOT NULL) x
          JOIN dim_supplier s ON x.supplier_id = s.supplier_id GROUP BY s.supplier_region
ORDER BY 1;
