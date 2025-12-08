# Operations Analytics Lead – Case Study (Merchant Care Europe)

This repo contains my solution for an Operations Analytics Lead case study on Merchant Support in Europe. The aim is to understand channel / provider performance, repeat contacts and cost per interaction, and to propose a 2024 channel strategy and performance framework.

## Repo Structure, Key Assumptions, Data issues, implementation and design, insights.

1. Repo Structure

```text
.
├── README.md
├── model_documentation.md          # Column & derived field documentation
├── sql/
│   ├── SU_DataChecks.sql
│   ├── SU_Q1_resolutionwindow.sql
│   ├── SU_Q2_channelperformancebycountry.sql
│   ├── SU_Q3_agentcompanyperformance.sql
│   ├── SU_Q4_merchantrepeatcontacts.sql
│   ├── SU_Q5_costallocation.sql
├── slides/
│   └── operations_analytics_case_study_deck_v2.pptx
└── docs/
    └── merchant_care_written_answers_v2.docx

Source table: sumup-takehometest.1234.interactions (1 row = 1 merchant → Support interaction via email/call/chat).

2. Key Assumptions

1. Time fields (INTERACTION_RESPONSE_TIME, INTERACTION_HANDLING_TIME) are in seconds.
2. A case is analytically resolved if IS_RESOLVING_INTERACTION = TRUE and there is no same-merchant + same-product recontact within 7–10 days.
3. I assume a notional monthly Support budget of €500k, allocated by effective handling hours per channel, excluding other agent costs like training/coaching, etc.
4. Chat concurrency = 3 (agents handle 3 chats in parallel), email/call = 1:1.
5. For cost modelling I cap handling time at p95 per channel to avoid a few extreme tickets driving cost.
6. Due to data issues (see below), some analyses – especially cost and chat at merchant level – are limited to December 2024.

3. Data Issues Found

From monthly sanity checks (SU_DataChecks.sql):
1. Chat merchant IDs broken in Jan–Nov 2024: thousands of chat interactions but only 1–5 distinct MERCHANT_CODEs per month. Dec 2024 finally shows a realistic merchant distribution.
2. Chat time fields incomplete earlier in the year: INTERACTION_RESPONSE_TIME and INTERACTION_HANDLING_TIME are mostly null for chat until ~Aug 2024, then become well populated.
3. MCC_GROUP completeness improves in Nov–Dec: earlier months have ~18–20% null; this drops sharply in Nov–Dec, especially for chat.
4. Resolution flag drift: share of interactions flagged as resolving drops over time (for chat from ~100% to ~53%), so I rely more on the recontact-based analytical definition than on the raw flag alone.

Suggestions for more data points for a holistic performance:
1. Interaction date timestamp
2. Additional data like NPS, CSAT, follow up contact relation(if a contact was made in relation with a previous contact, so we have another field for the original interaction ID)
3. Reason codes/inputs from agents

**Because of this, Dec 2024 is used as the cleanest month for detailed channel and cost views.**

4. Design, Implementation and insights (by Question)
Q1 – Resolution window
Files: SU_Q1_resolutionwindow.sql
For each merchant + product, I compute next_created_date (via LEAD) and days_to_next, then measure what % of recontacts fall within 1/3/7/10/14/30 days.
Code uses only resolving interactions as anchors. 
I used recontact patterns by merchant + product to see when “resolved” cases actually come back. Most recontacts cluster in the first 3–7 days, and the curve flattens after ~10 days, so a 7–10 day window balances catching true non-resolution without punishing normal future contacts.

Q2 – Channel performance by country
File: SU_Q2_channelperformancebycountry.sql
Resolving interactions are anchors; I compute 7-day recontact rate per MERCHANT_COUNTRY × INTERACTION_CHANNEL and rank channels per country (best = lowest recontact rate, worst = highest).
Channel performance is defined via 7-day recontact rate on resolving interactions: if a merchant comes back quickly for the same product, the first contact probably didn’t fully solve the issue. Comparing this rate by channel (and country) gives a fair view of first-contact resolution quality, independent of volume, and “best/worst” are simply the lowest vs highest recontact rates.

Q3 – Agent company performance
File: SU_Q3_agentcompanyperformance.sql
Same anchor logic, grouped by AGENT_COMPANY. I compute 7-day recontact rate and rank providers to identify best/worst performers.
To compare providers, I apply the same resolution metric (7-day recontact on resolving interactions), but grouped by AGENT_COMPANY. This keeps the definition of “good” consistent across channels and countries, and lets us rank providers on something directly tied to merchant experience rather than just speed or volume.

Q4 – Merchant repeat contacts & products
Files: SU_Q4_merchantrepeatcontacts.sql
At merchant level: distribution of contacts per merchant (2+, 5+, 10+).
At product level: share of merchants with 2+ contacts by CLASSIFICATION_PRODUCT to find high repeat-contact products.
I look at how many times each merchant contacts Support overall, and for each merchant × product pair, how often they come back (2+ contacts). Products with a high share of repeat-contact merchants are flagged as structural pain points, making them clear candidates for self-service, UX changes or process fixes.

Q5 – Channel cost allocation (Dec 2024, p95-capped)
File: SU_Q5_costallocation.sql
Restricted to Dec 2024 with non-null handling time.
I cap handling time at p95 per channel, convert to effective agent hours (chat/3), allocate €500k by share of hours, and compute cost per interaction by channel.
This is used for relative economics (email vs call vs chat), not as an exact cost benchmark.
I treat (capped) handling time as a proxy for labour cost, adjust for chat concurrency (3 in parallel), and allocate a notional €500k monthly budget by each channel’s share of effective agent hours. This gives a simple but robust view of relative cost per interaction (email vs call vs chat), especially once we cap extreme outliers so a few abnormal email tickets don’t distort the economics.

**5. How I Assessed Performance**
I combine three lenses:
Quality – Did we fix the issue?
Main metric: 7-day recontact rate on resolving interactions (same merchant + product).
Lower recontact = better first-contact resolution.
Used consistently for channels (Q2) and providers (Q3), and informed by Q1/Q4.

Demand – Where is the work and pain?
Volumes by channel / country / provider / product and contacts per merchant/product.
High-volume + high-recontact products are flagged as priority areas for self-service, product improvements, and training.

Cost & efficiency – How expensive is each channel?
Based on effective handling hours and a simple €500k monthly budget allocation.
I look at relative cost per interaction (email vs call vs chat) after capping outliers and adjusting for chat concurrency.

Recommendations in the slides and written answers come from the intersection of these three: channels and providers that are high quality, handle a meaningful share of demand, and are cost-efficient are favoured; those that are low quality and high cost are targeted for redesign or de-prioritisation.

6. How to Run
Ensure the table sumup-takehometest.1234.interactions exists in your BigQuery project.
Open the BigQuery console and run the SQL files from the sql/ folder.
