# Dashboard and bill-view fixes — 11 September 2026

The supplied production journal shows August dashboard filter requests taking
6,210–6,310 ms and an unfiltered dashboard taking 8,860 ms. Bill detail requests
fail with `undefined method 'jeevika_bill_approver_display_name'` in the approval
progress section of `modules/show`.

Changes:

- Expose the existing approver display method to views. The bill integration
  regression now renders an actual approval step and its formatted name.
- Reuse approval-label normalization within each controller request. Local
  profiling found 20,056 calls to label expansion on one dashboard request.
- Materialize the demonstration summary's selected training creator/method
  fields before its FCO join and four counters, reducing repeated parsing of
  large JSON form payloads. Month, creator, grouping and count semantics remain
  unchanged.
- Reuse JJ target records already loaded for the dashboard. Resolve missing
  training-form mapping references in batches without first loading the entire
  visible dashboard target population.

No data migration, shared cache TTL change, filter-rule change, or production
deployment is included.

## Local validation

Original HEAD and updated code were run in separate processes against the same
development database in read-only transactions, three requests per process.
The compared card/summary/target-row/dropdown payload checksums match for both
admin and JJ dashboards.

| Controller measurement | Original samples (ms) | Updated samples (ms) |
| --- | --- | --- |
| Admin dashboard | 779, 599, 456 | 517, 284, 302 |
| JJ dashboard | 386, 273, 295 | 488, 345, 282 |

Admin median fell from 599 to 302 ms. JJ timings are inconclusive and do not
demonstrate a speedup on this small local dataset. Query counts were unchanged
in these samples. These exclude rendering, authentication and network time;
they are not production latency guarantees. A separate benchmark using the
exact screenshot filters was not run because its execution was declined.

The focused suite had 58 passing tests and one new fixture setup error; after
fixing the fixture, all eight performance tests passed (34 assertions), covering
the previously failing test. Together the 59 focused cases pass, including bill
rendering/visibility, cascading ICS filters, demonstration counts, JJ mobile
dashboard and Other Activity progress. Ruby syntax and diff whitespace pass.

The additional admin-dashboard API test has an existing display-label failure:
it expects `View List`, while the page says `viwe list`. The unchanged HEAD code
reproduces that failure. It is unrelated to these changes.

Deploy the code through the normal release process and restart Puma to load the
helper fix. Then verify bill detail `view_id=7836` and measure the August
Sausar/Turekela filters and JJ dashboard under production load.
