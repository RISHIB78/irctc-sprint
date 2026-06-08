# Peer Review Session Notes

**Date:** 2026-06-06  
**Presented:** Feature Spec 1 (Tatkal Virtual Queue), Feature Spec 5 (WL Notification Dashboard)  
**Reviewers:** Peer group (Module 2.3)

## Challenges Raised

1. Redis SPOF during Tatkal peak � what happens if queue service goes down?
2. 90-second turn window too short for UPI on 2G networks
3. WL probability badge liability if prediction is wrong
4. WhatsApp API cost at scale during mass chart preparation
5. Security concern about decoupled captcha/OTP sessions
6. Double UPI payment on manual retry during pending state

## Updates Applied

See **Peer Review Updates** section in [`SPECS.md`](SPECS.md) and **Peer Review Matrix Updates** in [`MATRIX.md`](MATRIX.md).

Minimum 3 meaningful spec changes completed:
- Tatkal queue Redis fallback + 120s turn window + anti-gaming
- WL probability gated behind ?70% AI confidence
- Payment double-debit deduplication by gatewayTxnId
- Login session device fingerprint binding
- Search Filters matrix reclassification to Quick Win
