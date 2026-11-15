# Problem understanding

BookMyShow needs a reliable ticketing database for movies, venues, screens, shows, customers, offers, bookings, seats sold and reviews. It must protect seat availability and payment state during checkout while supporting customer lookups and cinema, distributor and finance reporting. The seed covers 1 April–7 July 2026; expected growth is 20×.

| Problem | Business need and stakeholder | Class |
|---|---|---|
| P1 | Quickly find currently showing movies and showtimes for movie-goers; programming teams need the schedule searchable. | Customer-facing / real-time |
| P2 | Render a screen’s seats and reserve each seat at most once per show for movie-goers and the booking engine. | Customer-facing / real-time |
| P3 | Find pending payments, confirm paid bookings and release expired seat locks for payments and seat-lock services. | Customer-facing / real-time |
| P4 | Retrieve bookings and authenticate by phone for movie-goers and support agents. | Customer-facing / real-time |
| P5 | Measure occupancy, identify cleaning gaps and seats that never sell for cinema/venue managers. | Reporting / analytics |
| P6 | Identify offers that have not been redeemed for the partnerships team. | Reporting / analytics |
| P7 | Report collections and ticket counts by movie/show for distributors. | Reporting / analytics |
| P8 | Provide revenue, regional, rating, loyalty, booking-pattern and cancellation reports for finance and insights teams. | Reporting / analytics |

## Assumptions

- A show occupies a single screen from `starts_at` up to, but not including, `ends_at`; adjacent shows may touch at an endpoint.
- A seat is uniquely identified by `seat_id`, but its row and number are only unique within a screen. Its sale uniqueness is `(show_id, seat_id)`.
- `booking_seats` is the set of seats held by a booking. In this seed, confirmed bookings have one row per ticket and cancelled or failed bookings have none. Pending bookings can be incomplete while checkout is in progress.
- Booking amounts are stored in currency units to two decimal places. The seed uses a 10% convenience fee and `total_amount = ticket_amount + convenience_fee + fnb_amount - discount`.
- A missing offer code means no offer was applied; a missing review text means a rating-only review. Both are nullable by design.
- Show end times are retained as supplied. They need not be recalculated from movie duration because schedules can include intermissions, trailers or operational buffers.
- Foreign keys preserve historical transactions: referenced cities, venues, screens, shows, customers, movies and offers cannot be deleted while referenced. Seat rows can be deleted only when not sold; deleting a booking cascades to its held-seat rows.