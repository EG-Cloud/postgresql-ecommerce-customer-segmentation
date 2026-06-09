-- BUSINESS ANALYSIS & CUSTOMER INSIGHTS
-- STEP 1: SEGMENT PERFORMANCE ANALYSIS (RFM)

SELECT
vrs.segment,
SUM(vst.order_value) AS turnover,
COUNT(*) AS nb_clients,
ROUND(AVG(vcf.avg_order_value), 2) AS aov

FROM view_rfm_segments vrs
INNER JOIN view_segmentation_table vst
ON vrs.customer_unique_id = vst.customer_unique_id
INNER JOIN view_customer_features vcf
ON vrs.customer_unique_id = vcf.customer_unique_id

GROUP BY vrs.segment
ORDER BY turnover DESC;

-- Business insight:
-- VIP customers are not the main revenue driver
-- High value one-shot and regular customers generate more turnover
-- Opportunity:
-- → Improve retention strategy to convert one-shot buyers into repeat customers
-- → Increase frequency among high-value users

-- STEP 2: CHURN DISTRIBUTION ANALYSIS

SELECT
customer_status,
COUNT(*) AS nb_clients,

ROUND(
    COUNT(*) * 100.0 / (SELECT COUNT(*) FROM view_churn_segments),
    2
) AS pct_segments

FROM view_churn_segments
GROUP BY customer_status;

-- Business insight:
-- Active customers are still dominant
-- However, churned and weak engagement segments are significant
-- Key objective:
-- → Reduce churn by improving post-purchase engagement and retention loops

-- STEP 3: SATISFACTION VS SEGMENT ANALYSIS

SELECT
vrs.segment,
ROUND(AVG(vres.avg_review_score), 2) AS avg_review_score,

ROUND(
    SUM(CASE WHEN vres.segment = 'Dissatisfied' THEN 1 ELSE 0 END) * 100.0
    / COUNT(*),
    2
) AS pct_dissatisfied

FROM view_rfm_segments vrs
INNER JOIN view_review_segments vres
ON vrs.customer_unique_id = vres.customer_unique_id

GROUP BY vrs.segment;

-- Strategic recommendation:
-- → Improve product quality and/or after-sales experience
-- → Target goal: reduce dissatisfaction below 10%

-- STEP 4: DELIVERY EXPERIENCE VS SATISFACTION

SELECT
ROUND(vres.avg_review_score) AS score,
AVG(vcds.delivery_delay_days) AS avg_delivery_delay

FROM view_review_segments vres
INNER JOIN view_customer_delivery_segments vcds
ON vres.customer_unique_id = vcds.customer_unique_id

WHERE vres.avg_review_score IS NOT NULL

GROUP BY ROUND(vres.avg_review_score);

-- Key implication:
-- → Delivery performance is a major driver of customer satisfaction
-- → Operational improvements in logistics can directly impact NPS / reviews