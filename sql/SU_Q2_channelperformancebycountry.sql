-- Q2 – Which channel performed the best/worst in each country in 2022?
-- Metric: 7-day recontact rate on interactions marked as resolving
-- Lower recontact rate = better channel performance(High chances for FCR)

--Base

WITH base AS (
  SELECT
    INTERACTION_ID,
    MERCHANT_CODE,
    CLASSIFICATION_PRODUCT,
    MERCHANT_COUNTRY,
    INTERACTION_CHANNEL,
    DATE(CREATED_DATE) AS created_date,
    IS_RESOLVING_INTERACTION
  FROM `sumup-takehometest.1234.interactions`
  where DATE_TRUNC(DATE(CREATED_DATE), MONTH) = date('2024-12-01')----limiting to Dec'24 due to data constraints explained in readme file
),

----Sequencing to get the next date of contact

sequenced AS (
  SELECT
    INTERACTION_ID,
    MERCHANT_CODE,
    CLASSIFICATION_PRODUCT,
    MERCHANT_COUNTRY,
    INTERACTION_CHANNEL,
    created_date,
    IS_RESOLVING_INTERACTION,
    LEAD(created_date) OVER (
      PARTITION BY MERCHANT_CODE, CLASSIFICATION_PRODUCT
      ORDER BY created_date, INTERACTION_ID
    ) AS next_created_date
  FROM base
),

--Calculating gaps between days of contacts for resolved interactions

anchors AS (
  SELECT
    MERCHANT_COUNTRY,
    INTERACTION_CHANNEL,
    CASE
      WHEN next_created_date IS NULL THEN NULL
      ELSE DATE_DIFF(next_created_date, created_date, DAY)
    END AS days_to_next
  FROM sequenced
  WHERE IS_RESOLVING_INTERACTION = TRUE
),

--Calculating recontact rate within 7 days for 'resolved' contacts

channel_stats AS (
  SELECT
    MERCHANT_COUNTRY,
    INTERACTION_CHANNEL,
    COUNT(*) AS resolving_interactions,
    COUNTIF(days_to_next <= 7) AS resolving_with_recontact_7d,
    SAFE_DIVIDE(COUNTIF(days_to_next <= 7), COUNT(*)) AS recontact_rate_7d
  FROM anchors
  GROUP BY MERCHANT_COUNTRY, INTERACTION_CHANNEL
)

--Ranking by lowest recontact rate for channels by merchant country

SELECT
  MERCHANT_COUNTRY,
  INTERACTION_CHANNEL,
  resolving_interactions,
  resolving_with_recontact_7d,
  recontact_rate_7d,
  DENSE_RANK() OVER (
    PARTITION BY MERCHANT_COUNTRY
    ORDER BY recontact_rate_7d ASC
  ) AS rank   -- 1 = best (lowest recontact rate)
FROM channel_stats
ORDER BY MERCHANT_COUNTRY, rank;
