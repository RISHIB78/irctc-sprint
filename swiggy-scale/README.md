# Swiggy-scale — Scale Simulation & Incident Architecture

This repository contains a systems-level analysis and incident runbook for a Swiggy-like monolith facing a World Cup Final promo spike.

Documents
- `docs/FAILURE-CASCADE.md` — traffic math, component capacity, failure cascade, timeline
- `docs/ARCHITECTURE.md` — current and redesigned ASCII architecture + component justification
- `docs/COST-ESTIMATE.md` — AWS baseline and peak cost calculations
- `docs/RUNBOOK.md` — 5-step incident runbook for junior engineers

Key findings
- The DB pool (100 connections) can be exhausted at ~400 RPS with synchronous payments — orders of magnitude below the 500K RPS demand.
- CDN + Redis + PgBouncer + async payments reduce origin load and prevent immediate collapse.
- Estimated baseline infra cost (~$1k/mo) is negligible compared to outage losses (₹189 crore for a 45-minute outage).

Architecture overview
- Replace the single monolith with a CDN, ALB, auto-scaled stateless Node fleet, Redis cache, PgBouncer, read replicas, and an async payment queue.

Tech stack context
- Node.js, PostgreSQL (with PgBouncer), Redis (ElastiCache), AWS (ALB, CloudFront, RDS, SQS)
