# Async Order Queue — SQS-backed flow

## Why async
- Synchronous payment calls hold DB connections for 200–2000ms. Offloading to SQS reduces API-held DB time to ~10ms and prevents pool exhaustion.

## Message format (JSON)
{
  "bookingId": "<uuid>",
  "userId": "<uuid>",
  "eventId": "<uuid>",
  "seatIds": ["<uuid>", ...],
  "totalAmount": 1200.00,
  "paymentToken": "<token>",
  "idempotencyKey": "<uuid-or-client-generated>"
}

## Worker logic
1. Receive message (visibility timeout = 120s)
2. Validate idempotency (skip if booking already confirmed)
3. Call payment gateway (retry up to 3 times on transient errors)
4a. Success: UPDATE booking status=confirmed; UPDATE seats SET status='booked'; notify user; delete message
4b. Failure: UPDATE booking status=failed; release seats; notify user; delete or route to DLQ depending on failure type

## Edge cases
- API published to SQS but crashed before responding: client may retry. Use idempotencyKey to dedupe messages and make publish idempotent.
- Payment gateway timeout: treat as transient, retry up to 3 times; if still unknown, move to DLQ and mark booking `pending_review`.

## SQS config
- Visibility timeout: 120s (2× expected max payment time)
- Max receive count before DLQ: 3
