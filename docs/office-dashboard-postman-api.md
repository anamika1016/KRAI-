# CC, FCOC, Agronomist dashboard — API handoff

Backend only. No web UI changes. Deploy the updated Rails backend before testing these additions on the production URL.

Import `docs/postman/office-dashboard.postman_collection.json` into Postman. Set collection variables `base_url`, `login`, `password`. Keep credentials local. Run **01 POST Login** first: its test script stores the returned Bearer token automatically. Run the collection separately for each role.

## 1. POST login

`POST {{base_url}}/api/v1/login`

Header: `Content-Type: application/json`

```json
{"login":"YOUR_USERNAME","password":"YOUR_PASSWORD"}
```

Successful response includes `success`, `token`, `user`. All subsequent requests use `Authorization: Bearer {{token}}`. The logged-in account controls scope: FCOC sees its assigned FCO, CC sees its mapped JJs, Agronomist sees the JJs it registered. Sending a different role or JJ ID cannot grant additional access.

## 2. GET endpoints

GET requests have query parameters, **no JSON body**. Dashboard reads do not require POST/PUT/DELETE.

| Method | Path | Result |
| --- | --- | --- |
| GET | `/api/v1/user-dashboard/configuration` | Available widget and list keys, titles, URLs |
| GET | `/api/v1/user-dashboard/filters` | Dropdowns, cascading order and default selections |
| GET | `/api/v1/user-dashboard` | Complete dashboard, all boxes and reports |
| GET | `/api/v1/user-dashboard/widgets/:key` | One box/report |
| GET | `/api/v1/user-dashboard/lists/:key` | View List: `title`, `count`, `records` |
| GET | `/api/v1/user-dashboard/lists/:key/export` | XLSX for the same list and filters |

Example:

```text
GET {{base_url}}/api/v1/user-dashboard?month=September&main_activity=Farmers%27%20Training&sub_activity=All&fco=All&ics=All
Authorization: Bearer {{token}}
```

## 3. Every filter

| Parameter | Value / behavior |
| --- | --- |
| `month` | Month name; omitted means previous calendar month; `All` means all months |
| `main_activity` | Exact returned name; omitted selects the available Farmers' Training default |
| `sub_activity` | Exact returned sub-activity or `All` |
| `fco` / `fcoc` | Exact returned FCO name or `All` |
| `ics` / `ics_name` | Exact returned ICS name or `All` |
| `cluster_incharge` | Optional visible cluster name |
| `vrp_id` | Optional visible JJ ID |
| `search` | Optional text search |
| `post` / `post_wise_name` | Optional JJ role |
| `participation_month`, `participation_fcoc` | Participation section narrowing |
| `weekly_target_month`, `weekly_target_fcoc`, `weekly_target_week` | Weekly section narrowing; week 1–4 |
| `ics_report_month`, `ics_report_ics` | ICS report narrowing; choose ICS to load its rows |
| `language` | `en` or `hi` for legacy summary labels |

Call `/filters` with the current selection. Read `filter_order`, `filters` and `applied_filters`. Cascade: month → main activity → sub activity → FCO → ICS. Clear dependent children to `All` when changing their parent, then request options again. Send resolved values into dashboard, widget, list and export requests. Convert a null dropdown selection to explicit `All` so it cannot accidentally activate an omitted default.

`All` always stays inside the logged-in user's authorized scope. Section filters cannot restore targets excluded by top-level filters. Reset to web defaults by omitting filters; select all explicitly with `month=All&main_activity=All`.

## 3A. One common View List API

Every dashboard card includes `list_key` and `list_endpoint`. Do not create a different mobile URL for each box. Call the endpoint returned in that card, with the same query filters and Bearer token:

```text
GET {{base_url}}/api/v1/user-dashboard/lists/{{list_key}}?month=June&main_activity=Farmers%27%20Training&sub_activity=All&fco=FCO-C%20Turekela&ics=All
Authorization: Bearer {{token}}
```

The response is always `{ success, title, list_type, filters, count, records }`. `count` is the number of actual returned rows. The matching Excel endpoint is `/api/v1/user-dashboard/lists/{{list_key}}/export` with the same filter parameters.

