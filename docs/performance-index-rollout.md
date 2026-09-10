# September 9 performance review

Initial scope: this document records the three-index change. The user later
authorized internal code optimization while preserving business behavior; see
application-performance-audit.md for that follow-up.

The supplied production journal shows login POSTs taking 10–14 ms, followed by
dashboard requests taking about 11–12 seconds (82–94 queries, roughly 8 seconds
in ActiveRecord). This explains the perceived login delay. Bill List also takes
28.675 seconds, including 27.128 seconds attributed to views; Payment List takes
6.325 seconds. Database indexes alone do not address that Ruby/rendering work.
The attachment does not establish API endpoint latency or server capacity.

The existing schema already has normalized training-month and FCO indexes.
The new indexes support the unchanged `afls.id::text` JSON membership joins and
combined normalized month/FCO id or name filters on target mappings. They do not
eliminate JSON expansion, repeated queries or Ruby record hydration. No blanket
GIN index was added: the existing array-expansion queries do not use a JSON
containment predicate. No Puma capacity settings were guessed without server
memory, CPU and database connection limits.

Local validation:

- Concurrent migration applied successfully to development; schema updated.
- Ruby syntax and whitespace checks passed.
- Existing dashboard logic checks: 5 tests, 14 assertions, no failures.
- Same controller-only profiler: before 1569.02 ms / 225.20 ms SQL; after
  1562.03 ms / 243.54 ms SQL; both 136 queries. This is effectively unchanged
  on the local dataset, **not evidence of a production speedup**. Full rendering,
  production query plans and concurrent-load capacity remain unverified.

Production rollout (not executed here):

1. Capture request timings for the same account, month, FCO and ICS filters.
2. Deploy this migration and schema through the normal release process, then run
   `RAILS_ENV=production bin/rails db:migrate` outside a wrapping transaction.
   Index creation is concurrent; it still consumes disk and I/O and may wait for
   existing transactions. The indexes add maintenance work to future writes.
3. Refresh planner statistics with `ANALYZE afls; ANALYZE target_mappings;` using
   the database maintenance account. Compare the same requests and query plans.
4. Confirm all three new indexes are valid in `pg_index`. If a concurrent build
   is interrupted, inspect and remove only its invalid index before retrying;
   the migration deliberately fails on duplicate names instead of silently
   accepting an invalid index.

Rollback only this migration if necessary:
`RAILS_ENV=production bin/rails db:migrate:down VERSION=20260909180000`.
It removes the three indexes concurrently and does not alter application data.

Making the remaining Ruby/rendering and repeated-query work substantially faster
requires application implementation changes while preserving business behavior,
or measured infrastructure changes. The subsequent authorized implementation addresses two of those bottlenecks. Production deployment and measurement are still required before calling
the reported slowness resolved.
