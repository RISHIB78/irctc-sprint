# Part A — The Zudio Incident: 5 Bugs Found, Fixed, and Verified

## Summary
- This PR contains fixes and documentation for Part A: security, logic, and performance bugs in the Zudio backend.

## Profiling (Before fixes)
| Endpoint | Response Time | Query Count | Notes |
|---|---:|---:|---|
| GET /api/products | ___ms | ___ | |
| GET /api/products?search=shirt | ___ms | ___ | |
| GET /api/products?search=shirt' OR '1'='1 | ___ms | ___ | SQL injection |
| GET /api/orders/history | ___ms | ___ | N+1 detected |
| POST /api/cart/checkout | ___ms | ___ | double discount |

## Summary of Bugs
1. SQL Injection in products search — CRITICAL
2. Plaintext passwords stored — CRITICAL
3. Double discount applied — HIGH
4. Stock not decremented on checkout — HIGH
5. N+1 query in order history — MEDIUM

## Before/After (example SQL injection fix)
Before:
```js
const query = `SELECT * FROM products WHERE name LIKE '%${req.query.search}%'`
await pool.query(query)
```
After:
```js
const query = `SELECT * FROM products WHERE name ILIKE $1`
await pool.query(query, [`%${req.query.search}%`])
```

## Verification checklist
- [ ] SQL injection test (GET /api/products?search=...) — returns literal string results
- [ ] Password hashing test — DB shows bcrypt hash
- [ ] Double discount test — second apply returns 400
- [ ] Stock decrement test — product stock reduced after checkout
- [ ] Order history profiling — query count reduced, response time improved

## Notes for reviewer
- The `PR_BODY.md` file is a draft. Update the profiling table and AUDIT.md with exact before/after measurements and the detailed `AUDIT.md` entries before merging.