For Participation cards, `training_unique_farmers`, `training_red`, `training_yellow`, and `training_green` now use the web dashboard View List SQL and the logged-in CC/Agronomist/FCOC authorization scope. Summary activity lists use the Summary card scope, and Demonstration uses `demonstration_method`.

## 4. Boxes, line by line

Use the new `sections` array for the screenshot dashboard. Each card includes `key`, `title`, `value`, `list_key`, `list_endpoint`, `export_endpoint`. Follow returned URLs with the same query and token.

| Box | Card key | View List key |
| --- | --- | --- |
| Total ICS Count | `summary_ics` | `summary_ics` |
| Total Villages Count | `summary_villages` | `summary_villages` |
| Total Farmer Count | `summary_farmers` | `summary_farmers` |
| Total Mapped Main Major Work Indicators | `total_mapped_main_activities` | same |
| Total Mapped Sub-Major Work Indicators | `total_mapped_sub_activities` | same |
| Mapped Farmer | `mapped_farmer` | `training_unique_farmers` |
| Pending | `training_red` | `training_red` |
| Only 1 Training | `training_yellow` | `training_yellow` |
| 1+ Trainings | `training_green` | `training_green` |
| OPG Training Target | `opg_training_target` | `demonstration_method` |
| General Training/Meeting | `general_training_meeting` | `demonstration_method` |
| Input Demo INM | `input_demo_inm` | `demonstration_method` |
| Input Demo PM | `input_demo_pm` | `demonstration_method` |
| FFS Exposure | `ffs_exposure` | `demonstration_method` |
| CC TARGET STATUS | `cc_target_status` | `demonstration_method` |
| Other: Main Major Work Indicator | `other_main_major_work_indicator` | `other_activities` |
| Other: Mapped Farmer | `other_mapped_farmer` | `other_activities` |
| Other: Achievement Farmer | `other_achievement_farmer` | `other_activities` |
| Other: Pending Farmer | `other_pending_farmer` | `other_activities` |
| Other: Achieved % | `other_achieved` | `other_activities` |
| FCO Required / Active / Vacant | `fco_requirement_sausar_required`, `_active`, `_vacant`; likewise `turekela` | same as card key |
| Billing Approved / Pending | `bill_approved`, `bill_pending` | same |
| Gender Male / Female | `gender_sausar_male`, `gender_sausar_female`; likewise `turekela` | same |
| CC and JJ Work Status | Section `cc_jj_work_status`: `rows`, `groups` | `cc_jj_work_status` |

Demonstration values are numeric pairs `{ "target": 10, "achievement": 7 }`, except OPG Training Target, which is a scalar. Other Achieved has `unit: "percent"`. Example values here are illustrative.

Required/Vacant lists return requirement totals, not invented JJ identities. Required uses existing web office capacity rules (Sausar 34 / Turekela 24, at least active count). Active and gender lists contain only visible JJs. Other achievements require matching authorized JJ, month, activity and mapped farmer. Unrepresented FCO cards are omitted.

Total Farmer Count follows the web's count of nonblank Tracenet rows. Mapped Farmer is a distinct mapped-farmer count; these are different metrics. Participation Pending is the red category, not the legacy `pending` field. Other can include non-training activities for the same visible JJs/month/ICS even while Farmers' Training is selected, matching the secondary web panel.

The legacy response also retains `cards`, `dashboard_summary`, `farmer_training_participation_status`, `weekly_activity_target_status`, `monthly_target_summary`, `hierarchy`, and report arrays. `ics_wise_farmer_report` provides ICS options, summary, rows and count. The configuration endpoint lists additional registration, weekly and activity drilldowns.

## 5. Response and errors

Illustrative card inside a complete response:

```json
{
  "key": "general_training_meeting",
  "title": "General Training/Meeting",
  "value": {"target": 10, "achievement": 7},
  "list_key": "demonstration_method",
  "list_endpoint": "/api/v1/user-dashboard/lists/demonstration_method",
  "export_endpoint": "/api/v1/user-dashboard/lists/demonstration_method/export"
}
```

List response: `{ "success": true, "dashboard_type": "user", "list_type": "...", "title": "...", "filters": {}, "count": 0, "records": [], "generated_at": "..." }`. Empty authorized results are valid. Do not interpret an error as zero data.

