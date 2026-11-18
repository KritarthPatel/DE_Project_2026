# Optimization report

Measured on 18 November 2026 with PostgreSQL 18.4 (Postgres.app), Apple ARM64, session TimeZone `Asia/Kolkata`, database `de_project_2026_benchmark`. All 11 seed-table counts matched and all supplied integrity checks passed. No server tuning or data changes were used. Each query has exactly **three** `EXPLAIN (ANALYZE, BUFFERS)` measurements; writes use `BEGIN`/`ROLLBACK`.

The sum of average execution times fell from the committed baseline's **4885.223 ms** to **475.266 ms** (90.27% reduction). The original `capstone` database and its machine/version metadata were unavailable. A fresh, untuned baseline on this machine totals **2000.123 ms**, giving a controlled local reduction of **76.24% (4.21×)**. The original baseline remains unchanged. These sums describe this workload, not throughput or end-to-end application latency. Three runs are a small sample; cache state and host load affect results.

Reproduce on an empty database after loading `sql/01_schema.sql` and `sql/02_load_data.sql`:

```bash
bash benchmarks/run_benchmark.sh de_project_2026_benchmark baseline_local 3
psql -X -v ON_ERROR_STOP=1 -d de_project_2026_benchmark -f sql/05_indexes.sql
bash benchmarks/run_benchmark.sh de_project_2026_benchmark optimized 3 sql/06_optimized_queries.sql
python3 benchmarks/verify_optimized.py | psql -X -q -d de_project_2026_benchmark
```

Use the same session timezone for both workloads. `05_indexes.sql` includes VACUUM/ANALYZE, so run it outside a transaction. The optimized results represent the final full three-run benchmark, including regressions; earlier exploratory timings were not selected to improve the comparison.

| Query | Committed before (ms) | Local before (ms) | Problem found in plan | Optimization applied | After (ms) | Improvement vs committed / local | Same result? |
|---|---:|---:|---|---|---:|---:|---|
| R01 | 13.881 | 6.563 | Date cast filters shows after access | Half-open timestamp range; covering shows_start_idx | 0.411 | 97.0% / 93.7% | EXCEPT ALL: equal |
| R02 | 9.702 | 4.237 | Movie/date filtering via screen index | Movie then start-time B-tree | 0.142 | 98.5% / 96.6% | SQL unchanged |
| R03 | 0.826 | 0.254 | Already indexed seat/show lookup | Additional screen/seat index; existing PK probes | 0.253 | 69.4% / 0.4% | SQL unchanged |
| R04 | 0.158 | 0.030 | Already unique booking-code lookup | Unchanged; existing unique index | 0.041 | 74.1% / -36.7% | SQL unchanged |
| R05 | 22.924 | 7.013 | Full bookings scan for one customer | Partial confirmed customer index | 0.104 | 99.5% / 98.5% | SQL unchanged |
| R06 | 0.194 | 0.125 | Scans 300 movie titles | Unchanged; tiny table does not justify GIN maintenance | 0.128 | 34.0% / -2.4% | SQL unchanged |
| R07 | 4.365 | 0.791 | Date cast prevents timestamp range scan | Half-open range; screen/start covering index | 0.100 | 97.7% / 87.4% | EXCEPT ALL: equal |
| R08 | 34.387 | 12.595 | Scans bookings and shows | Date and confirmed-show covering indexes | 5.114 | 85.1% / 59.4% | SQL unchanged |
| R09 | 12.294 | 5.362 | Scans bookings then sorts pending queue | Small pending timestamp covering index | 0.013 | 99.9% / 99.8% | SQL unchanged |
| R10 | 482.141 | 243.002 | Self-join compares many same-screen pairs | Bound s2.starts_at directly; screen/start index | 37.490 | 92.2% / 84.6% | EXCEPT ALL: equal |
| R11 | 93.898 | 47.126 | Aggregates all sold seats | Unchanged; full scans remain appropriate | 48.904 | 47.9% / -3.8% | SQL unchanged |
| R12 | 128.659 | 69.330 | Large confirmed-booking join and grouping | Unchanged; full scans and aggregation remain | 117.834 | 8.4% / -70.0% | SQL unchanged |
| R13 | 29.131 | 13.382 | NOT IN with nullable subquery returns no rows | Correct to indexed NOT EXISTS | 0.108 | 99.6% / 99.2% | Intentional bug fix |
| R14 | 10.382 | 5.389 | Aggregates reviews across movies | Unchanged; broad aggregation | 4.886 | 52.9% / 9.3% | SQL unchanged |
| R15 | 193.018 | 35.896 | Extracts time parts for every booking | Unchanged; all rows contribute | 35.514 | 81.6% / 1.1% | SQL unchanged |
| R16 | 38.370 | 19.023 | Joins June shows to bookings | Date covering index for shows | 18.147 | 52.7% / 4.6% | SQL unchanged |
| R17 | 67.555 | 29.591 | Scans sold seats for anti-join | Seat/show reverse index supports targeted probes | 0.359 | 99.5% / 98.8% | SQL unchanged |
| R18 | 133.488 | 54.467 | Year extraction and full joins | Half-open year range removes per-row extraction | 43.677 | 67.3% / 19.8% | EXCEPT ALL: equal |
| R19 | 3118.571 | 1229.779 | Repeated full booking scans per show | LEFT JOIN plus GROUP BY; two covering indexes | 0.335 | 100.0% / 100.0% | EXCEPT ALL: equal |
| R20 | 27.903 | 14.613 | Date casts scan confirmed bookings | Half-open range; covering confirmed-time index | 6.196 | 77.8% / 57.6% | EXCEPT ALL: equal |
| R21 | 86.252 | 39.487 | Groups most confirmed bookings | Unchanged; all qualifying bookings contribute | 46.144 | 46.5% / -16.9% | SQL unchanged |
| R22 | 87.197 | 38.771 | Sorts entire table before deep OFFSET | Covering timestamp index; retain page semantics | 6.521 | 92.5% / 83.2% | SQL unchanged |
| R23 | 0.045 | 0.023 | Already unique mobile lookup | Unchanged; existing unique index | 0.024 | 46.7% / -4.3% | SQL unchanged |
| R24 | 111.609 | 58.895 | Aggregates every sold seat | Unchanged; full scans remain appropriate | 64.933 | 41.8% / -10.3% | SQL unchanged |
| R25 | 50.949 | 24.378 | Scans shows and sold seats | Date covering index; time predicate still residual | 22.968 | 54.9% / 5.8% | SQL unchanged |
| W01 | 1.141 | 0.607 | Single insert and FK checks | Query unchanged; extra index maintenance | 0.932 | 18.3% / -53.5% | SQL unchanged |
| W02 | 38.275 | 9.883 | Scans seat IDs until target screen is found | Pending minimum index; planner still scans seats_pkey | 11.279 | 70.5% / -14.1% | SQL unchanged |
| W03 | 20.549 | 0.590 | Finds minimum pending booking via PK | Partial pending booking-id index | 0.463 | 97.7% / 21.5% | SQL unchanged |
| W04 | 55.476 | 23.885 | Scans bookings and booking seats | Pending and booking-id indexes | 0.112 | 99.8% / 99.5% | SQL unchanged |
| W05 | 11.883 | 5.036 | Full shows scan for one movie | Movie/start index; weekday filter remains residual | 2.134 | 82.0% / 57.6% | SQL unchanged |
| **Total** | **4885.223** | **2000.123** | | | **475.266** | **90.27% / 76.24%** | |

