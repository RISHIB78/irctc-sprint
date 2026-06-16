# Pull Request Description — Copy into PR #1

**Title:** IRCTC Sprint — Part A + Part B: Discovery, Specs, AI Feature, Matrix

---

## Summary

Part A documents 6 IRCTC pain points with broken flows, affected users, and frequency data. Part B turns each problem into a full feature spec with wireframes, an AI feature proposal (XGBoost WL predictor), a 2×2 Impact vs Effort matrix, and peer review updates.

---

## Part B — Top-Priority Quick Win Feature Spec (Persistent Search Filters)

### Problem Statement
Search filters (class, quota, departure time) silently reset when users navigate back from train details or refresh the page (Part A, Problem 2). ~1.2M daily search sessions are affected, forcing users to re-apply filters manually and sometimes losing their selected date.

### Proposed Solution
Every applied filter is immediately synced to URL query parameters and session storage. Filter chips appear as a persistent row above results, showing active filters with one-tap removal. Navigating to train details and back preserves the exact filtered state.

### Technical Implementation Plan
- **Frontend only:** `FilterChipBar`, `useSearchFilters` hook syncing state ? URL ? sessionStorage
- **API:** `GET /search/trains` accepts filter params; response adds `totalUnfiltered` count
- **No new infrastructure** — ship in Sprint 1 as highest-ROI Quick Win

### Success Metrics
- Filter reset support tickets drop by ?60%
- Multi-step search sessions retain filters ?95% of the time

---

## Wireframe — Search Filters (Quick Win)

![Search filters wireframe](assets/wireframes/search-filters-persistent.svg)

---

## Impact vs Effort Matrix

|                   | Low Effort         | High Effort        |
|-------------------|--------------------|--------------------|
| **High Impact**   | Persistent Search Filters, Smart Login OTP, Seat Selection Lock | Tatkal Virtual Queue, WL Notification Dashboard |
| **Low Impact**    | *(none)*           | Payment Status Tracker |

**Recommended Sprint Order:** Search Filters ? Login OTP ? Seat Selection Lock ? Tatkal Queue ? WL Dashboard + AI ? Payment Tracker

---

## Peer Review Updates

After presenting Tatkal Virtual Queue and WL Notification Dashboard, three key updates were made: (1) Tatkal turn window extended from 90s to 120s for UPI on 2G, with Redis fallback to direct booking if queue service is down; (2) WL probability badge gated behind ?70% AI confidence to avoid liability when predictions are wrong; (3) Search Filters reclassified from Fill-In to Quick Win after peers demonstrated 100% filter reset reproduction on browser back-navigation. Full notes in `part-b/PEER-REVIEW.md`.

---

## Files Added/Updated

- `part-a/PROBLEMS.md` — all 6 problems complete
- `part-b/SPECS.md` — 6 feature specifications
- `part-b/AI-FEATURE.md` — XGBoost WL Confirmation Probability Predictor
- `part-b/MATRIX.md` — Impact vs Effort matrix with justifications
- `part-b/PEER-REVIEW.md` — session notes
- `assets/wireframes/` — 6 UI wireframes (SVG)
