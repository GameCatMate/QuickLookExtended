-- Sample query for Quick Look preview
WITH recent_events AS (
    SELECT
        service_name,
        count(*) AS total_events,
        sum(CASE WHEN severity = 'error' THEN 1 ELSE 0 END) AS errors
    FROM telemetry_events
    WHERE created_at >= now() - interval '1 hour'
    GROUP BY service_name
)
SELECT
    service_name,
    total_events,
    errors,
    round(errors * 100.0 / nullif(total_events, 0), 2) AS error_rate
FROM recent_events
WHERE total_events > 10
ORDER BY error_rate DESC, total_events DESC;
