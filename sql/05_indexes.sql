\set ON_ERROR_STOP on
SET search_path TO bms;

-- R01/R07/R10: screen equality followed by a start-time range; included
-- columns cover the show identifiers and cleaning-gap end time.
CREATE INDEX IF NOT EXISTS shows_screen_start_idx
    ON shows (screen_id, starts_at) INCLUDE (show_id, ends_at);
-- R02/R19/W05: movie equality before the timestamp range.
CREATE INDEX IF NOT EXISTS shows_movie_start_idx
    ON shows (movie_id, starts_at) INCLUDE (show_id, screen_id);
-- R08/R16/R18/R25: date ranges across all movies/screens.
CREATE INDEX IF NOT EXISTS shows_start_idx
    ON shows (starts_at) INCLUDE (show_id, movie_id, screen_id);
-- R05: small per-customer confirmed-booking lookup.
CREATE INDEX IF NOT EXISTS bookings_confirmed_customer_idx
    ON bookings (customer_id) WHERE status = 'CONFIRMED';
-- R08/R19: confirmed bookings by show, covering revenue and ticket totals.
CREATE INDEX IF NOT EXISTS bookings_confirmed_show_idx
    ON bookings (show_id) INCLUDE (booking_id, ticket_amount, num_tickets)
    WHERE status = 'CONFIRMED';
-- R09/W04: only pending rows, timestamp range and queue order first.
CREATE INDEX IF NOT EXISTS bookings_pending_time_idx
    ON bookings (booked_at) INCLUDE (booking_id, show_id, num_tickets)
    WHERE status = 'PENDING';
-- W02/W03: directly find the minimum pending booking_id.
CREATE INDEX IF NOT EXISTS bookings_pending_id_idx
    ON bookings (booking_id) WHERE status = 'PENDING';
-- R13: indexed existence probes for offer redemption (NULLs are irrelevant).
CREATE INDEX IF NOT EXISTS bookings_offer_idx
    ON bookings (offer_code) WHERE offer_code IS NOT NULL;
-- R20: range scan covering the amounts needed for daily totals.
CREATE INDEX IF NOT EXISTS bookings_confirmed_time_idx
    ON bookings (booked_at) INCLUDE (total_amount) WHERE status = 'CONFIRMED';
-- R22: preserve OFFSET semantics, but avoid a full sort and heap reads.
CREATE INDEX IF NOT EXISTS bookings_newest_idx
    ON bookings (booked_at DESC)
    INCLUDE (booking_id, booking_code, customer_id, show_id, status);
-- R17: reverse of the existing (show_id, seat_id) PK for seat-first probes.
CREATE INDEX IF NOT EXISTS booking_seats_seat_show_idx
    ON booking_seats (seat_id, show_id);
-- W04: locate a pending booking's held seats without scanning every seat.
CREATE INDEX IF NOT EXISTS booking_seats_booking_idx
    ON booking_seats (booking_id);

-- W02: screen equality followed by seat-id order avoids scanning unrelated seats.
CREATE INDEX IF NOT EXISTS seats_screen_id_idx ON seats (screen_id, seat_id);

-- Refresh planner statistics and visibility maps for covering-index scans.
-- Run this script outside a transaction (VACUUM requires it).
VACUUM (ANALYZE) shows;
VACUUM (ANALYZE) bookings;
VACUUM (ANALYZE) booking_seats;
VACUUM (ANALYZE) seats;
