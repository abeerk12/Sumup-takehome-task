# Sumup-takehome-task
Analytics case study for SumUp: scalable data models, SQL, and documentation to evaluate customer support performance, channel and vendor efficiency, repeat contacts, and cost per channel, plus recommendations and a quarterly performance framework.

# Operations Analytics Lead – Case Study (Merchant Care Europe)

This repo contains my solution for an Operations Analytics Lead case study on Merchant Support in Europe. The aim is to understand channel / provider performance, repeat contacts and cost per interaction, and to propose a 2024 channel strategy and performance framework.

---

## 1. Repo Structure

```text
.
├── README.md
├── model_documentation.md          # Column & derived field documentation
├── sql/
│   ├── q0_monthly_sanity_check.sql
│   ├── q0_channel_mix_by_month.sql
│   ├── q1_resolution_window_option_a_all_anchors.sql
│   ├── q1_resolution_window_option_b_resolving_anchors.sql
│   ├── q2_channel_performance_by_country.sql
│   ├── q3_agent_company_performance.sql
│   ├── q4_merchant_repeat_contacts.sql
│   ├── q4_product_recontacts.sql
│   └── q5_channel_costs_p95_capped_dec2024.sql
├── slides/
│   └── operations_analytics_case_study_deck_v2.pptx
└── docs/
    └── merchant_care_written_answers_v2.docx


Source table: sumup-takehometest.1234.interactions (1 row = 1 merchant → Support interaction via email/call/chat).

**2. Key Assumptions**

Time fields (INTERACTION_RESPONSE_TIME, INTERACTION_HANDLING_TIME) are in seconds.

A case is analytically resolved if IS_RESOLVING_INTERACTION = TRUE and there is no same-merchant + same-product recontact within 7–10 days.

I assume a notional monthly Support budget of €500k, allocated by effective handling hours per channel.

Chat concurrency = 3 (agents handle 3 chats in parallel), email/call = 1:1.

For cost modelling I cap handling time at p95 per channel to avoid a few extreme tickets driving cost.

Due to data issues (see below), some analyses – especially cost and chat at merchant level – are limited to December 2024.

**3. Data Issues Found**

From monthly sanity checks (q0_*):

Chat merchant IDs broken in Jan–Nov 2024: thousands of chat interactions but only 1–5 distinct MERCHANT_CODEs per month. Dec 2024 finally shows a realistic merchant distribution.

Chat time fields incomplete earlier in the year: INTERACTION_RESPONSE_TIME and INTERACTION_HANDLING_TIME are mostly null for chat until ~Aug 2024, then become well populated.

MCC_GROUP completeness improves in Nov–Dec: earlier months have ~18–20% null; this drops sharply in Nov–Dec, especially for chat.

Resolution flag drift: share of interactions flagged as resolving drops over time (for chat from ~100% to ~53%), so I rely more on the recontact-based analytical definition than on the raw flag alone.

Because of this, Dec 2024 is used as the cleanest month for detailed channel and cost views.

**4. Design & Implementation (by Question)**
Q1 – Resolution window

Files: q1_resolution_window_option_a_all_anchors.sql, q1_resolution_window_option_b_resolving_anchors.sql.

For each merchant + product, I compute next_created_date (via LEAD) and days_to_next, then measure what % of recontacts fall within 1/3/7/10/14/30 days.

Option A uses all interactions as anchors; Option B uses only resolving interactions as anchors. This supports choosing a 7–10 day resolution window.

Q2 – Channel performance by country

File: q2_channel_performance_by_country.sql.

Resolving interactions are anchors; I compute 7-day recontact rate per MERCHANT_COUNTRY × INTERACTION_CHANNEL and rank channels per country (best = lowest recontact rate, worst = highest).

Q3 – Agent company performance

File: q3_agent_company_performance.sql.

Same anchor logic, grouped by AGENT_COMPANY. I compute 7-day recontact rate and rank providers to identify best/worst performers.

Q4 – Merchant repeat contacts & products

Files: q4_merchant_repeat_contacts.sql, q4_product_recontacts.sql.

At merchant level: distribution of contacts per merchant (2+, 5+, 10+).

At product level: share of merchants with 2+ contacts by CLASSIFICATION_PRODUCT to find high repeat-contact products.

Q5 – Channel cost allocation (Dec 2024, p95-capped)

File: q5_channel_costs_p95_capped_dec2024.sql.

Restricted to Dec 2024 with non-null handling time.

I cap handling time at p95 per channel, convert to effective agent hours (chat/3), allocate €500k by share of hours, and compute cost per interaction by channel.

This is used for relative economics (email vs call vs chat), not as an exact cost benchmark.

**5. How I Assessed Performance**

I combine three lenses:

**Quality – Did we fix the issue?**

Main metric: 7-day recontact rate on resolving interactions (same merchant + product).

Lower recontact = better first-contact resolution.

Used consistently for channels (Q2) and providers (Q3), and informed by Q1/Q4.

**Demand – Where is the work and pain?**

Volumes by channel / country / provider / product and contacts per merchant/product.

High-volume + high-recontact products are flagged as priority areas for self-service, product improvements, and training.

**Cost & efficiency – How expensive is each channel?**

Based on effective handling hours and a simple €500k monthly budget allocation.

I look at relative cost per interaction (email vs call vs chat) after capping outliers and adjusting for chat concurrency.

Recommendations in the slides and written answers come from the intersection of these three: channels and providers that are high quality, handle a meaningful share of demand, and are cost-efficient are favoured; those that are low quality and high cost are targeted for redesign or de-prioritisation.

**6. How to Run**

Ensure the table sumup-takehometest.1234.interactions exists in your BigQuery project.

Open the BigQuery console and run the SQL files from the sql/ folder.

Suggested order:

q0_* → sanity checks

q1_* → resolution window

q2, q3 → channel & provider performance

q4_* → repeat contacts & products

q5_* → cost per interaction (Dec 2024)
