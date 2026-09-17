# Office dashboard API — React handoff

These changes must be deployed to the Rails API before using the new configuration endpoint. Existing Admin `/api/v1/admin-dashboard` and JJ `/api/v1/jeevika-jankar-dashboard` implementations remain unchanged. No web dashboard changes are included.

Use `/api/v1/user-dashboard` for Manager ICS, Cluster Incharge, Agricultural Specialist/Agronomist, and FCO-C Sausar/Turekela. Do not call the Admin endpoint for these users. Do not send a role, user ID, office or hierarchy to authorize the request: the Bearer token resolves the current user on the server.

## Authentication and routing

`POST /api/v1/login` with JSON `{ "login": "USERNAME", "password": "PASSWORD" }` returns `token` and `user`. Send `Authorization: Bearer TOKEN` for every dashboard request. `/api/v1/me` returns the current login.

Keep the existing Admin and JJ routing. All other office-user logins use this API. Never match a person's name or hardcode individual account IDs in React.

| Login | Server-side visibility |
| --- | --- |
| Cluster Incharge | JJs mapped to that cluster identity |
| Agricultural Specialist / Agronomist | JJs registered by that user, including existing legacy identity mappings |
| FCO-C Sausar / Turekela | JJs belonging to the user's configured FCO |
| Manager ICS | Own registered JJs plus JJs associated with users in the saved subordinate hierarchy |

Missing assignments return empty data; they never grant global visibility. Confirm the Manager ICS hierarchy in the existing user hierarchy screen if a subordinate is missing. The API does not create or change mappings.

## Endpoints

| Method | URL | Result |
| --- | --- | --- |
| GET | `/api/v1/user-dashboard/configuration` | Current user plus dynamic widget/list keys, titles and URLs |
| GET | `/api/v1/user-dashboard/filters` | Cascading filter definitions, options, applied defaults and filter order |
| GET | `/api/v1/user-dashboard` | Complete dashboard payload |
| GET | `/api/v1/user-dashboard/widgets/:key` | One widget; `value` can be a number or report array |
| GET | `/api/v1/user-dashboard/lists/:key` | Drill-down `{ title, count, records, filters }` |
| GET | `/api/v1/user-dashboard/lists/:key/export` | XLSX download with the same filters and authorization |

Use the keys returned by `configuration`; do not invent a list key from a display heading. Existing keys include `total_registered`, `final_approved`, `pending_approval`, `target_records`, `total_mapped_villages`, `targeted_farmers`, `farmer_wise_achievement`, `farmer_wise_pending_achievement`, `cc_jj_work_status`, and `demonstration_method`. Not every widget has a matching list; use the returned lists catalog.

## Filters

Load filter options with the same query as the dashboard. Render the `filters` array (`key`, `heading`, `all_option`, `options`); use `filter_order` for cascading updates. When a parent changes, clear its dependent child values before fetching again. Initial `applied_filters` contains defaults; send those explicitly on subsequent requests.

| Query | Meaning |
| --- | --- |
| `month` | Returned month name; omitted defaults to the previous calendar month |
| `main_activity`, `sub_activity` | Returned activity names |
| `fco` (or `fcoc`) | Returned FCO name, not a hardcoded office ID |
| `ics` | Returned ICS name |
| `vrp_id` | Optional JJ ID from `filter_options.vrps` in the summary |
| `cluster_incharge`, `search` | Optional cluster name or text search |
| `participation_month`, `participation_fcoc` | Optional participation-specific narrowing |
| `weekly_target_month`, `weekly_target_fcoc`, `weekly_target_week` | Optional weekly narrowing; week 1–4 |
| `language` | `en` or `hi` for summary labels |

Send the literal `All` for an explicit all selection. Do not use an omitted parameter to mean All: omitted month and main activity have defaults. Participation/weekly month inherits the dashboard month unless explicitly supplied. Section filters narrow the selected dashboard scope; they cannot restore targets excluded by the main dashboard filters. Carry the same filters into widget, list and export calls. No-match or unauthorized JJ selections return empty results.

Example: `GET /api/v1/user-dashboard?month=August&main_activity=All&fco=FCO-C%20Sausar&ics=ICS%20A`

## Rendering the response

- `user`: current identity and role.
- `cards`: registration, approval, target, activity and bill totals.
- `dashboard_summary.items`: dynamic cards with `key`, `label`, `label_en`, `label_hi`, `value`. Iterate these directly.
- `farmer_training_participation_status`: selected month/FCO and participation totals/status counts.
- `weekly_activity_target_status`: selected month/week/FCO and weekly progress.
- `monthly_target_summary`: monthly target rows.
- `cc_jj_work_status`, `demonstration_method`: report arrays; render them as report cards/tables rather than scalar counts.
- `hierarchy`: configured subordinate hierarchy.
- `filter_options`: additional visible JJ/cluster options.

Registration cards follow the selected target filters, so they may exclude JJs without targets in that month. Target-record, unique-farmer and farmer/activity counts are different quantities. Use each returned metric as-is; do not sum them together or recalculate achievement in React.

Summary responses are cached briefly. Mapping changes can take roughly two minutes to appear because table versions and summaries each have a one-minute lifetime. Client caches must be separated by login and filter values, and cleared on logout. Never show previous-login data while loading.

## Ready-to-copy client

Copy [officeDashboardApi.mjs](react-examples/officeDashboardApi.mjs) into the React project:

```jsx
import { createOfficeDashboardApi } from "./officeDashboardApi.mjs";

const api = createOfficeDashboardApi({
  baseUrl: API_ORIGIN,
  getToken: () => authStore.getState().token,
});

// Run after office-user login. Keep existing Admin/JJ components unchanged.
const configuration = await api.configuration();
const options = await api.filters({ month: "All", main_activity: "All" });
const filters = { month: "All", main_activity: "All" };
const dashboard = await api.dashboard(filters);
// dashboard.dashboard_summary.items.map(item => <Card key={item.key} ... />)
const drilldown = await api.list("targeted_farmers", filters);
const file = await api.exportList("targeted_farmers", filters);
```

In a React effect, pass `{ signal: abortController.signal }` to calls and abort in cleanup so an older filter request cannot overwrite newer data. On 401, return to login; on 403, show access denied; on 422, use a valid catalog key. On a 500 or `success: false`, show the error and a retry action—never convert a failed request into zero counts. The supplied client throws on both HTTP and JSON failures.

For another frontend origin, existing reverse-proxy/CORS policy must permit that origin and the Authorization header. This handoff does not change deployment or CORS settings.
