# Farmer Training Participation Status — React Native handoff

Base URL: `https://krai.ploughmanagro.com/api/v1`

Authentication: admin login token, `Authorization: Bearer <token>`, `Accept: application/json`.

## All four boxes in one request

```http
GET /api/v1/admin-dashboard/farmer-training-participation?status=summary&month=August&fco=1004&weekly_target_week=1
```

Use this dedicated endpoint for this section instead of older full-dashboard participation values or individual widget values. The endpoint now calls the same current web count/popup and SQL list helpers. `status=summary` avoids loading farmer list rows and calculating the rest of the dashboard.

Render the returned `cards` array directly:

| Web box title | Card key | List status |
|---|---|---|
| Mapped Farmer | `mapped_farmer` | `unique` |
| Pending | `no_training` | `red` |
| Only 1 Training | `only_1_training` | `yellow` |
| 1+ Trainings | `one_plus_trainings` | `green` |

Every card contains `key`, `title`, `status`, `value`, and `popups`. Values are calculated on the server; do not derive Pending by subtracting counts.

Response fields:

```text
success, dashboard_type, title, status
selected_month, selected_fcoc, selected_week
cards: [{key, title, status, value, popups}]
red_fco_details: [web Pending popup breakdown rows]
totals: {total_unique_farmers_distinct, red, yellow, green, pending}
count, farmers, generated_at
```

For `status=summary`, `farmers` is empty and `count` is zero because a list was not requested. Use `cards[].value` for box counts.

## Every View List URL

Append the exact same selected filters to every request:

```text
/admin-dashboard/farmer-training-participation?status=unique&month=August&fco=1004
/admin-dashboard/farmer-training-participation?status=red&month=August&fco=1004
/admin-dashboard/farmer-training-participation?status=yellow&month=August&fco=1004
/admin-dashboard/farmer-training-participation?status=green&month=August&fco=1004
```

Pending popup sub-lists:

```text
/admin-dashboard/farmer-training-participation?status=no_activity&month=August&fco=1004
/admin-dashboard/farmer-training-participation?status=no_training_mapping&month=August&fco=1004
/admin-dashboard/farmer-training-participation?status=training_mapped_no_entry&month=August&fco=1004
```

List rows are returned in `farmers`, with `count` indicating the returned row count. Common row fields include `farmer_id`, `farmer_name`, `father_name`, `mobile_no`, `tracenet_no`, `ics`, `village`, `fcoc`, `months`, `status`. Training rows also include training-specific fields such as `sub_activities`, `training_method`, and `attendance_count`; do not assume every status has every field.

## Filters and exact web behavior

| Parameter | Value / behavior |
|---|---|
| `month` | Explicit month name, e.g. `August`; aliases `participation_month`, `training_month` |
| `fco` | Selected FCO, e.g. `1004` / `1006`, or dropdown value; aliases `participation_fcoc`, `training_fcoc`, `fcoc` |
| `ics` | Selected ICS string from dropdown; alias `ics_name` |
| `weekly_target_week` | `1`, `2`, `3`, `4`; omit for All Weeks; `week` is an alias |
| `status` | `summary` or a list status above |

Pass the web screen's actual month and FCO explicitly to compare counts; the web can choose a default visible FCO. `fco=All` requests the existing helper's combined FCO scope. Omitted month defaults to the previous calendar month in this API. The current shared web SQL helpers fall back to August for a blank month, so **do not use `month=All` for an all-month aggregation**.

The helper uses the existing Farmers' Training population. Main/sub-activity query strings do not independently narrow these SQL-based cards. ICS and login visibility use the existing web SQL scoping. Week changes attendance/Pending calculations; Mapped Farmer remains a monthly count. Day ranges are 1–7, 8–14, 15–21, 22–month end. All Weeks is not the sum of weekly distinct farmer counts.

The data calculation is shared with web; equality against production has not been measured. This update does not change web controllers, SQL, or views. The full-dashboard and older widget fields have not been migrated by this change: use this dedicated endpoint for the four participation boxes and their lists.

## React Native example

```javascript
const endpoint = 'https://krai.ploughmanagro.com/api/v1/admin-dashboard/farmer-training-participation';

async function loadParticipation(token, filters, status = 'summary') {
  const values = { ...filters, status };
  const query = Object.entries(values)
    .filter(([, value]) => value != null && value !== '')
    .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(value)}`)
    .join('&');
  const response = await fetch(`${endpoint}?${query}`, {
    headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' },
  });
  const data = await response.json();
  if (!response.ok || !data.success) throw new Error(data.message || 'Unable to load participation');
  return data;
}

const filters = { month: 'August', fco: '1004', weekly_target_week: 1 };
const summary = await loadParticipation(token, filters);
// Render summary.cards; show card.popups and summary.red_fco_details on tap.
const list = await loadParticipation(token, filters, 'yellow');
// Render list.farmers.
```

Refresh this summary on Month/FCO/ICS/Week changes. On card tap, pass `card.status` and the same filters. Ignore stale responses during rapid filter changes. This route currently requires admin login; it is not a JJ-login route.

Backend deployment is required for the updated response. No production deployment or latency benchmark was performed.
