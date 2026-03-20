-- Step 1: Append all monthly sales table together

CREATE OR REPLACE TABLE `<Project ID>.sales.sales2025` AS
SELECT * FROM `<Project ID>.sales.sales202501`
UNION ALL SELECT * FROM `<Project ID>.sales.sales202502`
UNION ALL SELECT * FROM `<Project ID>.sales.sales202503`
UNION ALL SELECT * FROM `<Project ID>.sales.sales202504`
UNION ALL SELECT * FROM `<Project ID>.sales.sales202505`
UNION ALL SELECT * FROM `<Project ID>.sales.sales202506`
UNION ALL SELECT * FROM `<Project ID>.sales.sales202507`
UNION ALL SELECT * FROM `<Project ID>.sales.sales202508`
UNION ALL SELECT * FROM `<Project ID>.sales.sales202509`
UNION ALL SELECT * FROM `<Project ID>.sales.sales202510`
UNION ALL SELECT * FROM `<Project ID>.sales.sales202511`
UNION ALL SELECT * FROM `<Project ID>.sales.sales202512` ;

-- Step 2: calculate recency, frequency, monetary, r, f, m ranks
-- Combine views with CTEs

CREATE OR REPLACE VIEW `<Project ID>.sales.rfm_metrics` 
AS
WITH current_date AS(
  SELECT DATE('2026-03-19') AS analysis_date -- today's date
),
rfm AS (
  SELECT
    CustomerID,
    MAX(OrderDate) as last_order_date,
    DATE_DIFF((SELECT analysis_date FROM current_date), MAX(OrderDate), DAY) AS recency,
    COUNT(*) AS frequency,
    SUM(OrderValue) AS monetary
  FROM `<Project ID>.sales.sales2025`
  GROUP BY CustomerID
)

SELECT 
  rfm.*,
  ROW_NUMBER() OVER(ORDER BY recency ASC) AS r_rank, 
  ROW_NUMBER() OVER(ORDER BY frequency DESC) AS f_rank,
  ROW_NUMBER() OVER(ORDER BY monetary DESC) AS m_rank
FROM rfm;


-- STEP 3: assigning deciles (10=best, 1=worst)
CREATE OR REPLACE VIEW `<Project ID>.sales.rfm_scores` 
AS
SELECT 
  *,
  NTILE(10) OVER(ORDER BY r_rank DESC) AS r_score,
  NTILE(10) OVER(ORDER BY f_rank DESC) AS f_score,
  NTILE(10) OVER(ORDER BY m_rank DESC) AS m_score
FROM `<Project ID>.sales.rfm_metrics` ;

-- STEP 4: total score
CREATE OR REPLACE VIEW `<Project ID>.sales.rfm_total_scores`
AS
SELECT 
  CustomerID,
  recency,
  frequency,
  monetary,
  r_score,
  f_score,
  m_score, 
  (r_score + f_score + m_score) as rfm_total_score
FROM `<Project ID>.sales.rfm_scores` 
ORDER BY rfm_total_score DESC;

-- STEP 5: BI ready rfm segments table
CREATE OR REPLACE TABLE `<Project ID>.sales.rfm_segments_final` 
AS
SELECT
  CustomerID,
  recency, 
  frequency, 
  monetary, 
  r_score,
  f_score,
  m_score, 
  rfm_total_score,
  CASE 
    WHEN rfm_total_score >= 28 THEN 'Champions' -- 28-30
    WHEN rfm_total_score >= 24 THEN 'Loyal VIPs' 
    WHEN rfm_total_score >= 20 THEN 'Potential Loyalists'
    WHEN rfm_total_score >= 16 THEN 'Promising'
    WHEN rfm_total_score >= 12 THEN 'Engaged'
    WHEN rfm_total_score >= 8 THEN 'Requires Attention'
    WHEN rfm_total_score >= 4 THEN 'At Risk' 
    ELSE 'Lost/Inactive'
  END AS rfm_segment
FROM `<Project ID>.sales.rfm_total_scores`
ORDER BY rfm_total_score DESC;