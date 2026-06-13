Part A scaffold for QuickBite performance assignment.

Files added:
- `PROFILING.md` - template to record Artillery baseline, EXPLAIN ANALYZE, and before/after numbers.
- `artillery-baseline.yml` - sample Artillery scenario to run baseline load tests.
- `migrations/003_add_performance_indexes.sql` - targeted index migrations with one-line justifications.
- `src/middleware/queryCount.middleware.js` - Express middleware scaffold to count DB queries per request.

How to use (assumes QuickBite project root):

1. Run Artillery baseline:

```bash
npm install -g artillery
artillery run artillery-baseline.yml --output baseline-results.json
artillery report baseline-results.json
```

2. Add middleware to your Express app (example in `src/app.js`):

```js
const queryCount = require('./src/middleware/queryCount.middleware');
app.use(queryCount);
```

3. Run migrations to add indexes:

```bash
psql $DATABASE_URL -f migrations/003_add_performance_indexes.sql
```

4. Run EXPLAIN ANALYZE on slow queries and paste outputs into `PROFILING.md`.
