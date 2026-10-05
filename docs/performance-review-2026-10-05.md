# Performance review: 5 October 2026

## Findings from the supplied production logs

The 232–248 second requests are `ModulesController#show` for
`/modules/training-form`. The logged `send_bill_for_approval` requests complete
in 116–989 ms. The 246.9 second completion belongs to a different request ID;
its start is outside the supplied excerpt. It cannot be attributed to the
approval action from adjacent log lines.

Training-form requests spend most of their time rendering, with substantial
GC time. Master pages load the complete location catalogue for dependent
dropdowns. Bill and dashboard lookups also reuse legacy names and phone numbers.
There are already numerous performance indexes, batched bill totals, eager
loads, and on-demand training farmer loading in this checkout.

## Changes

- Location catalogue reads pluck ID and serialized data into lightweight rows,
  avoiding full Active Record instantiation. Rows and the combined catalogue
  are reused within the request. All rows, ordering, aliases, value types and
  existing Ruby active/deleted filtering remain intact.
- Gram-panchayat fallback resolution builds a location/code index once instead
  of scanning candidates for each village. The first candidate still wins.
- Legacy JJ lookups build exact-label and lowercase-name indexes. ID matching
  still takes priority; collisions preserve the original candidate order.
- Approval-channel records and approver options load once per request,
  removing repeated queries and allocations across form/list rows.
- A concurrent composite index supports `vrp_id` plus
  `LOWER(BTRIM(month_name))`, matching the existing bill/target query expression.

No pagination, response fields, approval rules, target calculations or business
filters were changed. No shared cache was added.

## Verification

- Targeted lookup, bill rendering, dashboard and FCO suites: **31 tests,
  113 assertions, zero failures/errors**.
- Query-count tests verify that repeated location, approval-channel and
  approver-option reads each execute one query within the request.
- Synthetic benchmark: 3,000 location candidates and 300 fallback lookups:
  original scan **1.955 s**, indexed lookup **0.069 s**, including index build.
  These numbers measure the lookup, not a production page.
- Broader checks expose existing failures in sorting/training tests (two
  failures and one error) and an API fixture lacking a valid target quantity
  (one error). These were reproduced with the original controller from HEAD.
- `git diff --check` passes. Migration was applied to the local test database.

## Deployment and remaining measurement

Apply the migration during the normal deployment:

```sh
RAILS_ENV=production bundle exec rails db:migrate
```

Production was not changed or benchmarked. Compare the same routes, roles,
filters and data volume after deployment, recording total time, SQL duration,
query count, GC time and response size. The full location catalogue still
travels to the browser to preserve the current behavior. If large payloads
remain dominant, profile their rendering and JSON serialization before deciding
on further changes. There is no measured end-to-end speedup for every listed
page yet.
