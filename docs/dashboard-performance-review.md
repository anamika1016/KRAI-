# Dashboard and Jeevika payment review

The supplied production logs show login POST responses around 7–17 ms, but admin dashboard requests around 35–38 seconds, mostly ActiveRecord time. The reported Bill List request executed 1,167 queries and Payment List 578. These are production observations from the supplied log, not results from the modified code.

Changes:

- Completed-payment rows use assigned JJ visibility, including the shared API helper. Being a bill approver no longer grants unrelated completed-payment rows. Admin visibility remains global.
- Sub-activity choices follow month and selected location/user filters. Stale sub-activity selections are discarded instead of falling back to all main activities. Web and admin API use the same option helper.
- Other Activity shows target quantity, approved completion (capped at target), and pending for the filtered month/scope. Training-only dashboard calculations and Demonstration Method cards are skipped for this view.
- Bill List calculates process totals once per month across listed JJs, reuses monthly training records, and preserves individual JJ matching/fallback behavior. Bill Process behavior is unchanged.
- JJ creator identities, profile and photo associations are preloaded. API target achievements are indexed once instead of scanning records per target.
- Monthly count queries skip unused training record hydration. Yellow/green attendance totals share one grouped SQL query. Large JSON-derived joins explicitly materialize their intermediate sets.
- Concurrent expression indexes support existing normalized FCO filters. New slow-query logging emits duration and a SQL fingerprint for queries >= 200 ms, without SQL literals.

Validation and limits:

- Before later SQL/index changes, the selected database suite ran 31 tests: 30 passed; the API test failed because `target_dashboard` was absent. That response section has now been restored using its existing payload method, with batched lookup. Its database retest remains pending.
- Database-free regression checks cover month/location options, Other Activity totals, assignment visibility, and avoiding unused monthly training hydration.
- Local admin controller profiling measured 1.963 seconds / 137 SQL notifications before changes and 1.812 seconds / 138 at an intermediate revision. These include neither view rendering nor production-sized data and are not a final performance claim. Final full database validation was blocked when automatic approval review hit its usage limit.
- The new migration was applied successfully to the local development database. Test and production migration/validation remain pending. No deployment was performed.

After database execution is available, run:

```sh
RAILS_ENV=test bin/rails db:migrate
bin/rails test test/controllers/jeevika_visibility_test.rb test/controllers/dashboard_loading_performance_test.rb test/controllers/modules_controller_dashboard_test.rb test/controllers/other_target_dashboard_progress_test.rb test/controllers/api/v1/jeevika_jankar_dashboard_controller_test.rb
bin/rails runner test/dashboard_logic_unit_test.rb
bin/rails runner script/profile_dashboard.rb
```

For production rollout, run migrations and restart the application to load the initializer, then compare the existing request duration/query logs for the same users, filters and data. The profiler measures controller/SQL time only; use HTTP request logs for full-page latency and login timing. Verify completed-payment isolation with two different assigned-JJ accounts and visually check Other Activity / Farmer Training filters.
