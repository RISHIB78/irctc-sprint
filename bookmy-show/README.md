# BookMyShow — Part A design

This repo contains Part A deliverables: schema, concurrency strategy, cache design, and async order queue for a high-scale ticket sale under a $2,000/month AWS budget.

Docs:
- `docs/SCHEMA.md` — DDL, constraints, indexes, commentary
- `docs/CONCURRENCY.md` — hybrid Redis + Postgres strategy
- `docs/CACHE.md` — keys, TTLs, invalidation
- `docs/QUEUE.md` — async payment queue and worker logic
