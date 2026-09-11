# JJ dashboard — React Native handoff

Base host: `https://krai.ploughmanagro.com`

Implementation is in this repository. Deployment to this host has not been performed or verified in this task. Import `docs/postman/jj-dashboard-and-translation.postman_collection.json` into Postman. Set `username` and `password`, run **JJ Login**; its test script saves the returned `token`. Alternatively set `token` to an existing JJ login token. Use your local server as `base_url` to test before deployment.

## Authentication

```http
POST https://krai.ploughmanagro.com/api/v1/jeevika-jankar-login
Content-Type: application/json
```

```json
{"login":"JJ_USERNAME","password":"JJ_PASSWORD"}
```

Use the returned application token on every other request:

```http
Authorization: Bearer <JJ_LOGIN_TOKEN>
Accept: application/json
```

The existing login may require the JJ to accept the agreement on the web portal. An ordinary office-user token cannot select arbitrary JJs. A JJ always sees their own data even if `vrp_id` is supplied; an administrator can inspect a JJ by adding `vrp_id=<id>`.

## Full dashboard and filters

- `GET https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard?month=August`
- `GET https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/filters?month=August`

Summary returns `jeevika_jankar`, `months`, `selected_month`, `cards`, `target_progress`, `weekly_target_plan` and `selected_week`. Dropdown response returns available `months`, five `weeks` options and applied selections.

All dashboard endpoints accept `month=August` (or `training_month=August`). When omitted, they use the same month selection as the JJ web dashboard: current month if assigned, otherwise the last available month in the web's month order. Use explicit `month=August` for the supplied screenshot. `month=all` includes all months. A month with no assignments returns zero/empty results, never another month's data. Send the same month to every box and drill-down.

## Each box: GET

| Screen box | Complete API URL |
| --- | --- |
| Mapped Villages | `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/widgets/mapped_villages?month=August` |
| Main Major Work Indicators | `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/widgets/main_activities?month=August` |
| Sub Major Work Indicators | `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/widgets/sub_activities?month=August` |
| Assigned Target | `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/widgets/assigned_target?month=August` |
| Assigned Farmers | `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/widgets/mapped_farmers?month=August` |
| Achieved Target | `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/widgets/achieved_target?month=August` |
| Pending Target | `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/widgets/pending_target?month=August` |

Box response shape (example value only; actual values come from the logged-in JJ):

```json
{"success":true,"dashboard_type":"jeevika_jankar","widget":"mapped_villages","heading":"Mapped Villages","value":2,"filters":{"month":"August"},"generated_at":"..."}
```

`main_activities` and `sub_activities` are the stable field keys for Main Major Work Indicators and Sub Major Work Indicators. `mapped_farmers` is the Assigned Farmers box. Counts reuse existing web calculation methods; no values from the screenshot are hard-coded.

## Each box's detail list and both tables: GET

| List / table | Complete API URL |
| --- | --- |
| Mapped Villages | `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/lists/mapped_villages?month=August` |
| Main Major Work Indicators | `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/lists/main_activities?month=August` |
| Sub Major Work Indicators | `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/lists/sub_activities?month=August` |
| Assigned Target | `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/lists/assigned_target?month=August` |
| Assigned Farmers | `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/lists/mapped_farmers?month=August` |
| Achieved Target | `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/lists/achieved_target?month=August` |
| Pending Target | `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/lists/pending_target?month=August` |
| Assigned Target Progress | `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/lists/target_progress?month=August` |
| Weekly Target Plan | `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/lists/weekly_target_plan?month=August` |

Lists return `success`, `dashboard_type`, `list_type`, `title`, `filters`, `count`, `total`, `records`, `generated_at`. `count` is the number of returned rows. For box lists, `total` is the box metric (target quantity may differ from row count). For table lists, `total` is row count. All scoped rows are returned; React Native can search/page locally. No hidden page limit is applied.

