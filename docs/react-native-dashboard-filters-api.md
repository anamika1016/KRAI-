# React Native: dashboard auto-filter API

Backend changes are local and require deployment before the updated behavior is available on the server. Web controllers, views, and database schema are unchanged.

Base URL: `https://krai.ploughmanagro.com/api/v1`

Every request requires:

```http
Authorization: Bearer <login_token>
Accept: application/json
```

## Endpoints

| Purpose | Admin login | Office login (CC / Agronomist / FCO) |
|---|---|---|
| All five dropdowns | `GET /admin-dashboard/filters` | `GET /user-dashboard/filters` |
| Dashboard data | `GET /admin-dashboard` | `GET /user-dashboard` |
| One card | `GET /admin-dashboard/widgets/:widget` | `GET /user-dashboard/widgets/:widget` |
| Card records | `GET /admin-dashboard/lists/:list_type` | `GET /user-dashboard/lists/:list_type` |
| Excel | `GET /admin-dashboard/lists/:list_type/export` | `GET /user-dashboard/lists/:list_type/export` |

These are existing endpoints. The filter endpoints now calculate dropdowns directly from login-visible target mappings, without calculating all dashboard reports. They are for the screenshot's admin/office dashboard; JJ login has separate endpoints described in [JJ API documentation](jj-dashboard-mobile-api.md).

## Query parameters and cascade

| Order | Query key | Heading | Options come from |
|---|---|---|---|
| 1 | `month` | Month | Visible mapping months |
| 2 | `main_activity` | Main Major Work Indicator | Selected month |
| 3 | `sub_activity` | Sub Major Work Indicator | Selected month + main activity |
| 4 | `fco` | FCO | Selected month + main + sub activity |
| 5 | `ics` | ICS Name | Selected month + main + sub + FCO |

Use the exact strings returned in `options`, not numeric IDs. `fcoc` is an alias for `fco`; `ics_name` is an alias for `ics`. Prefer the canonical keys above and do not send conflicting aliases.

Omitted `month` defaults to the previous calendar month. Omitted `main_activity` defaults to the existing farmer-training activity when available. Send `All` explicitly for an unrestricted selection. Unknown month/main activity produces empty child options. An obsolete sub-activity, FCO, or ICS selection is cleared to `null` in `applied_filters`; the client must use the returned selections for its next data request. Empty mapped scopes return empty option arrays.

## Farmers' Training example

```http
GET /api/v1/admin-dashboard/filters?month=August&main_activity=Farmers%27%20Training
```

This returns only the August sub-activities and FCOs mapped under Farmers' Training. Then select a returned sub-activity and refresh the filters:

```http
GET /api/v1/admin-dashboard/filters?month=August&main_activity=Farmers%27%20Training&sub_activity=<URL_ENCODED_OPTION>
```

Select an FCO to narrow ICS options:

```http
GET /api/v1/admin-dashboard/filters?month=August&main_activity=Farmers%27%20Training&sub_activity=<URL_ENCODED_OPTION>&fco=<URL_ENCODED_OPTION>
```

Response shape (illustrative mapping values, not production data):

```json
{
  "success": true,
  "dashboard_type": "admin",
  "filters": [
    {"key":"main_activity","heading":"Main Major Work Indicator","all_option":"All Main Major Work Indicators","options":["Farmers' Training"]},
    {"key":"sub_activity","heading":"Sub Major Work Indicator","all_option":"All Sub Major Work Indicators","options":["Soil"]},
    {"key":"fco","heading":"FCO","all_option":"All FCO","options":["FCO A"]},
    {"key":"ics","heading":"ICS Name","all_option":"All ICS","options":["ICS A"]},
    {"key":"month","heading":"Month","all_option":"All Months","options":["August"]}
  ],
  "applied_filters": {"month":"August","main_activity":"Farmers' Training","sub_activity":null,"fco":null,"ics":null},
  "filter_order": ["month","main_activity","sub_activity","fco","ics"],
  "generated_at":"2026-09-12T12:00:00+05:30"
}
```

## React Native integration

On any selection change, clear all downstream selections to `All`, call `/filters`, update dropdowns from the response, then fetch the dashboard with `applied_filters`. No Apply button is needed in the app. The backend returns the options; the app must trigger these requests on selection changes.

```javascript
const baseUrl = 'https://krai.ploughmanagro.com/api/v1';
const dashboardPath = '/admin-dashboard'; // '/user-dashboard' for office login
const order = ['month', 'main_activity', 'sub_activity', 'fco', 'ics'];
let selection = { month: 'August', main_activity: "Farmers' Training" };
let requestVersion = 0;

const query = values => Object.entries(values)
  .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(value ?? 'All')}`)
  .join('&');

async function getJson(path, values) {
  const response = await fetch(`${baseUrl}${path}?${query(values)}`, {
    headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' },
  });
  const body = await response.json();
  if (!response.ok || !body.success) throw new Error(body.message || 'Request failed');
  return body;
}

async function refreshDashboard() {
  const version = ++requestVersion;
  try {
    const result = await getJson(`${dashboardPath}/filters`, selection);
    if (version !== requestVersion) return;
    selection = result.applied_filters;
    setDropdowns(result.filters); // React state setter
    setSelectedFilters(selection);
    const dashboard = await getJson(dashboardPath, selection);
    if (version === requestVersion) setDashboard(dashboard);
  } catch (error) {
    if (version === requestVersion) setError(error.message);
  }
}

function onFilterChange(key, value) {
  selection = { ...selection, [key]: value ?? 'All' };
  order.slice(order.indexOf(key) + 1).forEach(child => { selection[child] = 'All'; });
  return refreshDashboard();
}

function clearFilters() {
  selection = Object.fromEntries(order.map(key => [key, 'All']));
  return refreshDashboard();
}
// Call refreshDashboard() on initial screen load.
```

The example assumes `token` and React state setters are supplied by your screen. It ignores older responses so rapid selection changes do not overwrite newer results. Pass the same normalized `selection` to widgets, lists, and exports. Encode `null` as `All` rather than omitting it, to avoid reactivating defaults.

Card keys and report-specific filter behavior are documented in [dashboard API reference](dashboard-api-reference.md). These changes update the five top-level dropdowns; existing report calculations and report-specific parameters remain in place.
