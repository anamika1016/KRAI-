# Training Form List and downloads

The Training Form List Excel export now streams a compressed XLSX workbook directly from batches of visible training records. It avoids the old CSV generation/parsing round trip and the full in-memory worksheet. Columns, cell text, filename, pending-first/newest-first ordering, and visibility rules are retained. Both download responses disable proxy buffering and start sending archive metadata before reading training records. Downloads still include the full visible dataset, including when the HTML list is capped.

The HTML list retains its existing 800-record screen cap, Show all link, 15-row client pagination, search, and actions. Field keys are computed once per render; unused farmer-name strings are not assembled. Approval revision summaries are limited to the records on the screen. Only the first 15 rows are painted initially, and initialization reads training row text without forcing browser layout for every row. All rows stay available to the existing search/pagination code.

Excel and ZIP links use direct browser navigation (`data-turbo="false"`) so Turbo does not handle the binary response as an HTML visit.

`/modules/training-form-list/export?format=zip` now returns a streaming ZIP64 archive. Previously it loaded every training record and attachment into memory, compressed all files into another in-memory buffer, and only then sent a response. This could cause long waits and excessive memory use; production logs are needed to confirm the exact cause of a particular 502.

The response starts with a directory entry before records are queried. Records are read in batches of 100 with the existing visibility rules, and attachment contents are read in 64 KiB chunks. Files are stored without recompression, which avoids spending CPU on already compressed photos/PDFs. Only ZIP directory metadata grows with the file count. Archive files are inside `training_attachments/`; duplicate names receive unique suffixes. Missing files are skipped as before. Resolved paths must remain inside `public/uploads/module_records`.

Deploy the updated application and restart Puma through the normal deployment process. No database migration or job worker is required. Keep Nginx's default handling of `X-Accel-Buffering: no`; a proxy configured to ignore this header should disable response buffering for this export route. This implementation also sets `Last-Modified` to prevent middleware from buffering the response to calculate an ETag.

After deployment, test both `format=xlsx` and `format=zip` with a large visible dataset. Confirm that response bytes arrive promptly, open the downloaded Excel/ZIP, exercise list search and pagination, and check Puma/Nginx logs for errors. The fix has been tested locally; production deployment and production latency have not been verified.
