-- Q5 – Associate costs with each channel (with outlier treatment)
-- Approach:
--   1. Use INTERACTION_HANDLING_TIME as cost driver.
--   2. Cap handling time per channel at the 95th percentile to reduce impact of extreme outliers.
--   3. Adjust for concurrency (chat = 3 in parallel).
--   4. Allocate €0.5M monthly budget by share of effective agent hours.
--   5. Compute cost per interaction.


-- 1) Base data for Dec 2024
WITH base AS (
  SELECT
    DATE_TRUNC(DATE(CREATED_DATE), MONTH) AS month,
    INTERACTION_CHANNEL,
    INTERACTION_HANDLING_TIME
  FROM `sumup-takehometest.1234.interactions`
  WHERE INTERACTION_HANDLING_TIME IS NOT NULL
    AND DATE_TRUNC(DATE(CREATED_DATE), MONTH) = DATE '2024-12-01'
),

-- 2) Compute 95th percentile handling time per channel
pctl AS (
  SELECT
    INTERACTION_CHANNEL,
    APPROX_QUANTILES(INTERACTION_HANDLING_TIME, 100)[OFFSET(95)] AS p95_handling_time
  FROM base
  GROUP BY INTERACTION_CHANNEL
),

-- 3) Cap handling time at p95 per channel
capped AS (
  SELECT
    b.month,
    b.INTERACTION_CHANNEL,
    LEAST(b.INTERACTION_HANDLING_TIME, p.p95_handling_time) AS handling_time_capped
  FROM base b
  JOIN pctl p
    USING (INTERACTION_CHANNEL)
),

-- 4) Aggregate by channel and month using capped handling time
by_channel_month AS (
  SELECT
    month,
    INTERACTION_CHANNEL,
    COUNT(*) AS interactions,
    SUM(handling_time_capped) AS total_handling_sec,
    AVG(handling_time_capped) AS avg_handling_sec
  FROM capped
  GROUP BY month, INTERACTION_CHANNEL
),

-- 5) Convert to effective agent hours (chat concurrency)
with_eff AS (
  SELECT
    month,
    INTERACTION_CHANNEL,
    interactions,
    total_handling_sec,
    avg_handling_sec,
    CASE
      WHEN INTERACTION_CHANNEL = 'chat'
        THEN total_handling_sec / 3600.0 / 3.0   -- 3 chats in parallel
      ELSE total_handling_sec / 3600.0           -- 1× for call/email
    END AS eff_agent_hours
  FROM by_channel_month
),

-- 6) Total effective hours per month
tot AS (
  SELECT
    month,
    SUM(eff_agent_hours) AS total_eff_hours
  FROM with_eff
  GROUP BY month
)

-- 7) Final allocation and cost per interaction
SELECT
  c.month,
  c.INTERACTION_CHANNEL,
  c.interactions,
  c.total_handling_sec,
  c.avg_handling_sec,
  c.eff_agent_hours,
  c.eff_agent_hours / t.total_eff_hours AS share_of_eff_hours,
  (c.eff_agent_hours / t.total_eff_hours) * 500000 AS allocated_cost,
  ((c.eff_agent_hours / t.total_eff_hours) * 500000) / c.interactions AS cost_per_interaction
FROM with_eff c
JOIN tot t
  ON c.month = t.month
ORDER BY c.month, cost_per_interaction DESC;
