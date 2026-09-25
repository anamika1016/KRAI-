# September 25 performance fixes

The supplied Puma journal contains 71 slow pending-approval queries, totalling
301,334 ms (maximum 14,465 ms). These run from the shared sidebar on dashboard,
JJ, AFL, Target Mapping, user lists and forms. Login credential checking itself
was 6–9 ms; the subsequent dashboard was slow. These are observed request samples,
not a controlled production benchmark.

## Changes

- Sidebar badges, approval lists and training-list status cells load read-only
  approval metadata. Embedded image evidence, before/proposed snapshots and
  history remain stored and are loaded in full for review and decisions.
- Legacy pending requests still auto-route using a complete locked record. Staff
  is fetched lazily once per list. Later staff assignments are still reconsidered.
- Dashboard bill loading reuses the existing bill-list projection, excluding
  nested farmer detail arrays that dashboard filters/counts do not consume.
  Bill detail and print pages retain their full records.
- Shared JJ lookup primes existing creator identity caches in batches, reducing
  repeated identity queries in dashboard/bill/target visibility checks.
- Training form CC and Agronomist options share a request-local staff catalogue.

No pagination, authorization, status, payment, filter or business rules were
intentionally changed. No persistent cross-request cache was added. Existing
1095/Pavijetpur changes were preserved.

## Validation

Focused approval, bill rendering and dashboard performance suite: 23 tests,
129 assertions, zero failures/errors. New tests cover projected visibility,
requester access, single-query routed requests, evidence preservation and legacy
routing after later staff assignment.

Broader dashboard, ICS, VRP, API-list and farmer suite: 51 tests, 209 assertions,
16 failures. Loading the saved pre-change methods reproduces all 16 failing test
names (baseline runner: 52 tests, 213 assertions). There are no additional failing
names, but the application test suite is not green.

Local uncached controller+layout samples, same development data; profiling is
wrapped in a rolled-back transaction. SQL query counts exclude schema/cache hits.

| Page | Before ms | After ms | Before queries | After queries |
| --- | ---: | ---: | ---: | ---: |
| Dashboard, August training | 408 | 220 | 148 | 69 |
| Training approval list | 17 | 13 | 10 | 6 |
| Training form list | 102 | 93 | 12 | 8 |
| JJ list | 50 | 47 | 16 | 14 |
| Target Mapping | 113 | 113 | 13 | 11 |
| User list | 130 | 169 | 10 | 8 |
| User registration | 282 | 275 | 9 | 7 |
| Bill list | 446 | 470 | 66 | 68 |

All eight samples rendered HTTP 200 and retained their HTML byte lengths; this
is not a byte-for-byte content assertion. Single samples include warmup/noise;
they do not establish a speedup for user/Target Mapping/bill pages or production.
The three local approval records total 1,660,393 bytes, versus 1,123 bytes for the
metadata projection. Production evidence may be substantially larger.

## Deployment and remaining limits

These changes are local, not deployed. Deploy the code and restart Puma through
the normal release process. No new migration is required by this patch. Verify
that existing September 24 lookup-index migrations have already run in production.

Capture comparable production timings after deployment, especially concurrent
requests, bill lists and large filtered lists. Several tables still render all
rows before browser pagination; changing this needs a separate implementation
that preserves search, export, selection and filtering. Existing reporting SQL
and server resource contention can remain slow. This patch does not claim to
eliminate every application performance issue.
