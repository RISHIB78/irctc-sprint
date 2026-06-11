# Concurrency Strategy — BookMyShow Part A

## Options considered

- Option A: PostgreSQL `SELECT FOR UPDATE` row-level locking inside a transaction.
- Option B: Redis `SETNX` distributed lock for per-seat locks.

## Chosen approach: Hybrid (Redis SETNX for hot-path holds, PostgreSQL optimistic lock for final confirmation)

Reasoning (summary):
- At 500k simultaneous attempts, DB connections are a bottleneck. Redis SETNX provides sub-ms lock acquisition and scales to 100k+ ops/sec per node.
- Use Redis to guard the hot path (seat hold during user checkout). After payment completes, finalize booking using an optimistic `UPDATE seats SET status='booked', version=version+1 WHERE id=$1 AND version=$2` inside a short transaction to ensure ACID on final commit.

## Redis lock semantics
- Key: `seat_lock:{event_id}:{seat_id}`
- Value: `{lockOwner}:{timestamp}`
- Acquire: `SET key value NX EX 30` (30s TTL)
- Release: Lua script that deletes only if value matches

## PostgreSQL confirmation step (pseudo SQL)
BEGIN;
UPDATE seats SET status='booked', version=version+1
WHERE id=$1 AND version=$2 AND status='held'
RETURNING id;
-- if 0 rows returned -> conflict; release locks and notify user
COMMIT;

## Failure modes and mitigations
- Redis failure: fall back to DB `SELECT FOR UPDATE` for the seat (graceful degradation).
- Client abandons during hold: background job clears `held_until` and releases lock after TTL.

## Capacity math (when POSTFORUPDATE fails)
- With PgBouncer max_connections=500, payment calls holding connections for 0.8s, pool exhausts at much lower RPS than needed. Redis moves lock ops off DB and reduces connection pressure.
