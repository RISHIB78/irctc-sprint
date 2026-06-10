# FAILURE CASCADE — Swiggy-like World Cup Promo

## Summary
- Event: 50% promo pushed to 180M users. Concentrated spike window: 60s.
- Active users (8% CTR): 14,400,000. Scenario simplified to 10,000,000 concurrent users in documentation sections below.

## Peak RPS calculation
- Active users clicking: 10,000,000 (conservative scenario)
- API calls per user in first 60s: 3 (GET /restaurants, GET /restaurant/:id, POST /orders)
- Peak RPS = (10,000,000 × 3) / 60 = 500,000 RPS

## Component capacity numbers (monolith)
- PostgreSQL max_connections = 100 (configured)
- Node.js monolith event-loop practical limit ≈ 12,000 RPS (t3.medium-like instance)
- Payment hold time per request: 200–2000 ms (avg 800 ms)
- Average DB query time (menu/read): 20 ms

## DB pool exhaustion math (example)
- Let p = proportion of requests that make synchronous payment calls. Assume p = 0.30.
- Connections held ≈ (1 - p) * RPS * query_time_s + p * RPS * payment_hold_time_s
- Solve for RPS when connections held = 100 (pool size)
- Using query_time_s = 0.020, payment_hold_time_s = 0.8:
  connections = 0.7*RPS*0.02 + 0.3*RPS*0.8 = RPS*(0.014 + 0.24) = RPS*0.254
  Pool exhaust when RPS = 100 / 0.254 ≈ 393 RPS

Conclusion: with these parameters, ~400 RPS exhausts the DB pool — far below the 500K RPS demand.

## Failure cascade (triggers and effects)

1) PostgreSQL connection pool exhaustion — CRITICAL
- Trigger: ~400 RPS (see math above)
- User-visible: new requests error with DB connection errors; 5xx spikes
- Causes: node request queueing, event-loop backlog, downstream OOM

2) Node.js event-loop saturation — CRITICAL
- Trigger: ~12,000 RPS sustained on single instance
- User-visible: response latency increases (50ms → seconds), timeouts
- Causes: memory pressure, process crash (OOM) → whole app down

3) Synchronous payment amplification — HIGH
- Trigger: payment calls holding DB connections (avg 800ms) amplify connection usage
- User-visible: orders slow, many failures; payment gateway timeouts
- Causes: holds DB connections and increases time to exhaustion

4) Promo code race condition (TOCTOU) — HIGH
- Trigger: concurrent SELECT then UPDATE without atomicity
- User-visible: promo budget overspent; many users get a valid response though budget exhausted
- Causes: incorrect business results, revenue loss

5) Static asset NIC saturation (no CDN) — HIGH
- Trigger: large number of image downloads (10M users × 20 images × 200KB ≈ 40TB)
- User-visible: static content slows origin, API requests starve
- Causes: network saturation, upstreams failing

## Timeline (T+0 → T+2h)
- T+0s: Push notification sent to 180M users
- T+3s: DB pool saturates (100/100) — many DB errors
- T+5s: Node.js event loop backs up; response times rise to 500ms
- T+8s: New DB connections rejected; API 5xx increases sharply
- T+10s: Payment gateway calls begin timing out; queued payments accumulate
- T+12s: Promo race causes budget inconsistencies; oversold promos reported
- T+15s: NIC saturated by static traffic; API largely unreachable
- T+18s: Node process crashes with OOM; instance removed by LB health checks
- T+45m: On-call identifies primary failures and starts mitigation
- T+2h: System restored to stable state; postmortem initiated

## Short recommendations (from analysis)
- Add CDN for static assets immediately
- Add Redis cache for menu/restaurant list and promo locking
- Move synchronous payments to an async worker queue
- Introduce PgBouncer or similar connection pooler
- Add read replicas for heavy read queries (order history, menus)