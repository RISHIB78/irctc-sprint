# Part A — BookMyShow: Schema, Concurrency, Cache, Queue

## Peak RPS calculation
- Expected concurrent users: 500,000 (5 lakh) at T+0
- API calls per user in first 60s: 3 (view event, view seatmap, book)
- Peak RPS = (500,000 × 3) / 60 = 25,000 RPS

## Concurrency choice (one sentence)
- Chosen: Hybrid — Redis SETNX for hot-path seat holds, fallback to PostgreSQL optimistic locking for final confirmation; this gives sub-ms lock throughput at sale time while preserving DB ACID guarantees on commit.

## Cache TTL and invalidation (seat availability)
- Key: `availability:{event_id}:{category}`
- TTL: 30 seconds (cache-aside). Invalidation: immediate targeted delete on any seat status change for that event+category so the next read repopulates the accurate count.

## SQS visibility timeout
- Value: 120 seconds (2× expected max payment processing time). Rationale: prevents duplicate processing while allowing the worker enough time for payment gateway retries; messages failing after 3 receives move to DLQ for manual inspection.

## What to review in this PR
- `bookmy-show/docs/SCHEMA.md` — DDL with PKs, FKs, CHECKs, indexes
- `bookmy-show/docs/CONCURRENCY.md` — hybrid locking strategy and failure modes
- `bookmy-show/docs/CACHE.md` — keys, TTLs, invalidation flow
- `bookmy-show/docs/QUEUE.md` — SQS message format and worker behavior

Please open the PR at the provided URL and paste this description as the PR body. I pushed the branch `bookmy-show` with these docs.
