# CC & JJ Performance — Android API

`GET /api/v1/cc-performance?month=November`

Send the existing login token in `Authorization: Bearer <token>`.
Available to Admin, Cluster Coordinator, FCOC and Agronomist logins. Data is
restricted to the authenticated user's web dashboard scope.

## Month

- `month=November`: selected month's counts (case insensitive English month name).
- `month=all`, empty month, or omitted month: All Months.
- A valid month with no targets returns zero target/achievement counts; it does
  not fall back to another month. Total JJ follows the web panel's active-JJ rule.
- Invalid month: HTTP 422. Missing/expired token: HTTP 401. Unsupported role: HTTP 403.

Optional web filters: `fcoc`, `to_name` (or `to`), `ics` (or `ics_name`),
`vrp_id`, `main_activity`, `sub_activity`, `cluster_incharge`, `post`, `search`.
Use the same filters as the web to compare counts. The default main activity is
resolved by the web dashboard's existing rules.

## Response

Example shape only; counts below are placeholders:

```json
{
  "success": true,
  "data": {
    "month": "November",
    "months": ["August", "September", "November"],
    "cc_target": 0,
    "cc_achievement": 0,
    "total_jj": 0,
    "total_opg_jj_target": 0,
    "total_opg_jj_achievement": 0
  },
  "generated_at": "2026-11-18T13:00:00+05:30"
}
```

| JSON field | Android card |
| --- | --- |
| `cc_target` | CC Target |
| `cc_achievement` | CC Achievement |
| `total_jj` | Total JJ |
| `total_opg_jj_target` | Total OPG JJ Target |
| `total_opg_jj_achievement` | Total OPG JJ Achievement |

`months` supplies the user's available month options. A request can select any
valid calendar month even when absent from these options. Counts are calculated
fresh using `CcDashboardReport` and the web dashboard's scope/filter pipeline.
OPG target uses the same saved village-target deduplication as Demonstration
Method. Total JJ includes active JJs according to the web role-specific rule;
it is not a count of training entries or a sum of monthly JJ counts.

```bash
curl 'https://krai.ploughmanagro.com/api/v1/cc-performance?month=November' \
  -H 'Authorization: Bearer YOUR_LOGIN_TOKEN' \
  -H 'Accept: application/json'
```

This endpoint must be deployed before the production URL is available.
