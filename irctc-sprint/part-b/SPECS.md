# IRCTC Feature Specifications � Part B

> All specs trace back to documented pain points in [`part-a/PROBLEMS.md`](../part-a/PROBLEMS.md).

---

## Feature Spec 1: Tatkal Virtual Queue

### Problem Statement
During the daily 10:00 AM Tatkal quota release, ~200k users hit the booking API simultaneously. The booking POST to `/booking/api/ticket` returns HTTP 502, and the UI shows an infinite spinner with no recovery path (Part A, Problem 1). Users lose their prepared booking details and must restart from scratch, often missing the quota entirely.

### Current State (from Part A)
Users log in, select train/class, enter passenger details, and click "Book Now" at 10:00 AM. The front-end sends a POST to the booking service, which times out under load and returns 502. The UI hangs indefinitely � no queue position, no estimated wait, no retry guidance. This breaks at step 6 of the Part A flow.

### Proposed Solution
Before Tatkal opens, users enter a virtual waiting room with their pre-filled booking details locked in. They see a live countdown to quota release, their queue position, and an estimated wait time. When their number is called, they have 90 seconds to confirm and complete payment. If the server is still overloaded, they are automatically re-queued with their position preserved rather than losing progress.

### Proposed User Flow � Step by Step
1. User logs in before 9:55 AM and selects Tatkal train, class, and passengers.
2. System detects Tatkal window approaching and prompts: "Join Virtual Queue?"
3. User confirms; booking details are saved server-side and a queue token is issued.
4. Waiting room screen shows countdown, queue position (#4,281), and estimated wait (~9 min).
5. At 10:00 AM quota opens; queue advances automatically via WebSocket/polling.
6. When position reaches #1, user sees "Your turn � 90 seconds to complete booking."
7. User taps "Confirm Booking"; system submits pre-validated POST with priority token.
8. On success -> payment screen. On 502 -> auto-retry 3� with position held, then re-queue at front.

### Technical Implementation Plan

**System components affected:**
- Frontend: new Tatkal Queue page, WebSocket client, countdown timer component
- Backend: new Queue Service (Redis-backed), Booking Service (priority token validation)
- Database: queue session store, pre-booking snapshot table
- Load balancer: queue-aware routing for priority tokens
- CDN: static assets for waiting room (must load on 2G)

**New data requirements:**
- `queue_sessions`: `{ sessionId, userId, queuePosition, joinedAt, bookingSnapshot (JSON), status, expiresAt }`
- `booking_snapshots`: `{ trainId, classCode, passengers[], quotaType, createdAt }`
- `priority_tokens`: `{ tokenId, sessionId, issuedAt, ttlSeconds: 90, used: boolean }`

**API changes:**
- `POST /queue/tatkal/join` -> Accepts booking snapshot -> Returns `{ sessionId, position, estimatedWaitSec }`
- `GET /queue/tatkal/status/{sessionId}` -> Returns `{ position, status, estimatedWaitSec, turnExpiresAt }`
- `WS /queue/tatkal/live` -> Pushes position updates every 2 seconds
- `POST /booking/api/ticket` (modified) -> Accepts optional `priorityToken` header for queue bypass
- `POST /queue/tatkal/retry` -> Re-queues user at front after failed attempt

**Frontend changes:**
- New route `/tatkal/queue/:sessionId`
- Components: `QueueCountdown`, `QueuePositionCard`, `BookingSnapshotSummary`, `TurnAlertModal`
- State: `queueSession` (position, status, turnDeadline), WebSocket connection manager
- Fallback polling every 5s if WebSocket disconnects

**Third-party services (if any):**
- Redis Cluster for queue ordering and pub/sub (position broadcasts)
- No external ML/third-party APIs required

### Success Metrics
- Tatkal booking completion rate increases from ~30% to >=65% during 9:55�10:10 AM window
- HTTP 502 exposure to end users drops by >=80% (errors handled server-side with re-queue)
- Average time-to-PNR for successful Tatkal bookings decreases from ~8 min to ?3 min
- User-reported "stuck spinner" support tickets drop by >=70%

### Edge Cases and Constraints
- User closes browser mid-queue -> session preserved for 30 min via `sessionId` cookie; resume on re-login
- Queue position expires if user doesn't act within 90 seconds -> moved to end of queue with notification
- Railway backend API may still reject booking even with priority token -> show clear error, offer re-queue
- Government audit requirements: all queue events logged with timestamp for RTI compliance
- Graceful degradation: if Redis unavailable, fall back to existing direct-booking flow with a "high traffic" banner

### Wireframe
![Tatkal queue screen wireframe](../assets/wireframes/tatkal-queue-screen.svg)
*Caption: Proposed Tatkal virtual queue screen � mobile view (375px). NEW: queue position + countdown replace infinite spinner.*

---

## Feature Spec 2: Persistent Search Filters

### Problem Statement
Search filters (class, quota, departure time) silently reset when users navigate back from train details or refresh the page (Part A, Problem 2). ~1.2M daily search sessions are affected, forcing users to re-apply filters manually and sometimes losing their selected date.

### Current State (from Part A)
Users apply filters, view 8 matching trains, open train details, then press browser Back. Filter chips disappear and all 47 trains are shown unfiltered. Re-applying filters may trigger a full page reload that clears the date field. Breaks at steps 5�7 of the Part A flow.

### Proposed Solution
Every applied filter is immediately synced to URL query parameters and session storage. Filter chips appear as a persistent row above results, showing active filters with one-tap removal. Navigating to train details and back preserves the exact filtered state. An empty-results state suggests which filters to relax.

### Proposed User Flow � Step by Step
1. User searches Chennai -> Bangalore, 12 Jun 2026.
2. Applies filters: AC 3-Tier, Tatkal, 06:00�12:00 departures.
3. Filter chips appear; URL updates to `?class=3A&quota=TQ&depAfter=0600&depBefore=1200`.
4. Results show "8 trains match (47 total)."
5. User taps train 12622 -> details page opens.
6. User presses Back -> returns to filtered results with all chips intact.
7. User removes "Tatkal" chip -> results refresh to 23 trains; URL updates automatically.
8. If zero results -> empty state suggests "Try removing Tatkal or widening time range."

### Technical Implementation Plan

**System components affected:**
- Frontend: search results page, filter panel, URL router
- Backend: search API (accept filter params � may already exist but not wired to frontend persistence)
- Browser: sessionStorage for filter backup

**New data requirements:**
- No new database tables; filters are client-side state encoded in URL
- `sessionStorage.searchFilters`: backup copy keyed by `{from}-{to}-{date}` hash

**API changes:**
- `GET /search/trains` (modified) -> Ensure all filter params (`class`, `quota`, `depAfter`, `depBefore`, `trainType`) are accepted and documented in OpenAPI spec
- Response adds `totalUnfiltered` count alongside `filteredCount`

**Frontend changes:**
- `FilterChipBar` component with removable chips
- `useSearchFilters` hook: syncs state -> URL -> sessionStorage on every change
- `SearchResultsPage` reads filters from URL on mount (not default state)
- `EmptyFilterResults` component with suggested filter relaxations

**Third-party services (if any):**
- None

### Success Metrics
- Filter reset complaints (support tickets tagged "search") drop by >=60%
- Multi-step search sessions (view details -> back) retain filters >=95% of the time
- Average filters re-applied per session drops from ~2.3 to <=0.2

### Edge Cases and Constraints
- Shared URL with filters embedded must reproduce exact results for another user
- Session timeout (20 min) -> filters restored from sessionStorage on re-login
- Invalid filter combo in URL (e.g., `class=INVALID`) -> ignore invalid params, show warning chip
- Graceful degradation: if sessionStorage unavailable (private browsing), URL-only persistence still works

### Wireframe
![Search filters wireframe](../assets/wireframes/search-filters-persistent.svg)
*Caption: Search results with persistent filter chips and before/after comparison.*

---

## Feature Spec 3: Seat Selection Lock During Availability Poll

### Problem Statement
During berth selection, background availability polling every 30 seconds clears all user selections without warning (Part A, Problem 3). Group travellers booking 4�6 berths together (~150k sessions/week) must re-select berths under time pressure, often losing preferred seats.

### Current State (from Part A)
User selects berths B1�B4 in coach S5. A background GET to `/availability/coach/{trainId}` fires, the coach layout re-renders, and all selections are cleared. User must re-select before the 10-minute booking timer expires. Breaks at steps 5�7.

### Proposed Solution
User selections are stored in a separate state layer that persists across availability poll responses. When new availability data arrives, the system merges it with locked selections � only clearing a berth if it was confirmed booked by another user, with an inline conflict notification and alternate suggestion.

### Proposed User Flow � Step by Step
1. User reaches coach layout for 4 passengers.
2. Taps berths B1, B2, B3, B4 � all highlight green; summary shows "4 berths selected."
3. Background poll fires; UI shows "Availability updated 12s ago � your selections preserved ?"
4. If B3 is now booked by another user -> B3 turns red with tooltip "Taken � tap to pick alternate."
5. User taps adjacent B7; selection restored to 4 berths.
6. User long-presses B1 to "lock" preference (lower berth priority).
7. User taps "Confirm Berths" -> proceeds to payment with selections intact.

### Technical Implementation Plan

**System components affected:**
- Frontend: coach layout component, selection state manager
- Backend: availability API (no schema change; frontend merge logic is primary fix)
- WebSocket (optional): real-time berth conflict push

**New data requirements:**
- Client-side only: `selectedBerths: Map<berthId, { coachId, berthNumber, locked: boolean }>`
- Server-side (optional): `berth_holds: { userId, trainId, berthId, heldUntil }` for 2-min soft lock

**API changes:**
- `GET /availability/coach/{trainId}` (modified response) -> Add `lastUpdatedAt` timestamp field
- `POST /availability/coach/hold` (new) -> Soft-lock selected berths for 120 seconds -> `{ held: berthId[], conflicts: berthId[] }`

**Frontend changes:**
- Refactor `CoachLayout` to use `useBerthSelection` hook with immutable merge on poll response
- `SelectionLockBanner` component during refresh
- `BerthConflictModal` for taken berths with adjacent suggestions
- Debounce poll interval to 45s while user has active selections

**Third-party services (if any):**
- None

### Success Metrics
- Berth re-selection rate during booking drops from ~25% to >=5%
- Group booking (4+ passengers) completion rate increases by >=15%
- Booking timer expiry rate due to selection loss drops by >=40%

### Edge Cases and Constraints
- All selected berths become unavailable -> show "Select new berths" with refreshed layout, timer extended by 2 min
- User selects conflicting berths (same berth twice) -> inline validation prevents
- Soft hold expires before confirm -> warn user "Berths released � please reconfirm"
- Railway API does not support hold -> client-side lock only (merge on poll, no server hold)

### Wireframe
![Seat selection lock wireframe](../assets/wireframes/seat-selection-lock.svg)
*Caption: Coach layout with selection lock during availability refresh and conflict state.*

---

## Feature Spec 4: Payment Status Tracker with Auto-Retry

### Problem Statement
After seat allocation, payment gateway callbacks timeout and users land on an ambiguous "Transaction Pending" page with no transaction ID, no retry, and no refund timeline (Part A, Problem 4). ~80k payment attempts/day enter this limbo state.

### Current State (from Part A)
User completes UPI payment on phone, but the gateway callback to `/payment/callback` times out after 30s. IRCTC shows generic pending message; no PNR is issued and no refund is initiated. Breaks at steps 5�7.

### Proposed Solution
A dedicated payment status screen shows a live step tracker (initiated -> gateway confirmation -> PNR issued), the transaction ID, and automatic retry of the callback check every 10 seconds for up to 5 attempts. If payment confirmed but PNR delayed, the system issues PNR asynchronously and notifies the user. If payment failed, seat is held for 10 more minutes with a one-tap retry.

### Proposed User Flow � Step by Step
1. User clicks "Pay Now" for ?1,240 via UPI.
2. Redirected to payment gateway; completes UPI on phone.
3. Lands on Payment Status screen showing Transaction ID and step tracker.
4. Step 2 "Awaiting gateway confirmation" pulses; auto-retry countdown shows "Retry in 8s."
5. On successful callback -> Step 3 green; PNR displayed with download button.
6. If callback fails after 5 retries -> "Payment received � PNR processing" with support link.
7. If payment not received -> "Payment failed" with [Retry Payment] and 10-min seat hold timer.

### Technical Implementation Plan

**System components affected:**
- Frontend: new Payment Status page
- Backend: Payment Service (callback handler, retry worker), Booking Service (async PNR issuance)
- Message queue: payment status reconciliation jobs
- Database: payment_transactions table enhancement

**New data requirements:**
- `payment_transactions`: add `callbackAttempts`, `lastCallbackAt`, `gatewayTxnId`, `reconciliationStatus`
- `seat_holds`: `{ bookingRef, heldUntil, reason: 'payment_pending' }`

**API changes:**
- `GET /payment/status/{txnId}` -> Returns `{ status, steps[], pnr, retryCount, seatHoldExpiresAt }`
- `POST /payment/retry-callback/{txnId}` -> Triggers manual callback check against gateway
- `POST /payment/reconcile` (internal cron) -> Polls gateway for pending txns every 60s

**Frontend changes:**
- Route `/payment/status/:txnId`
- Components: `PaymentStepTracker`, `TransactionIdCard`, `SeatHoldTimer`, `RetryButton`
- Poll `/payment/status/{txnId}` every 10s for 5 min, then every 60s

**Third-party services (if any):**
- Payment gateway status API (Paytm/Razorpay reconciliation endpoint)
- SMS gateway for async PNR notification

### Success Metrics
- "Transaction Pending" unresolved cases drop from ~15% to >=3%
- Mean time to PNR confirmation after payment decreases from ~12 min to ?2 min
- Payment-related support calls drop by >=50%

### Edge Cases and Constraints
- Double payment (user retries manually while first succeeds) -> deduplicate by `gatewayTxnId`, auto-refund duplicate
- Gateway API down -> show honest "Unable to verify � seat held 30 min" with manual check option
- UPI debited but gateway shows pending -> reconciliation cron resolves within 24h; user shown clear timeline
- PCI compliance: transaction ID displayed, full card/UPI details never logged client-side

### Wireframe
![Payment status tracker wireframe](../assets/wireframes/payment-status-tracker.svg)
*Caption: Payment status screen with step tracker, transaction ID, and success/failure states.*

---

## Feature Spec 5: Waitlist Notification and Status Dashboard

### Problem Statement
Waitlisted passengers (~900k tickets/month) receive no SMS, email, or push notification when WL position improves or when tickets confirm at chart preparation (Part A, Problem 5). Users must manually refresh PNR status and often miss confirmation details.

### Current State (from Part A)
User books WL/18, checks manually next day to find WL/12, but no notification was sent. At chart prep, ticket confirms to CNF but user arrives at station unaware of coach/berth. Breaks at steps 3�4; notification service batch runs every 6 hours and skips users who opted out of marketing SMS.

### Proposed Solution
A "My Bookings" dashboard shows live WL position, a timeline of all position changes, and notification preferences (transactional SMS, WhatsApp, in-app push � separate from marketing). Every WL movement triggers a real-time notification. At chart preparation, a high-priority push alert shows confirmed coach and berth.

### Proposed User Flow � Step by Step
1. User books ticket; status WL/18. Dashboard shows position and notification toggles.
2. WL improves to WL/12 -> SMS + WhatsApp sent within 5 minutes; timeline updated.
3. User opens app -> sees "WL/8 � Confirmation probability: 72% likely" badge.
4. Chart prepares 4 hours before departure -> push notification: "CONFIRMED! Coach S3, Berth 24."
5. User taps notification -> e-ticket with QR code.
6. If not confirmed -> dashboard shows "WL/3 � likely to confirm" with alternative train suggestion.

### Technical Implementation Plan

**System components affected:**
- Frontend: My Bookings dashboard, notification preference settings
- Backend: Notification Service (rebuilt), PNR status polling worker, Chart Preparation webhook
- Database: notification_log, wl_history
- Third-party: SMS ( transactional route), WhatsApp Business API, FCM push

**New data requirements:**
- `wl_history`: `{ pnr, wlPosition, recordedAt, eventType: 'movement'|'chart_prep'|'confirm' }`
- `notification_preferences`: `{ userId, transactionalSms, whatsapp, email, pushEnabled }`
- `notification_log`: `{ userId, pnr, channel, sentAt, status, messageType }`

**API changes:**
- `GET /bookings/wl-dashboard` -> Returns active WL bookings with position, history, probability
- `PUT /notifications/preferences` -> Updates channel preferences (transactional separate from marketing)
- `POST /notify/wl-update` (rebuilt) -> Event-driven, triggered on every PNR status change (not 6-hour batch)
- `GET /bookings/{pnr}/wl-history` -> Timeline of position changes

**Frontend changes:**
- `WLDashboardCard` with position badge, probability bar, timeline
- `NotificationPreferences` panel with transactional/marketing separation
- Push notification handler for chart prep alerts

**Third-party services (if any):**
- WhatsApp Business API (Meta) for WL updates � high open rate in India
- Firebase Cloud Messaging for in-app push
- SMS via transactional DLT-registered template (India TRAI compliance)

### Success Metrics
- WL notification delivery rate increases from ~10% to >=90% within 5 min of status change
- Manual PNR check frequency drops by >=50% for WL passengers
- Station enquiry counter visits for "don't know my berth" drop by >=30%

### Edge Cases and Constraints
- User opted out of all channels -> in-app notification only; show banner on next login
- WhatsApp API rate limits during mass chart prep -> priority queue: CNF confirmations first, then WL movements
- Wrong WL position in notification -> log source PNR refresh timestamp; allow user to report discrepancy
- Graceful degradation: if WhatsApp fails, fall back to SMS; if SMS fails, in-app + email

### Wireframe
![WL notification dashboard wireframe](../assets/wireframes/wl-notification-dashboard.svg)
*Caption: My Bookings dashboard with WL timeline, probability badge, and notification preferences.*

---

## Feature Spec 6: Smart Login with OTP Session Persistence

### Problem Statement
During peak login windows (Tatkal 9:45�10:15 AM), captcha expires before submission and OTP tokens are invalidated when captcha is re-solved, forcing repeated login loops that increase server load (Part A, Problem 6). ~500k login attempts fail daily during Tatkal.

### Current State (from Part A)
User solves captcha, waits 8 seconds for page load, gets "captcha expired," re-solves captcha, receives OTP, switches to SMS app for 15 seconds, returns to find "OTP already used or expired." Full restart required. Breaks at steps 7�8.

### Proposed Solution
Once captcha is validated and OTP is sent, the captcha session is locked � re-solving captcha does not invalidate the OTP. OTP validity extends to 3 minutes with a visible countdown timer. A "Resend OTP" button refreshes the code without restarting captcha. Failed OTP attempts show remaining tries without clearing the session.

### Proposed User Flow � Step by Step
1. User enters username, password, and captcha on mobile at 9:50 AM.
2. Taps "Continue to OTP" -> captcha validated server-side; OTP sent to ***9876.
3. Captcha field greyed out with label "Verified -> � OTP session active."
4. OTP input shown with 3:00 countdown timer.
5. User switches to SMS app for 20 seconds, returns � timer shows 2:40 remaining.
6. Enters OTP -> login succeeds.
7. If OTP expired -> "Resend OTP" button (no captcha re-entry required).
8. If 3 failed OTP attempts -> session locked 5 min with clear message (anti-brute-force).

### Technical Implementation Plan

**System components affected:**
- Frontend: login page refactor, OTP step component
- Backend: Auth Service (session management), Captcha Service, OTP Service
- Redis: login session store with TTL

**New data requirements:**
- `login_sessions`: `{ sessionId, userId, captchaVerified, otpSentAt, otpAttempts, expiresAt, status }`
- No changes to user credentials table

**API changes:**
- `POST /auth/login/init` -> Validates credentials + captcha -> Returns `{ sessionId, otpSent: true, otpExpiresAt }`
- `POST /auth/login/verify-otp` -> Accepts `{ sessionId, otp }` -> Returns auth token or `{ error, attemptsRemaining }`
- `POST /auth/login/resend-otp` -> Accepts `{ sessionId }` -> Sends new OTP without captcha re-validation
- Deprecate monolithic `POST /auth/login` that couples captcha + OTP in one request

**Frontend changes:**
- Split login into `CredentialsStep` and `OtpStep` components
- `OtpTimer` countdown (3 min), `ResendOtpButton` (enabled after 30s)
- Disable captcha re-render after OTP sent; show "Verified" badge
- Store `sessionId` in component state (not URL)

**Third-party services (if any):**
- Redis for session TTL management
- Existing SMS OTP provider (no change)

### Success Metrics
- Login success rate during Tatkal window increases from ~50% to >=85%
- Average login attempts per successful session drops from ~3.2 to ?1.3
- Auth service load during 9:45�10:15 AM drops by >=30% (fewer retry loops)

### Edge Cases and Constraints
- Session hijacking risk -> bind `sessionId` to device fingerprint + IP; expire on mismatch
- OTP SMS delayed >3 min -> allow one free extension (+2 min) before resend required
- Account lockout after 3 failed OTP -> 5-min cooldown with support link
- Graceful degradation: if Redis down, fall back to current monolithic login with extended captcha TTL (5 min)

### Wireframe
![Smart login OTP wireframe](../assets/wireframes/login-smart-otp.svg)
*Caption: Split login flow with OTP timer, captcha lock, and resend without restart.*

---

## Peer Review Updates

After presenting Feature Spec 1 (Tatkal Virtual Queue) and Feature Spec 5 (WL Notification Dashboard) to peers, the following updates were made:

1. **Tatkal Queue � Redis SPOF concern:** Added graceful degradation fallback to direct-booking flow if Redis is unavailable, rather than blocking all Tatkal users. Peer noted a Redis outage during peak would be worse than current 502 behavior.

2. **Tatkal Queue � 90-second turn window too short for UPI:** Extended turn window from 90s to 120s and added metric tracking for "turn expired without action" to calibrate further. Peer shared anecdote of UPI app switch taking 45+ seconds on 2G.

3. **Tatkal Queue � Queue gaming:** Added edge case for multi-device queue joining � one queue session per userId enforced server-side; duplicate sessions merged keeping earliest position.

4. **WL Dashboard � Probability badge liability:** Moved probability display to AI-FEATURE.md scope; dashboard shows raw WL position and timeline only unless AI confidence >=70%. Peer asked: "What if predictor says 80% and user cancels alternate booking?"

5. **WL Dashboard � WhatsApp cost at scale:** Added priority queue for chart-prep confirmations over intermediate WL movements to control WhatsApp API costs during mass events.

6. **Search Filters � Matrix reconsideration:** Moved from "Fill-In" to "Quick Win" after peer demonstrated filter reset is reproducible on every back-navigation (higher impact than initially scored).

7. **Payment Tracker � Double payment edge case:** Added explicit deduplication by `gatewayTxnId` with auto-refund after peer described personal experience of double UPI debit during IRCTC retry.

8. **Login Smart OTP � Security pushback:** Added device fingerprint binding to sessionId and 5-min lockout after 3 failed OTP attempts to address peer's security concern about decoupled captcha/OTP sessions.
