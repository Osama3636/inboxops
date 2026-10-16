-- InboxOps helper views. Run after 01_schema.sql.

-- Runs, outcomes, and cost per day
CREATE OR REPLACE VIEW v_daily_summary AS
SELECT
    created_at::date                                        AS day,
    count(*)                                                AS runs,
    count(*) FILTER (WHERE status = 'executed')             AS executed,
    count(*) FILTER (WHERE status = 'failed')               AS failed,
    count(*) FILTER (WHERE status = 'needs_review')         AS needs_review,
    round(100.0 * count(*) FILTER (WHERE status = 'executed')
          / NULLIF(count(*) FILTER (WHERE status IN ('executed', 'failed')), 0), 1)
                                                            AS success_rate_pct,
    round(avg(cost_usd), 6)                                 AS avg_cost_usd,
    round(sum(cost_usd), 6)                                 AS total_cost_usd
FROM agent_runs
GROUP BY 1
ORDER BY 1 DESC;

-- Approval behaviour per day
CREATE OR REPLACE VIEW v_approval_summary AS
SELECT
    sent_at::date                                           AS day,
    count(*)                                                AS requests,
    count(*) FILTER (WHERE state = 'approved')              AS approved,
    count(*) FILTER (WHERE state = 'rejected')              AS rejected,
    count(*) FILTER (WHERE state = 'expired')               AS expired,
    round(100.0 * count(*) FILTER (WHERE state = 'approved')
          / NULLIF(count(*) FILTER (WHERE state <> 'pending'), 0), 1)
                                                            AS approval_rate_pct,
    round(avg(extract(epoch FROM (decided_at - sent_at)) / 60)
          FILTER (WHERE state IN ('approved', 'rejected')), 1)
                                                            AS avg_minutes_to_decision
FROM approvals
GROUP BY 1
ORDER BY 1 DESC;

-- Headline numbers for each evaluation batch (paste into the README)
CREATE OR REPLACE VIEW v_eval_summary AS
SELECT
    batch,
    model,
    count(*)                                                AS cases,
    round(100.0 * count(*) FILTER (WHERE category_correct) / count(*), 1)
                                                            AS category_accuracy_pct,
    round(avg(latency_ms))                                  AS avg_latency_ms,
    round(avg(cost_usd), 6)                                 AS avg_cost_usd,
    count(*) FILTER (WHERE schema_valid = false)            AS schema_failures,
    count(*) FILTER (WHERE is_adversarial)                  AS adversarial_cases,
    count(*) FILTER (WHERE is_adversarial AND safe_handling) AS adversarial_safe
FROM eval_results
GROUP BY batch, model
ORDER BY batch DESC;

-- Per-field extraction accuracy for each evaluation batch
CREATE OR REPLACE VIEW v_eval_field_accuracy AS
SELECT
    e.batch,
    f.key                                                   AS field,
    count(*)                                                AS checked,
    count(*) FILTER (WHERE f.value = 'true')                AS correct,
    round(100.0 * count(*) FILTER (WHERE f.value = 'true') / count(*), 1)
                                                            AS accuracy_pct
FROM eval_results e,
     jsonb_each_text(e.field_scores) AS f(key, value)
WHERE e.field_scores IS NOT NULL
GROUP BY e.batch, f.key
ORDER BY e.batch DESC, f.key;

CREATE OR REPLACE VIEW v_stuck_runs AS
SELECT id, status, category, created_at
FROM agent_runs
WHERE status IN ('started', 'classified', 'executing')
  AND created_at < now() - interval '30 minutes'
  AND COALESCE(message_id, '') NOT LIKE 'eval-%';