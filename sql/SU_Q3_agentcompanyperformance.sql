-- Q3 – Which Agent Company performed the best?
-- Metric: 7-day recontact rate on resolving interactions(=TRUE) by AGENT_COMPANY.

--Base

WITH base AS (
  SELECT
    INTERACTION_ID,
    MERCHANT_CODE,
    CLASSIFICATION_PRODUCT,
    AGENT_COMPANY,
    DATE(CREATED_DATE) AS created_date,
    IS_RESOLVING_INTERACTION
  FROM `sumup-takehometest.1234.interactions`
  where DATE_TRUNC(DATE(CREATED_DATE), MONTH) = date('2024-12-01')
),

----Sequencing to get the next date of contact

sequenced AS (
  SELECT
    INTERACTION_ID,
    MERCHANT_CODE,
    CLASSIFICATION_PRODUCT,
    AGENT_COMPANY,
    created_date,
    IS_RESOLVING_INTERACTION,
    LEAD(created_date) OVER (
      PARTITION BY MERCHANT_CODE, CLASSIFICATION_PRODUCT
      ORDER BY created_date, INTERACTION_ID
    ) AS next_created_date
  FROM base
),

----Calculating gaps between days of contacts

anchors AS (
  SELECT
    AGENT_COMPANY,
    CASE
      WHEN next_created_date IS NULL THEN NULL
      ELSE DATE_DIFF(next_created_date, created_date, DAY)
    END AS days_to_next
  FROM sequenced
  WHERE IS_RESOLVING_INTERACTION = TRUE
),

--Calculating recontact rate within 7 days for 'resolved' contacts

company_stats AS (
  SELECT
    AGENT_COMPANY,
    COUNT(*) AS resolving_interactions,
    COUNTIF(days_to_next <= 7) AS resolving_with_recontact_7d,
    SAFE_DIVIDE(COUNTIF(days_to_next <= 7), COUNT(*)) AS recontact_rate_7d
  FROM anchors
  GROUP BY AGENT_COMPANY
)

--Ranking agent companies with lowest recontact rate

SELECT
  AGENT_COMPANY,
  resolving_interactions,
  resolving_with_recontact_7d,
  recontact_rate_7d,
  DENSE_RANK() OVER (
    ORDER BY recontact_rate_7d ASC
  ) AS rank   -- 1 = best (lowest recontact rate)

FROM company_stats
ORDER BY rank;
