# Impact vs Effort Matrix

## The Matrix

|                   | Low Effort         | High Effort        |
|-------------------|--------------------|--------------------|
| **High Impact**   | Persistent Search Filters, Smart Login OTP, Seat Selection Lock | Tatkal Virtual Queue, WL Notification Dashboard |
| **Low Impact**    | *(none — all 6 problems affect core flows)* | Payment Status Tracker |

## How I Scored Each Dimension

### Impact Scoring (1–5)
I scored Impact based on:
- Number of users affected (from Part A frequency analysis)
- Whether the problem is in the core booking flow
- Severity of consequence for the user

| Problem | Users Affected | Core Flow? | Severity | Impact Score |
|---------|---------------|------------|----------|-------------|
| 1. Tatkal Queue | ~200k/day | Yes — booking | Critical (miss quota) | 5 |
| 2. Search Filters | ~1.2M/day | Yes — search | Medium (frustration) | 4 |
| 3. Seat Selection | ~150k/week | Yes — booking | High (lose seats) | 4 |
| 4. Payment Timeout | ~80k/day | Yes — payment | Critical (money/PNR limbo) | 4 |
| 5. WL Notifications | ~900k/month | Yes — post-booking | High (miss journey) | 5 |
| 6. Login OTP Loop | ~500k/day (peak) | Yes — auth gateway | High (can't book at all) | 4 |

### Effort Scoring (1–5)
I scored Effort based on:
- Number of system components touched
- Whether new infrastructure is required
- Risk of breaking existing flows
- Railway API dependencies

| Problem | Components | New Infra? | Risk | Effort Score |
|---------|-------------|------------|------|-------------|
| 1. Tatkal Queue | 5 (FE, BE, Redis, LB, DB) | Yes — Redis queue | High | 5 |
| 2. Search Filters | 1 (FE only) | No | Low | 2 |
| 3. Seat Selection | 2 (FE + optional hold API) | No | Low | 2 |
| 4. Payment Tracker | 4 (FE, BE, MQ, gateway) | Yes — retry worker | Medium | 4 |
| 5. WL Notifications | 5 (FE, BE, SMS, WhatsApp, FCM) | Yes — event-driven notify | Medium | 4 |
| 6. Login Smart OTP | 3 (FE, Auth, Redis) | Yes — session store | Medium | 3 |

---

## Placement Justifications

### Problem 1: Tatkal Virtual Queue — Major Project (High Impact, High Effort)
Tatkal crashes affect ~200k users daily at exactly 10:00 AM, making this the highest-severity problem in Part A — users directly lose quota and money. The solution requires a new Redis-backed Queue Service, WebSocket infrastructure, priority token validation in the Booking Service, and load-balancer changes — touching 5 system components with high regression risk during peak. This is a Major Project: schedule for a dedicated sprint with load testing, but prioritize after Quick Wins ship because the ROI on completion rate (30% ? 65%) is the largest single metric gain.

### Problem 2: Persistent Search Filters — Quick Win (High Impact, Low Effort)
Filter resets affect an estimated 40% of ~1.2M daily search sessions, making this one of the broadest-reaching UX bugs in Part A. The fix is almost entirely frontend — syncing filter state to URL query params and sessionStorage with a `FilterChipBar` component — no backend schema changes or new infrastructure. Ship this first: maximum user reach for minimum engineering investment, and it builds confidence before tackling infrastructure-heavy features.

### Problem 3: Seat Selection Lock — Quick Win (High Impact, Low Effort)
Random berth resets affect ~25% of multi-passenger bookings (~150k sessions/week), causing real seat loss under time pressure. The primary fix is a frontend state merge in the `CoachLayout` component — storing selections separately from poll responses — with an optional soft-hold API that is not blocking. Low effort because it doesn't require Railway API changes; ship alongside Search Filters in Sprint 1.

### Problem 4: Payment Status Tracker — Time Sink ? Revised to Major Project (High Impact, High Effort)
Payment limbo affects ~80k attempts/day with direct financial consequence — users don't know if money was debited. However, it requires payment gateway reconciliation APIs, a message queue retry worker, async PNR issuance, and PCI-compliant transaction logging across 4 components. Initially scored as Time Sink due to gateway dependency risk, but peer review raised the financial severity — reclassified to Major Project and scheduled after Quick Wins but alongside Tatkal Queue in Sprint 2.

### Problem 5: WL Notification Dashboard — Major Project (High Impact, High Effort)
Waitlisted passengers (~900k tickets/month) have no proactive updates, leading to missed journeys and station chaos. The solution rebuilds the notification pipeline (batch ? event-driven), integrates WhatsApp Business API + FCM + transactional SMS, and adds the AI probability predictor — touching 5 components. High effort but highest post-booking impact; schedule for Sprint 2 with the AI model trained in parallel during Sprint 1.

### Problem 6: Smart Login OTP — Quick Win (High Impact, Low Effort)
Login failures during Tatkal affect ~500k attempts/day — users can't even reach the booking flow. The fix splits the monolithic login into a two-step session (captcha ? OTP) stored in Redis with a 3-minute TTL — 3 components but well-understood auth patterns with no Railway API dependency. Quick Win because it reduces auth service load by 30% while improving success rate from 50% to 85%; ship in Sprint 1 before Tatkal Queue so users can actually log in.

---

## Recommended Sprint Order

1. **Persistent Search Filters** — Frontend-only, broadest reach (1.2M sessions/day), zero infra risk. Builds team velocity.
2. **Smart Login OTP** — Unblocks the auth gateway before Tatkal window; must ship before Problem 1 can help anyone.
3. **Seat Selection Lock** — Frontend-heavy, pairs naturally with Search Filters sprint; completes the booking UX polish layer.
4. **Tatkal Virtual Queue** — Highest single metric impact but needs Redis + load testing; deploy before next Tatkal season.
5. **WL Notification Dashboard + AI Predictor** — Train XGBoost model during Sprint 1–2; launch notifications and probability badge together.
6. **Payment Status Tracker** — Requires payment gateway partnership for reconciliation API access; longest external dependency lead time.

---

## Peer Review Matrix Updates

- **Search Filters:** Moved from Low Impact ? High Impact (Quick Win) after peer demo showed 100% reproduction rate on back-navigation.
- **Payment Tracker:** Moved from Time Sink ? Major Project after peer described double UPI debit — financial severity upgraded.
- **Login OTP:** Effort score reduced from 4 ? 3 after peer confirmed Redis session pattern is already used elsewhere in IRCTC auth stack.