- Villages: `mapping_id`, `village_id`, `fco`, `gram_panchayat`, `village`, `farmers`, `targets`, `target_quantity`; legacy `target_records`, `assigned`, `achieved`, `pending` are also retained.
- Main/sub indicators: `main_activity` or `sub_activity`, `target_records`, `assigned`, `achieved`, `pending`.
- Farmers: `farmer_id`, `assignment_status`, `farmer_name`, `father_name`, `tracenet_no`, `ics`, `village`. Unavailable master details are null; assigned IDs are retained.
- Target lists: `target_mapping_id`, `month`, `completion_date`, `fco`, `ics`, `village`, `farmers`, `main_activity`, `sub_activity`, `main_activities`, `sub_activities`, `assigned`, `achieved`, `pending`, `progress_percent`, assigned/completed farmer IDs, all weekly metrics and demonstration targets.

## Assigned Target Progress columns

| Web column | JSON field |
| --- | --- |
| Month / Completion Date / FCO / Village / Farmers | `month` / `completion_date` / `fco` / `village` / `farmers` |
| Main / Sub Major Work Indicator | `main_activity` / `sub_activity` (grouped arrays also provided) |
| Targeted Farmer | `assigned` |
| Week 1–4 | `week_1`, `week_2`, `week_3`, `week_4` |
| OPG Training | `opg_training` |
| General Training/Meeting | `general_training` |
| Input Demo INM / PM | `input_demo_inm` / `input_demo_pm` |
| FFS Exposure | `ffs` |
| Completed / Pending / Progress | `achieved` / `pending` / `progress_percent` |

Progress-list `completion_date` is ISO `YYYY-MM-DD` or null. Weekly-list `completion_date` retains the existing `DD-MM-YYYY` / `-` representation.

## Weekly Target Plan

All weeks:

`GET https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/lists/weekly_target_plan?month=August&target_week=all`

One week:

`GET https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/lists/weekly_target_plan?month=August&target_week=week_2`

Accepted `target_week`: `all`, `week_1`, `week_2`, `week_3`, `week_4`. Invalid/omitted values show all weeks, matching the web behavior. Each row includes `target`, `week_1`–`week_4`, `week_1_achieved`–`week_4_achieved`, `completed`, `pending`, village/activity/month/date. A selected week also returns `selected_week`, `week_plan`, `week_achieved`. Selecting a week changes displayed weekly metrics; it does not remove assignments or change overall totals.

## Excel

Every list above supports `/export` before the query string. Example:

`GET https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/lists/weekly_target_plan/export?month=August&target_week=week_2`

Response is an XLSX file, not JSON. Send the same Bearer token and save the response as a file.

## Translation

- `GET https://krai.ploughmanagro.com/api/v1/translate/languages`
- `POST https://krai.ploughmanagro.com/api/v1/translate`

```json
{"q":["Mapped Villages","Assigned Farmers","Weekly Target Plan"],"source":"en","target":"hi"}
```

Use the same JJ login token. Response contains `translations: [{"text":"...","translated_text":"..."}]` in input order. Languages: `en`, `hi`, `mr`, `or`, `gu`. This translates text sent by the mobile app, not an entire React Native screen automatically. Batch screen labels/text and update the displayed strings in app state; keep IDs and business request values unchanged.

Google requires `GOOGLE_TRANSLATE_API_KEY` configured on the Rails server with Cloud Translation enabled and billing configured. Without this, non-identity translation returns `503 translation_not_configured`; the endpoint is not a credential-free substitute for Google. Do not send the app token to `translation.googleapis.com`. See `docs/react-native-translation-api.md` for limits and troubleshooting.

## Errors and validation

Unauthenticated requests return `401`. A token without valid JJ selection returns `422`. Unknown widget/list returns `422` with available keys. Translation additionally uses `422` for invalid inputs, `503` for missing server configuration, `502` for provider failure, `504` for timeout and `429` for the configured request limit.

Only API controller/routes, tests and handoff documents were changed for this task. Web controllers, JavaScript, templates and styles were not edited.

Validation: 18 automated tests / 163 assertions passed, including dashboard/API regressions, all seven boxes, month/weekly selection, farmer details, Excel export, two-JJ isolation, village ID grouping and translation errors. Google responses were simulated in service tests; live Google translation and production deployment were not verified. Postman collection contains 31 requests and passed JSON validation.
