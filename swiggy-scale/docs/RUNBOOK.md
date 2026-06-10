# INCIDENT RUNBOOK — Swiggy-scale (Junior engineer friendly)

## STEP 1 — Detect (alerts)
Minimum alarms:
- `ALB_5XX_RATE > 5%` for 2 minutes → Critical
- `RDS_DBConnections > 80%` of max_connections → Warning
- `EC2_CPU > 80%` across >50% instances for 3 minutes → Warning
- `Redis_MemoryUtil > 75%` → Warning
- `SQS_ApproximateNumberOfMessages > 10,000` → Warning
- `P99_RESPONSE_TIME > 2s` → Critical

## STEP 2 — Triage (30s decision tree)
1) Check RDS DBConnections. If >80% → go to 3a (DB pool exhaustion).
2) Else check SQS depth. If >10k → go to 3d (payment worker backlog).
3) Else check ALB 5xx rate. If >5% → look at EC2 CPU/health.
4) Else check Redis miss rate. If miss rate >50% → go to 3c (cache invalidation).

## STEP 3 — Respond (component-specific)

3a) DB pool exhaustion
- Action:
  - Scale read replicas and increase PgBouncer pool temporarily.
  - Identify long-held connections: `SELECT pid, state, query, age(clock_timestamp(), query_start) FROM pg_stat_activity ORDER BY age DESC LIMIT 20;`
  - If payment calls are holding connections, disable promo workers and pause inbound writes via feature flag.
- Success: `RDS_DBConnections` drops <70% within 60s. 5xx rate trending down.
- Owner: DB on-call (Slack: #oncall-db)

3b) Node.js compute saturation
- Action:
  - Trigger immediate scale-up: increase desired capacity in ASG or start replacement instances.
  - If OOM observed, rotate instances using ALB: `aws autoscaling set-desired-capacity --auto-scaling-group-name api-asg --desired-capacity N`
- Success: P99 latency drops under 1s and CPU reduces below 70% in 2–5 minutes.
- Owner: Platform on-call (#oncall-platform)

3c) Redis cache miss spike
- Action:
  - Check eviction metrics and keys: `redis-cli INFO memory` and `redis-cli --scan | wc -l`.
  - If invalidation mass happened, revert recent deploys that cleared keys or restore warm cache from snapshot.
- Success: Cache hit rate >80% and DB connections reduce.
- Owner: Backend on-call (#oncall-backend)

3d) Payment queue backlog
- Action:
  - Verify payment worker logs, scale payment workers.
  - If workers crashed, restart: `systemctl restart payment-worker` or scale up ECS service.
- Success: SQS depth drops steadily; error rate on payments falls.
- Owner: Payments team (#oncall-payments)

## STEP 4 — Rollback
- Criteria: 5xx rate >20% and no improvement for 5 minutes AND no active deploy in last 2 hours.
- Command (example ECS):
```
aws ecs update-service --cluster swift-prod --service api --task-definition api:PREVIOUS_STABLE
```
- Warning: Do NOT rollback DB schema changes without consultation.

## STEP 5 — Postmortem template
- Timeline: ordered list of events with CloudWatch timestamps
- Root cause: concise single-sentence cause
- Impact: duration, users affected, estimated financial loss
- Actions: numbered list, owner, due date
- Verification: how to validate each action is complete
