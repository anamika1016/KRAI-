# Application performance audit — supplied September 9 journal

This is a source review and analysis of the supplied journal, not a production
load test. Request IDs were used to associate interleaved start/completion lines.
Query parameters, credentials and user data are omitted.

| Route | Samples | Observed duration |
| --- | ---: | ---: |
| Bill List | 1 | 28.675 s |
| Dashboard, including filters | 10 | 5.254–12.157 s; mean 9.272 s |
| Farmer training participation | 10 | 2.307–10.868 s; mean 5.406 s |
| Payment List | 1 | 6.325 s |
| Training Form List | 1 | 4.615 s |
| Farmer Participation Report | 1 | 4.125 s |
| Demonstration Method | 2 | 3.741–3.794 s |
| Training Form | 1 | 3.094 s |
| Target Mappings | 1 | 1.662 s |
| VRP List | 2 | 0.108–0.109 s |
| AFL List | 2 | 0.026–0.038 s |
| Login POST | 2 | 0.010–0.014 s |

The login redirect leads to the slow dashboard. The journal does not demonstrate
slow credential lookup. No API request timings were present in the parsed sample.

## Implementation bottlenecks

1. `ModulesController#dashboard` loads all visible targets and VRPs before Ruby
   filtering. Cascading dropdowns depend on intermediate populations, so pushing
   all filters into a single initial SQL scope would change their behavior.
2. `preload_jeevika_bill_process_totals` calls `jeevika_jankar_bill_rows` for every
   bill month. That method hydrates farmers, builds training indexes and constructs
   per-farmer detail hashes even when the caller needs only target/achievement
   totals. Bill List's logged view time is 27.128 s versus 1.190 s ActiveRecord.
   Preserve the existing grouping, month fallbacks and payment calculation when
   separating totals from detail generation.
3. `farmer_training_participation` calculates all card counts, obtains the entire
   selected list, then slices it for pagination. Yellow/green card SQL is already
   shared in this checkout. Moving slicing into SQL must preserve sorting, total
   counts, exported rows, status aliases and existing access scopes.
4. `CcJjWorkStatusReport#summary` executes summary SQL and then full detail SQL
   through `rows`, merely to find FCOs missing from the summary. A narrower query
   must reproduce the exact detail population before this can be replaced.
5. `TargetMappingsController#index` loads and groups all matching mappings; many
   module tables use browser pagination after all rows have been rendered. This
   does not bound server CPU or HTML size. AFL's ordinary list already uses SQL
   pagination and is fast in this log; do not indiscriminately rewrite it.
6. `Api::V1::UserDashboardController#filters` invokes the complete cached dashboard
   builder for filter options. Cold cache and invalidation therefore incur the
   full dashboard cost. Any separate option builder must preserve cascading
   filters and user-scoped visibility. API latency remains unmeasured.
7. Login lookups already have indexed paths. Production enables eager loading and
   caching. Increasing Puma workers without available RAM and database connection
   capacity may worsen contention; production capacity information is unavailable.

## Scope and next validation

The user subsequently authorized internal optimization while preserving behavior.
Bill totals now skip unused farmer display/evidence construction, retaining the
existing target selection, fallback and progress calculations. CC/JJ summary
uses a scoped distinct-FCO query instead of generating all detail rows solely
for FCO membership. No UI, authentication, approval or payment rules were edited.
The three-index migration remains part of this patch.

Further optimization should compare old/new totals and row membership for
admin and restricted users, mixed training/other activities, legacy month values,
and missing assignments. Then measure full HTML requests and API responses for
matching users and filters. A controller-only microbenchmark cannot establish
rendering performance or concurrent-user capacity.

## Verification of the authorized optimizations

- Focused regression suite: 27 tests, 154 assertions, all pass. Includes full
  versus totals-only bill calculation, scoped dashboard/ICS behavior, report
  status counts, payment visibility and user dashboard list APIs.
- Broader dashboard/login/API suite: 57 tests, 310 assertions, 11 failures and
  2 errors. Running the original methods saved before editing reproduces the
  exact same failing test names and summary. The two login test errors reference
  missing `Minitest::Mock`. These existing failures remain unresolved; this is
  not a claim that the entire application test suite passes.
- Local full-render comparison, original versus optimized methods, same data:

| Page | Before | After |
| --- | ---: | ---: |
| August dashboard | 1569.11 ms | 1447.54 ms |
| August dashboard, FCO 1004 | 1055.92 ms | 762.64 ms |
| Bill List | 2986.99 ms | 2208.74 ms |
| Payment List | 2449.05 ms | 2284.87 ms |

Bill and payment totals have identical serialized SHA-256 digests before/after.
All four rendered pages have matching HTML byte lengths (not a byte-for-byte
content assertion). These are single local samples, including template/layout
rendering but not HTTP middleware/network time, and do not establish production
performance or load capacity. Migration applied to local development and test;
no production deployment occurred. Syntax and diff whitespace checks pass.
