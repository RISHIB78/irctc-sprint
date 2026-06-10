# ARCHITECTURE — Current and Redesigned

## Current architecture (monolith)

Internet
    │
    ▼
┌──────────────────────────────────────┐
│  Single Node.js Express Server        │  ← ⚠️ SPOF: single process (Part: FAILURE 2)
│  - Routes + Business Logic + DB       │  ← ⚠️ N+1 queries and no cache (Part: FAILURE 1)
│  - No CDN, no Redis, no pgbouncer     │  ← ⚠️ NIC saturation & DB pool issues (FAILURE 5)
└──────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────┐
│  Single PostgreSQL Instance           │  ← ⚠️ max_connections = 100 (FAILURE 1)
│  - Reads and writes on same server    │  ← ⚠️ Read/write contention (FAILURE 3)
└──────────────────────────────────────┘

## Redesigned architecture (for 10M spike)

Internet
   │
   ▼
┌─────────────────────────┐
│ CloudFront CDN          │  ← static assets + images cached at edge
└─────────────────────────┘
   │ (dynamic API traffic)
   ▼
┌─────────────────────────┐
│ Application Load Balancer│  ← SSL termination, health checks, rate limiting
└─────────────────────────┘
   │   │   │
   ▼   ▼   ▼
┌────┐┌────┐┌────┐        ← 4–20 stateless Node.js app instances (auto-scale)
│App1││App2││App3│
└────┘└────┘└────┘
   │   │   │
   └───┴───┘
       ▼
┌─────────────────────────┐
│ Redis Cluster           │  ← cache for menus, X-Cache header, promo locks (SETNX)
└─────────────────────────┘
       ▼
┌─────────────────────────┐    ┌─────────────────────┐
│ PostgreSQL Primary      │ ──► │ Read Replica 1      │
│ (writes + transactions) │     └─────────────────────┘
└─────────────────────────┘     ┌─────────────────────┐
                                 │ Read Replica 2      │
                                 └─────────────────────┘
       ▼
┌─────────────────────────┐
│ PgBouncer               │  ← pooled DB connections, reduces physical DB connections
└─────────────────────────┘
       ▼
┌─────────────────────────┐
│ SQS Payment Queue       │  ← async payments, payment workers consume
└─────────────────────────┘

## Component justification table

| Component | Failure It Prevents | How It Prevents It |
|---|---|---|
|CloudFront CDN| Failure 5 (NIC saturation) | Serves static assets from edge - origin bandwidth drops to near zero |
|ALB (Load Balancer)| Single-instance failure | Routes traffic across healthy instances, auto-scaling triggers on CPU/latency |
|Redis Cluster| DB pool exhaustion & N+1 reads | Cache hot read traffic (menus), SETNX for promo locking to prevent TOCTOU |
|PgBouncer| DB connection exhaustion | Multiplexes many app connections into a small pool of physical DB connections |
|Read Replicas| Read/write contention | Route read-heavy endpoints (order history, product list) to replicas, reduce primary load |
|SQS + Payment workers| Synchronous payment amplification | Offload long-running payment calls to async workers, freeing DB connections quickly |
