# Cache Design — keys, TTLs, invalidation

## Keys and TTLs

- `event:{event_id}` → TTL 3600s (1 hour). Event metadata rarely changes.
- `seatmap:{event_id}` → TTL 86400s (1 day). Static layout.
- `availability:{event_id}:{category}` → TTL 30s. Counts for UI; invalidate on seat status change.

## Invalidation strategy
- Use cache-aside pattern: on read, if miss → query DB and populate key with TTL.
- On seat status change (hold/book/release), publish an internal event and delete `availability:{event_id}:{category}` immediately so next read repopulates accurate count.

## What NOT to cache
- Do NOT cache individual `seat:{seat_id}` availability. Single-seat state must be authoritative via Redis lock or DB.

## Pseudocode
When seat status changes:
  UPDATE seats SET status=...;
  PUBLISH 'seat.changed' (event_id, category);
  DEL availability:{event_id}:{category}

When serving product/availability request:
  if redis.exists(availability:key) return
  else query DB, set key with TTL 30s, return