**Correctness evidence.** [Verification output](../benchmarks/results/optimized/equivalence.csv) records counts and bidirectional `EXCEPT ALL` differences for every rewritten query. The [verification generator](../benchmarks/verify_optimized.py) uses a single repeatable-read snapshot and preserves duplicate multiplicities. R01: 93→93, R07: 17→17, R10: 209→209, R18: 80→80, R19: 207→207, R20: 30→30; each has zero different rows. ORDER BY expressions are unchanged, so specified ordering is preserved; equal sort keys remain unspecified. R19 retains zero-booking shows via LEFT JOIN and COALESCE. R10 retains all qualifying pairs rather than substituting LEAD, which would impose consecutive-only semantics. Date boundaries retain the session-timezone meaning of the original date/year casts. All five write statements are unchanged.

R13 intentionally changes from zero to seven rows: 127,659 bookings have a NULL offer_code. An unmatched value compared with `NOT IN` against a set containing NULL evaluates to UNKNOWN and is rejected by WHERE. `NOT EXISTS` correctly returns the seven offers without matching redemptions. This is the explicit correctness exception required by the project brief, not an equivalent rewrite.

R22 retains OFFSET 100000 rather than inventing a cursor. Its existing ORDER BY booked_at is not unique, so tied timestamps can produce different row choices/order across plans, especially at page boundaries. The same ambiguity exists in LIMIT queries R14/R25. No deterministic tie-breaker was added because that would modify the supplied contract.

**Why the major gains occur.** The following are the five largest absolute reductions against the local baseline. Each link contains all three complete plans, including buffer counts; the excerpts show the change in access paths. Original committed plans are also retained under `benchmarks/results/baseline/`.

