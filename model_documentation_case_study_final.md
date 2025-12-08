# Model & Column Documentation

## Table: `sumup-takehometest.1234.interactions`

**Grain:**  
1 row = 1 interaction (merchant → Support) via email, call or chat.

---

## Core Identifiers

### INTERACTION_ID
- Type: string / integer
- Description: Unique identifier for the interaction.
- Usage: Primary key for the table and tie-breaker in window functions.

### MERCHANT_CODE
- Type: string
- Description: Identifier of the merchant account.
- Usage: Grouping key for merchant-level KPIs, repeat-contact analysis and segmentation.
- Data issue: For chat, merchant codes are effectively collapsed (1–5 merchants per month) until Dec 2024.

---

## Agent / Provider Dimensions

### AGENT_ID
- Type: string
- Description: Identifier of the individual agent handling the interaction.
- Usage: Potential for agent-level KPIs (not central to this case study).

### AGENT_COMPANY
- Type: string
- Typical values: `COMPANY_1`, `COMPANY_2`, `COMPANY_3`
- Description: Employer / BPO provider of the agent.
- Usage: Comparison of provider performance (Q3).

---

## Merchant Dimensions

### MERCHANT_COUNTRY
- Type: string
- Values: `BE`, `CH`, `IE`, `NL`
- Description: Country of the merchant.
- Usage: Country-level comparisons (Q2) and segmentation.

### MCC_GROUP
- Type: string (nullable)
- Description: Grouped Merchant Category Code describing the merchant’s business type.
- Usage: Potential segmentation for future analysis.
- Data issue: ~18–20% nulls earlier in 2024; quality improves significantly in Nov–Dec, especially for chat.

---

## Channel & Product

### INTERACTION_CHANNEL
- Type: string
- Values: `email`, `call`, `chat`
- Description: Channel through which the merchant contacted Support.
- Usage: Central dimension in assessing channel performance and costs (Q2, Q5).

### CLASSIFICATION_PRODUCT
- Type: string
- Example values: `profile`, `hardware`, `banking`, `online payments`, `misc`, etc.
- Description: Product/topic classification for the interaction.
- Usage: Used as the “reason” for repeat-contact analysis (same merchant and product) and product-level performance metrics (Q1, Q4).

---

## Time Fields

### CREATED_DATE
- Type: datetime / timestamp
- Description: Time when the interaction was created.
- Usage:
  - Converted to `DATE(CREATED_DATE)` and `DATE_TRUNC(..., MONTH)` for ordering and monthly aggregations.
  - Used in window functions to determine time until next interaction for the same merchant and product.

### Derived: created_date
- Definition: `DATE(CREATED_DATE)`
- Usage: Simplifies ordering and date arithmetic (e.g. `DATE_DIFF`).

### Derived: month
- Definition: `DATE_TRUNC(DATE(CREATED_DATE), MONTH)`
- Usage: Monthly aggregations and sanity checks.

---

## Resolution & Status

### IS_RESOLVING_INTERACTION
- Type: boolean
- Description: Flag set by the agent to indicate that this interaction resolves the issue.
- Usage:
  - Used to filter “resolving” interactions which act as anchors in recontact analyses.
  - Combined with recontact logic to derive an analytical resolution metric.
- Data note: The overall share of interactions flagged as resolving decreases over 2024; for chat it drops from nearly 100% to ~53% in Dec, indicating behavioural or policy changes.

---

## Time-to-Serve Metrics

### INTERACTION_RESPONSE_TIME
- Type: numeric (nullable, assumed seconds)
- Description: Time from interaction creation to first agent response.
- Usage: SLA-type metrics (not central to core case questions but useful for service speed analysis).
- Data issue: For chat, this field is mostly null until around August 2024; from Aug–Dec it is fully populated.

### INTERACTION_HANDLING_TIME
- Type: numeric (nullable, assumed seconds)
- Description: Duration the agent spent handling the interaction.
- Usage:
  - Main cost driver in Q5 (channel cost allocation).
  - Could be used to analyse productivity and case complexity.
- Data issue: Contains extreme outliers (especially for email), with some tickets open for several days; for cost analysis, I cap the value at the 95th percentile per channel.

---

## Derived Metrics Used in SQL

The following fields are not stored in the table but are computed in queries:

### next_created_date
- Definition:
  ```sql
  LEAD(created_date) OVER (
    PARTITION BY MERCHANT_CODE, CLASSIFICATION_PRODUCT
    ORDER BY created_date, INTERACTION_ID
  )
  ```
- Description: Date of the **next interaction** for the same merchant and product.
- Usage: Identify recontacts and compute time to next contact.

### days_to_next
- Definition: `DATE_DIFF(next_created_date, created_date, DAY)`
- Description: Number of days between an interaction and the next same‑product interaction for that merchant.
- Usage: Underpins recontact rate calculations (1/3/7/10/14/30 days).

### Recontact flags
- Examples:
  - `days_to_next <= 7` (recontact within 7 days)
  - `days_to_next <= 10` (recontact within 10 days)
- Usage: Compute recontact rates per channel, product, provider and country.

### recontact_rate_7d
- Definition: share of resolving interactions with `days_to_next <= 7`.
- Usage: Main quality metric in Q2 and Q3; lower values indicate better first-contact resolution.

### handling_time_capped
- Definition:
  - For each channel, compute p95:
    ```sql
    p95 = APPROX_QUANTILES(INTERACTION_HANDLING_TIME, 100)[OFFSET(95)]
    ```
  - Then: `handling_time_capped = LEAST(INTERACTION_HANDLING_TIME, p95)`
- Usage: Outlier-robust cost driver in Q5.

### effective_agent_hours
- Definition:
  ```sql
  CASE
    WHEN INTERACTION_CHANNEL = 'chat'
      THEN total_handling_sec / 3600.0 / 3.0   -- 3 chats in parallel
    ELSE total_handling_sec / 3600.0           -- calls/email at 1×
  END
  ```
- Description: Approximation of the agent working hours needed per channel, adjusted for concurrency.
- Usage: Allocate the monthly Support budget across channels proportionally to effective hours.

### cost_per_interaction
- Definition:
  ```sql
  allocated_cost / interactions
  ```
- Description: Estimated cost per interaction per channel, given a total monthly budget.
- Usage: Compare economic efficiency between email, call and chat (Q5).
