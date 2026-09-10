# Performance and translation update — 10 September 2026

Changes are incremental to the user's existing staged changes. No deployment or migration was performed.

- Dashboard mapped-farmer SQL no longer joins AFLs and calculates three unused distinct aggregates. Displayed ICS, village and farmer counts still use their original separate scopes.
- ICS/village totals count distinct location tuples in PostgreSQL instead of transferring a grouped hash into Ruby. Null handling, location columns and visibility filters are preserved.
- Training target mapping results and active master rows are reused within each request. No shared user-data cache or new stale-data interval was introduced.
- Repeated list-field name/alias calculations are reused; first-present lookup stops at the first nonblank value.
- Bill List applies the existing month/status/state predicates before expensive row details and totals. Month choices still come from all visible bills. Admin default behavior and visibility predicates are retained.
- Language selection waits for Google's asynchronously created options, cancels stale selections, supports English restoration and widget recreation after navigation, and retries script failures on a later selection. Newly inserted UI is translated without repeatedly scanning the full page. Google widget markup is excluded from the local text translator. Button binding also works for cloned Turbo snapshots.

## Local measurements

Single samples on local development data, separate Ruby processes. The baseline used the original staged controller/view, without changing the working tree. These are not production latency guarantees; warm database caches and sample size affect timings.

| Measurement | Before | After |
| --- | ---: | ---: |
| Dashboard controller only | 1,095 ms | 707 ms |
| Dashboard SQL | 193 ms | 100 ms |
| Training Form ERB | 604 ms | 476 ms |
| Training Form SQL notifications | 48 | 40 |
| Bill List ERB, August filter | 1,487 ms | 228 ms |
| Bill List SQL notifications, August filter | 62 | 31 |
| Training Form List ERB | 151 ms | 144 ms |

The August Bill List sample had no matching displayed bills: it demonstrates avoiding work for excluded records, not populated-list throughput. Training Form List's small timing difference is inconclusive. Dashboard query count stayed at 136; its queries do less work. The unfiltered participation report also rendered successfully (256 ms controller + 39 ms ERB); no before/after performance claim is made for it.

`script/profile_module_page.rb` profiles controller + ERB in a read-only database transaction. It excludes layout, authentication callbacks, network and browser time; reports SQL fingerprints without personal values. Production-scale browser profiling remains necessary for the reported 4–14 second rendering cases.

## Validation

- 41 targeted database tests, 187 assertions: passed (dashboard, ICS filters, bill visibility, Other Activity and JJ dashboard API).
- 5 database-free tests, 14 assertions: passed. Corrected an outdated test stub to accept the existing `totals_only` keyword.
- 4 JavaScript tests: passed (delayed options, rapid selections/English, replaced widget holder, script failure and bounded retries).
- Ruby and JavaScript syntax and diff whitespace checks passed.
- Broader VRP suite: 11 failures. The unchanged staged baseline also has 11 failures in that suite, including login/permission redirects, dashboard expectations and date-sensitive bill expectations. These unrelated business behaviors were not changed.
- Live Google service/browser interaction was not tested end to end. Local labels update immediately; Google's remaining translation depends on script/service network latency.

The React Native handoff is in `docs/react-native-translation-api.md`. The existing browser widget is not a native JSON API; the document supplies the official Cloud Translation API request/response and setup requirements. No Google Cloud credentials or mobile proxy endpoint were created.
