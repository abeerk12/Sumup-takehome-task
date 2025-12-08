-- Q4 – What percentage of merchants contacted multiple times, and which products were most frequently recontacted?

-- Merchant × product pairs and their interaction counts.

--Base

WITH merchant_product AS (
  SELECT
    MERCHANT_CODE,
    CLASSIFICATION_PRODUCT,
    MCC_GROUP,
    COUNT(*) AS interaction_count
  FROM `sumup-takehometest.1234.interactions`
  where DATE_TRUNC(DATE(CREATED_DATE), MONTH) = date('2024-12-01')
  GROUP BY MERCHANT_CODE, CLASSIFICATION_PRODUCT, MCC_GROUP
),

--Aggregated by product

product_agg AS (
  SELECT
    CLASSIFICATION_PRODUCT,
    MCC_GROUP,
    COUNT(*) AS merchants_on_product,
    COUNTIF(interaction_count >= 2) AS merchants_with_2plus_contacts,
    SAFE_DIVIDE(COUNTIF(interaction_count >= 2), COUNT(*)) AS recontact_rate
  FROM merchant_product
  GROUP BY CLASSIFICATION_PRODUCT, MCC_GROUP
)

--Summarized contacts by Merchants and products

SELECT
  CLASSIFICATION_PRODUCT,
  MCC_GROUP,
  merchants_on_product,
  merchants_with_2plus_contacts,
  recontact_rate
FROM product_agg
ORDER BY merchants_with_2plus_contacts DESC;
