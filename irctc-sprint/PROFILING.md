## Part A - Profiling & Fixes

### Baseline (before any fixes)

| Endpoint                | P50    | P95    | Error Rate |
|-------------------------|--------|--------|------------|
| GET /api/restaurants    | ___ms  | ___ms  | ___%       |
| GET /api/orders/history | ___ms  | ___ms  | ___%       |
| POST /api/orders        | ___ms  | ___ms  | ___%       |

### Query Count per Endpoint

| Endpoint                        | Query Count | Note              |
|---------------------------------|-------------|-------------------|
| GET /api/restaurants            | ___         |                   |
| GET /api/restaurants/:id/menu   | ___         |                   |
| GET /api/orders/history         | ___         | ← N+1 here?       |

### EXPLAIN ANALYZE Results

Paste EXPLAIN ANALYZE output for each slow query here, with findings and fix notes.

### Artillery Results

Include `baseline-results.json` and `after-fixes-results.json` outputs and summary tables.

### Indexes Added

List migration names and one-sentence justifications for each index added.
