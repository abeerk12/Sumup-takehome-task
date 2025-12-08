-- Q1 – The resolution window is 7 days; we would like to optimise this timeframe. Recommend a new one and justify.

-- Goal:
--   Calibrate resolution window based on when "resolved" issues come back.

WITH all_interactions AS (
  SELECT
    INTERACTION_ID,
    MERCHANT_CODE,
    CLASSIFICATION_PRODUCT,
    DATE(CREATED_DATE) AS created_date,
    DATE_TRUNC(DATE(CREATED_DATE), MONTH) AS month,
    IS_RESOLVING_INTERACTION
  FROM `sumup-takehometest.1234.interactions`
  where DATE_TRUNC(DATE(CREATED_DATE), MONTH) = date('2024-12-01')--limiting to Dec'24 due to data constraints explained in readme file
),

sequenced AS (
  SELECT
    INTERACTION_ID,
    MERCHANT_CODE,
    CLASSIFICATION_PRODUCT,
    created_date,
    month,
    IS_RESOLVING_INTERACTION,
    -- Next same-merchant, same-product interaction
    LEAD(created_date) OVER (
      PARTITION BY MERCHANT_CODE, CLASSIFICATION_PRODUCT
      ORDER BY created_date, INTERACTION_ID
    ) AS next_created_date
  FROM all_interactions
),

gaps AS (
  SELECT
    month,
    created_date,
    next_created_date,
    CASE
      WHEN next_created_date IS NULL THEN NULL
      ELSE DATE_DIFF(next_created_date, created_date, DAY)
    END AS days_to_next --days to next interaction
  FROM sequenced
  WHERE IS_RESOLVING_INTERACTION = TRUE
)

--Getting a distribution of repeat contacts by number of days

SELECT
  month,
  COUNT(*) AS total_resolving_interactions,
  COUNTIF(days_to_next IS NOT NULL) AS resolving_with_recontact,
  SAFE_DIVIDE(COUNTIF(days_to_next <= 1),  COUNTIF(days_to_next IS NOT NULL)) AS pct_recontact_within_1d,
  SAFE_DIVIDE(COUNTIF(days_to_next <= 3),  COUNTIF(days_to_next IS NOT NULL)) AS pct_recontact_within_3d,
  SAFE_DIVIDE(COUNTIF(days_to_next <= 7),  COUNTIF(days_to_next IS NOT NULL)) AS pct_recontact_within_7d,
  SAFE_DIVIDE(COUNTIF(days_to_next <= 10), COUNTIF(days_to_next IS NOT NULL)) AS pct_recontact_within_10d,
  SAFE_DIVIDE(COUNTIF(days_to_next <= 14), COUNTIF(days_to_next IS NOT NULL)) AS pct_recontact_within_14d,
  SAFE_DIVIDE(COUNTIF(days_to_next <= 30), COUNTIF(days_to_next IS NOT NULL)) AS pct_recontact_within_30d
FROM gaps
GROUP BY month
ORDER BY month;