401: missing/invalid token. 403: JJ login on this office endpoint. 422: invalid list/widget key. 500: dashboard calculation failure. Use configuration for valid keys.

## 6. Timing and verification

The complete response contains `meta.server_processing_ms`, `meta.cache_hit`, and a `Server-Timing` header. These measure server dashboard processing, excluding network transfer. Postman separately shows total request time. The summary is cached for one minute with login and filter separation; fresh database version stamps invalidate the office summary cache after source changes. Production millisecond latency is not guaranteed by local tests.

The collection includes HTTP/JSON assertions, automatic token capture, export MIME checks and individual View List requests. Import it and run against the deployed backend with each role's credentials. Backend integration tests use the local test database; they are not a claim that the Postman desktop app or production endpoint was exercised.

## September 24 integration correction: summary and month cascade

Use `dashboard_summary.cards` for the five screenshot summary boxes, or `dashboard_summary.counts` for keyed values. These match `sections[key=summary].cards` and the corresponding summary widget/list endpoints. The older `dashboard_summary.items/values` remain compatibility metrics: `targeted_farmers` is **not** Total Farmer Count. Do not map those legacy values to the screenshot's five summary headings.

```text
GET /api/v1/user-dashboard/filters?month=August&main_activity=Farmers%27%20Training&sub_activity=All&fco=All&ics=All
GET /api/v1/user-dashboard?month=August&main_activity=Farmers%27%20Training&sub_activity=All&fco=All&ics=All
```

Dashboard `filter_options.sub_activities` now excludes modules from other months. Populate dropdowns from the returned options; replace the previous options rather than appending. On a month/main selection change, clear dependent values to All and reload filters, then dashboard. GET body should be empty; login/password belong only to POST login. Every GET requires the logged-in user's Bearer token.

Office API cache version stamps are now read from the database on each request, including fractional update timestamps. Committed record changes no longer wait for the previous one-minute version cache. Network and calculation time still apply; no fixed latency guarantee. Existing web code is unchanged by this correction.

### Summary versus selected activity filters

For exact web parity, the five **Dashboard Summary** cards use the authorized login scope and selected FCO, ICS, cluster, JJ and search filters. They do not change for `month`, `main_activity` or `sub_activity`. **Farmer Training Participation Status** and **Demonstration Method** use every selected filter, including month, main activity and sub activity, and therefore change immediately when a filter is applied.

## Timeout mitigation: use boxes for the mobile landing page

`GET /api/v1/user-dashboard/boxes?month=August&main_activity=Farmers%27%20Training&sub_activity=All&fco=All&ics=All`

Returns the same `sections` for `summary`, `participation`, `demonstration` (15 cards), `filters`, `filter_options`, `user` and processing time. It skips weekly farmer rows, billing, hierarchy, Other and CC/JJ work-status calculations. The full endpoint remains available; use separate list/report URLs when opening those screens. No production latency guarantee has been established. Deploy the backend before using this new URL.

Dropdown API: `GET /api/v1/user-dashboard/filters?month=August&main_activity=Farmers%27%20Training&sub_activity=All&fco=All&ics=All`. Both require Bearer authorization and an empty GET body. Use identical filter parameters for boxes and list requests.

## June and historical monthly data

The office mobile API now calculates Dashboard Summary and Farmer Training Participation from the selected, authorized target mappings. This preserves historical farmer IDs when a later AFL import no longer contains them. Thus CC sees only JJs mapped under that CC, Agronomist sees only JJs registered by that Agronomist, and FCOC sees only JJs in the login FCO; these scopes apply in June and every other month.

For a fast mobile page call:

`GET /api/v1/user-dashboard/boxes?month=June&main_activity=Farmers%27%20Training&sub_activity=All&fco=All&ics=All`

For dropdowns call:

`GET /api/v1/user-dashboard/filters?month=June&main_activity=Farmers%27%20Training&sub_activity=All&fco=All&ics=All`

Send the same Bearer token and same query values in both requests. `filters` supplies the cascading Month → Main Activity → Sub Activity → FCO → ICS options. A returned zero is therefore a real zero inside that login scope, not a global dashboard value.
