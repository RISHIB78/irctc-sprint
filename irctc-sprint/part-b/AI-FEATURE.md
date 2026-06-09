# AI Feature Specification: Waitlist Confirmation Probability Predictor

## Problem It Solves
This AI feature directly addresses **Problem 5: Waitlist Status Updates Never Arrive** (see [`part-a/PROBLEMS.md`](../part-a/PROBLEMS.md), Problem 5) and enhances **Feature Spec 5** (WL Notification Dashboard). Waitlisted passengers (~900k tickets/month) manually refresh PNR status because they don't know whether their WL/8 ticket will confirm. A probability predictor gives them actionable guidance — "72% likely to confirm" — so they can decide whether to book an alternative train or wait.

## Proposed Feature — User Perspective
When a user views a waitlisted booking on the My Bookings dashboard, a badge appears next to the WL position: **"Confirmation probability: 72% likely"** with a green/amber/red confidence bar. The label updates each time WL position changes. If probability is high (?70%), the dashboard suggests: "You likely don't need a backup ticket." If low (<30%), it suggests: "Consider train 12640 departing 1 hour later — 45 seats available." The user never needs to type a query; the prediction appears automatically on their existing booking card.

## Model or API Choice
**Primary model: Custom XGBoost classifier** served via an internal FastAPI microservice.

**Why XGBoost and not GPT-4 or a deep learning model:**
- WL confirmation is a structured tabular prediction problem (route, class, WL position, day-of-week, historical clearance rate) — not a language task
- XGBoost trains in minutes on CPU, runs inference in <10ms on 2G-friendly payloads
- No API cost per prediction (critical at 900k tickets/month scale)
- Interpretable feature importance for Railway audit compliance
- GPT-4 would be overkill, slow (500ms+ latency), expensive ($0.01+/call), and unreliable offline

**Fallback model:** Rule-based lookup table using historical clearance rates by `(route, class, wlPositionBucket)` when ML service is unavailable.

## Training or Input Data

| Feature | Source | Availability |
|---------|--------|--------------|
| Route (from?to station pair) | IRCTC booking DB | Available |
| Train number + class code | IRCTC booking DB | Available |
| Current WL position | PNR status API (real-time) | Available |
| Journey date + day of week | Booking record | Available |
| Historical WL clearance rate for route/class | IRCTC analytics DB (12 months) | Available — needs ETL pipeline |
| Cancellation rate by route (last 7 days) | Cancellation logs | Available |
| Chart preparation timing | Railway chart prep webhook | Available |
| Quota type (General/Tatkal) | Booking record | Available |
| Seasonality (festival/holiday flag) | Indian holiday calendar API | Available |

**Training pipeline:**
1. Extract 12 months of `(route, class, wlAtBooking, wlAtChartPrep, finalStatus)` records
2. Label: `confirmed = 1 if finalStatus == CNF else 0`
3. Train XGBoost with 80/20 temporal split (train on months 1–10, validate on 11–12)
4. Retrain weekly via Airflow cron on fresh data
5. Target accuracy: ?78% on validation set (baseline: 50% random)

## How Output Is Shown to the User

Displayed on the WL Dashboard card (see wireframe):

```
???????????????????????????????????????
? PNR: 4829167534          WL/8      ?
? 12622 | Chennai ? Bangalore        ?
?                                     ?
? Confirmation probability:           ?
? ????????????????????  72% likely   ?  ? Green bar if ?70%
?                                     ?
? ? Improved from WL/18 yesterday    ?
???????????????????????????????????????
```

- **?70% confidence:** Green bar + text "Likely to confirm — backup ticket optional"
- **30–69% confidence:** Amber bar + text "Uncertain — consider a backup option"
- **<30% confidence:** Red bar + text "Unlikely to confirm" + alternate train suggestion card
- **<50% model confidence (meta-confidence):** Hide probability badge entirely; show only raw WL position

Reference wireframe: [`assets/wireframes/wl-notification-dashboard.svg`](../assets/wireframes/wl-notification-dashboard.svg)

## Confidence Threshold and Fallback

| Condition | User sees |
|-----------|-----------|
| Model confidence ?50% AND prediction computed | Probability badge with color-coded bar |
| Model confidence <50% (meta) | Raw WL position only — no probability badge |
| ML service timeout (>500ms) | Rule-based lookup: "Historically, WL/8 on this route confirms ~65% of the time" (static table) |
| ML service down entirely | No probability; standard WL position + timeline (Feature Spec 5 works without AI) |
| Insufficient historical data for route (<100 samples) | "Not enough data for prediction" — no badge |
| User on 2G with slow load | Badge loads asynchronously; skeleton placeholder shown first |

**Critical UX rule:** The probability badge is always supplementary to the raw WL position — never replace the official PNR status. A disclaimer reads: "Prediction based on historical data — not a guarantee."

## Success Metrics
- Prediction accuracy ?78% on held-out validation set (measured weekly)
- Users with high-probability (?70%) bookings who also book backup tickets: ?15% (indicates trust in prediction)
- Support tickets asking "will my WL confirm?" drop by ?40%
- Dashboard engagement: ?60% of WL users view probability badge within 24h of booking
- False high-confidence rate (<5%): cases where model predicted ?70% but ticket remained WL at chart prep

## Limitations and Risks
- **Wrong prediction, user skips backup:** If model says 80% likely and ticket doesn't confirm, user may miss journey. Mitigation: always show raw WL position prominently; disclaimer on every badge; never auto-cancel or auto-modify bookings based on prediction
- **Bias toward popular routes:** Model trained heavily on Chennai–Bangalore, Delhi–Mumbai pairs may underperform on rural routes. Mitigation: route-specific confidence thresholds; hide badge when sample size <100
- **Sudden quota changes:** Railway adds extra coaches ? historical patterns break. Mitigation: weekly retraining + anomaly detection flag when clearance rate deviates >2? from 7-day average
- **Regulatory risk:** IRCTC is a government system — predictions must be labeled as estimates, not official status. Legal review required before launch
- **Data privacy:** Model uses aggregated route-level data, never individual user browsing history

## Peer Review Update
Peer challenged: "What if the WL predictor is wrong and the user misses their journey?" Added the meta-confidence threshold (<50% hides badge), mandatory disclaimer, and explicit rule that prediction never replaces official PNR status. Also added false high-confidence rate as a tracked metric (target <5%).
