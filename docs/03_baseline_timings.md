# Baseline query timings

Each workload query was measured three times with `EXPLAIN (ANALYZE, BUFFERS)` using `benchmarks/run_benchmark.sh capstone baseline 3`. Write queries ran inside a transaction that was rolled back after each run. The average is the arithmetic mean reported by the benchmark summary, rounded to three decimal places.

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Home page: movies showing in Bengaluru on 2 July 2026 and how many shows each has | READ | 18.320 | 13.355 | 9.967 | 13.881 |
| R02: Showtimes page: shows of movie 2 in Bengaluru on 2 July 2026, grouped by cinema | READ | 11.240 | 8.980 | 8.887 | 9.702 |
| R03: Seat layout: every seat of show 144446 and whether it is already sold | READ | 0.816 | 0.598 | 1.065 | 0.826 |
| R04: Support: open a booking by its code | READ | 0.132 | 0.163 | 0.180 | 0.158 |
| R05: "My bookings": customer 1331's upcoming confirmed shows | READ | 26.655 | 21.537 | 20.581 | 22.924 |
| R06: Search: movies whose title contains "kalki" | READ | 0.173 | 0.172 | 0.237 | 0.194 |
| R07: Cinema dashboard: occupancy of every show at venue 11 on 28 June 2026 | READ | 4.779 | 4.167 | 4.150 | 4.365 |
| R08: Box office: top 10 movies by collections over the weekend of 26–28 June 2026 | READ | 41.154 | 30.988 | 31.020 | 34.387 |
| R09: Seat-lock service: bookings still PENDING more than 10 minutes after they were made (checked at 23:59, 30 Jun 2026) | READ | 12.209 | 12.492 | 12.180 | 12.294 |
| R10: Cinema operations: consecutive shows on the same screen with less than 30 minutes for cleaning (June 2026) | READ | 476.040 | 486.941 | 483.441 | 482.141 |
| R11: Revenue mix: share of ticket revenue from recliner seats, per screen type | READ | 94.364 | 92.008 | 95.323 | 93.898 |
| R12: Fans: customers who booked the same movie more than once | READ | 116.829 | 140.790 | 128.359 | 128.659 |
| R13: Partnerships: offers that have never been redeemed | READ | 28.095 | 29.104 | 30.194 | 29.131 |
| R14: Movie pages: average user rating of 2026 releases with at least 20 reviews | READ | 10.091 | 10.463 | 10.593 | 10.382 |
| R15: Capacity planning: bookings by weekday and hour of booking | READ | 191.617 | 192.028 | 195.408 | 193.018 |
| R16: Cinema partners: cancellation rate per venue for June 2026 shows | READ | 38.153 | 39.249 | 37.709 | 38.370 |
| R17: Cinema operations: seats of screen 101 that were never sold for any June 2026 show | READ | 67.028 | 67.545 | 68.091 | 67.555 |
| R18: Regional insights: collections per language per city in 2026 | READ | 133.410 | 134.563 | 132.491 | 133.488 |
| R19: Distributor report: tickets sold for every June 2026 show of movie 2 | READ | 3162.697 | 3099.930 | 3093.085 | 3118.571 |
| R20: Finance: daily collections and running total for June 2026 | READ | 27.524 | 27.559 | 28.627 | 27.903 |
| R21: Loyalty: 20 customers with the most confirmed bookings in 2026 | READ | 80.723 | 89.855 | 88.179 | 86.252 |
| R22: Support console: all bookings, newest first, page 4,001 (25 per page) | READ | 86.117 | 89.176 | 86.298 | 87.197 |
| R23: Sign-in with mobile number | READ | 0.044 | 0.044 | 0.046 | 0.045 |
| R24: Pricing: average price paid per seat class in each city (2026) | READ | 113.095 | 112.118 | 109.615 | 111.609 |
| R25: Programming: average occupancy of late-night shows (starting 22:30 or later) in June 2026 | READ | 50.201 | 50.857 | 51.790 | 50.949 |
| W01: Checkout: create a PENDING booking for 2 tickets of show 144446 | WRITE | 1.264 | 1.096 | 1.064 | 1.141 |
| W02: Seat lock: the oldest PENDING booking adds 2 more seats (the unsold seats with the lowest ids in its show) | WRITE | 38.443 | 37.646 | 38.737 | 38.275 |
| W03: Payment callback: confirm the oldest PENDING booking | WRITE | 21.113 | 19.958 | 20.576 | 20.549 |
| W04: Seat-lock expiry: release seats held by PENDING bookings older than 10 minutes | WRITE | 54.040 | 57.406 | 54.982 | 55.476 |
| W05: Pricing: 10% higher prices for all July weekend shows of movie 2 | WRITE | 11.946 | 11.579 | 12.124 | 11.883 |
