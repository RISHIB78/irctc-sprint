# BookMyShow — Schema (Part A)

-- events, venues, seats, users, bookings, booking_seats

CREATE TABLE venues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  city TEXT NOT NULL,
  capacity INTEGER NOT NULL CHECK (capacity > 0)
);
CREATE INDEX idx_venues_city ON venues(city);

CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id UUID NOT NULL REFERENCES venues(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('upcoming','on_sale','sold_out','cancelled')),
  total_seats INTEGER NOT NULL CHECK (total_seats >= 0)
);
CREATE INDEX idx_events_start_time ON events(start_time);

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  phone TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE TABLE seats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  section TEXT NOT NULL,
  row TEXT NOT NULL,
  number TEXT NOT NULL,
  price NUMERIC(10,2) NOT NULL CHECK (price > 0),
  category TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('available','held','booked')),
  held_until TIMESTAMP WITH TIME ZONE,
  held_by UUID REFERENCES users(id) ON DELETE SET NULL,
  version INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_seats_event_status ON seats(event_id, status);

CREATE TABLE bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('pending','confirmed','failed','refunded')),
  total_amount NUMERIC(12,2) NOT NULL CHECK (total_amount >= 0),
  payment_ref TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX idx_bookings_user ON bookings(user_id, created_at DESC);
CREATE INDEX idx_bookings_unresolved ON bookings(id) WHERE status IN ('pending','failed');

CREATE TABLE booking_seats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  seat_id UUID NOT NULL REFERENCES seats(id) ON DELETE RESTRICT,
  unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price > 0)
);

-- Commentary
- `booking.id` uses UUIDs to avoid predictable sequencing and allow client-side idempotency keys.
- `seats.version` provides optimistic locking for the confirmation phase (UPDATE ... WHERE version = X RETURNING ...).
- `held_until` allows short-lived holds without long-running transactions; background job releases expired holds.
- Partial index on `bookings` for unresolved statuses keeps the pending-work query fast and small.