- **R19**: 1229.779 → 0.335 ms. [Before plan](../benchmarks/results/baseline_local/R19.txt), [after plan](../benchmarks/results/optimized/R19.txt). Before: `Seq Scan on shows | Seq Scan on bookings`. After: `Index Only Scan using shows_movie_start_idx on shows | Index Only Scan using bookings_confirmed_show_idx on bookings`.
- **R10**: 243.002 → 37.490 ms. [Before plan](../benchmarks/results/baseline_local/R10.txt), [after plan](../benchmarks/results/optimized/R10.txt). Before: `Seq Scan on shows`. After: `Index Scan using shows_start_idx on shows | Index Only Scan using shows_screen_start_idx on shows`.
- **R22**: 38.771 → 6.521 ms. [Before plan](../benchmarks/results/baseline_local/R22.txt), [after plan](../benchmarks/results/optimized/R22.txt). Before: `Seq Scan on bookings`. After: `Index Only Scan using bookings_newest_idx on bookings`.
- **R17**: 29.591 → 0.359 ms. [Before plan](../benchmarks/results/baseline_local/R17.txt), [after plan](../benchmarks/results/optimized/R17.txt). Before: `Seq Scan on booking_seats | Seq Scan on shows | Index Scan using seats_screen_id_row_label_seat_number_key on seats`. After: `Index Scan using seats_screen_id_row_label_seat_number_key on seats | Index Only Scan using booking_seats_seat_show_idx on booking_seats | Index Scan using shows_pkey on shows`.
- **W04**: 23.885 → 0.112 ms. [Before plan](../benchmarks/results/baseline_local/W04.txt), [after plan](../benchmarks/results/optimized/W04.txt). Before: `Seq Scan on booking_seats | Seq Scan on bookings`. After: `Index Scan using bookings_pending_id_idx on bookings | Index Scan using booking_seats_booking_idx on booking_seats`.

R19 replaces hundreds of repeated full booking scans with indexed show/booking lookups and grouped sums. R10's direct upper bound allows a bounded index range for each screen. R17 probes sold seats by seat_id instead of building a broad anti-join. R22 reads the timestamp index in order without a large sort, although its OFFSET still consumes 100,025 index entries. W04 finds the tiny pending subset and probes held seats by booking_id. There are only ten pending bookings, which explains the especially strong partial-index gains and limits extrapolation to a much larger pending queue.

**Write overhead and regressions.** Comparisons here use the local baseline to avoid attributing machine differences to indexes.

- W01: 0.607 → 0.932 ms (+0.325 ms, +53.5%).
- W02: 9.883 → 11.279 ms (+1.396 ms, +14.1%).
- W03: 0.590 → 0.463 ms (-0.127 ms, -21.5%).
- W04: 23.885 → 0.112 ms (-23.773 ms, -99.5%).
- W05: 5.036 → 2.134 ms (-2.902 ms, -57.6%).

W01 maintains additional booking indexes and shows a measurable insert regression; this is a reasonable tradeoff for the large lookup/report savings on this seed workload, but does not establish concurrent production throughput. W02 still scans seats_pkey and rejects many unrelated seats; the added `(screen_id, seat_id)` index is selected by R03 but did not persuade the planner to use the desired W02 access path. Its regression cannot be attributed solely to index maintenance. Status updates also maintain membership in partial indexes, and booking-seat writes maintain both extra indexes.

R11, R12, R21 and R24 regress locally while retaining broad scans and aggregation. In particular R12 has no query rewrite and still groups many confirmed bookings; these measurements do not prove an index-caused slowdown. R15 is essentially unchanged. R04/R06/R23 are already tiny, so small absolute fluctuations yield misleading percentage changes. No claim of improvement is made for every query. Full-table reports must still process most input rows; summary tables would require an explicit freshness policy. No GIN index was added for the 300-row movie table.

**Index storage.** Measured with `pg_relation_size` after the final benchmark; table bytes refer to the heap only, excluding TOAST and existing indexes. Covering indexes trade space and write work for fewer heap accesses; visibility-map benefits depend on vacuuming in a changing database.

| New index | Table | Index bytes | Table heap bytes | Index / heap |
|---|---|---:|---:|---:|
| booking_seats_booking_idx | booking_seats | 4915200 | 16121856 | 30.5% |
| booking_seats_seat_show_idx | booking_seats | 6766592 | 16121856 | 42.0% |
| bookings_confirmed_customer_idx | bookings | 1875968 | 17891328 | 10.5% |
| bookings_confirmed_show_idx | bookings | 4243456 | 17891328 | 23.7% |
| bookings_confirmed_time_idx | bookings | 4251648 | 17891328 | 23.8% |
| bookings_newest_idx | bookings | 10149888 | 17891328 | 56.7% |
| bookings_offer_idx | bookings | 180224 | 17891328 | 1.0% |
| bookings_pending_id_idx | bookings | 16384 | 17891328 | 0.1% |
| bookings_pending_time_idx | bookings | 16384 | 17891328 | 0.1% |
| seats_screen_id_idx | seats | 2121728 | 4915200 | 43.2% |
| shows_movie_start_idx | shows | 6529024 | 11534336 | 56.6% |
| shows_screen_start_idx | shows | 7962624 | 11534336 | 69.0% |
| shows_start_idx | shows | 6561792 | 11534336 | 56.9% |

Total new index storage: **55,590,912 bytes**. Raw storage measurements: [index_sizes.csv](../benchmarks/results/optimized/index_sizes.csv). No existing constraint indexes were removed.
