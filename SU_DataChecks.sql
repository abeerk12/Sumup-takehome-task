-- Monthly sanity check for interactions dataset

WITH base AS (
  SELECT
    DATE_TRUNC(DATE(CREATED_DATE), MONTH) AS month,
    INTERACTION_ID,
    MERCHANT_CODE,
    CLASSIFICATION_PRODUCT,
    MERCHANT_COUNTRY,
    INTERACTION_CHANNEL,
    AGENT_COMPANY,
    IS_RESOLVING_INTERACTION,
    MCC_GROUP,
    INTERACTION_RESPONSE_TIME,
    INTERACTION_HANDLING_TIME
  FROM `sumup-takehometest.1234.interactions`
)
, grouped as
(SELECT
  month,
  merchant_country,
  interaction_channel,
  COUNT(*) AS total_interactions,
  COUNT(DISTINCT MERCHANT_CODE) AS distinct_merchants,
  COUNT(DISTINCT CLASSIFICATION_PRODUCT) AS distinct_products,
  COUNT(DISTINCT MERCHANT_COUNTRY) AS distinct_countries,
  COUNT(DISTINCT INTERACTION_CHANNEL) AS distinct_channels,
  COUNT(DISTINCT AGENT_COMPANY) AS distinct_agent_companies,

  -- Share of interactions marked as resolving
  AVG(CASE WHEN IS_RESOLVING_INTERACTION THEN 1 ELSE 0 END) AS resolving_share,

  -- Null shares for key fields
  AVG(CASE WHEN MCC_GROUP IS NULL THEN 1 ELSE 0 END) AS mcc_null_share,
  AVG(CASE WHEN INTERACTION_RESPONSE_TIME IS NULL THEN 1 ELSE 0 END) AS resp_time_null_share,
  AVG(CASE WHEN INTERACTION_HANDLING_TIME IS NULL THEN 1 ELSE 0 END) AS handle_time_null_share

FROM base
--where interaction_channel = 'chat'
GROUP BY 1,2,3
ORDER BY 1,2,3)

select * from grouped where handle_time_null_share <>1;--similar checks for more suspicious fields like merchant counts, etc.

--sanity checks to see if email handling times are longer than call handling times 
-- SELECT
--   INTERACTION_CHANNEL,
--   AVG(INTERACTION_HANDLING_TIME) AS avg_ht,
--   APPROX_QUANTILES(INTERACTION_HANDLING_TIME, 5) AS ht_quartiles
-- FROM resolution_window
-- GROUP BY INTERACTION_CHANNEL;


--Findings:
-- * I limit the deeper analysis to **December 2024** because it is the only month where chat has a realistic number of distinct merchants, plus mostly complete handling/response times and MCC groups.
-- * In earlier months, chat merchant codes are essentially collapsed (1–5 merchants for thousands of chats) and key time fields/MCC are largely missing, which would bias recontact and cost metrics.
-- * December still has all channels, countries and providers active, so it gives the **cleanest and most representative snapshot** under these data constraints.
