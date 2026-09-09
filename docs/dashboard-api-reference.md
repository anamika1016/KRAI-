# Mobile Dashboard API URLs

Base URL: `https://krai.ploughmanagro.com/api/v1`  
Header on every request: `Authorization: Bearer <token>`

## Admin dashboard box APIs

| Heading | URL |
|---|---|
| Total ICS Count | `/admin-dashboard/widgets/total_ics_count` |
| Total Registered Jeevika Jankar | `/admin-dashboard/widgets/total_registered` |
| Final Approved | `/admin-dashboard/widgets/final_approved` |
| Pending Approval | `/admin-dashboard/widgets/pending_approval` |
| Target Records | `/admin-dashboard/widgets/target_records` |
| Without Target | `/admin-dashboard/widgets/without_target` |
| Activities Assigned | `/admin-dashboard/widgets/activities_assigned` |
| Without Activity | `/admin-dashboard/widgets/without_activity` |
| Level 2 Users | `/admin-dashboard/widgets/level_2_users` |
| Bill Approved | `/admin-dashboard/widgets/bill_approved` |
| Bill Pending | `/admin-dashboard/widgets/bill_pending` |

Example: `https://krai.ploughmanagro.com/api/v1/admin-dashboard/widgets/total_ics_count`

## Admin filter API

`GET https://krai.ploughmanagro.com/api/v1/admin-dashboard/filters`

It returns five dynamic dropdowns with these exact headings: **Main Major Work Indicator**, **Sub Major Work Indicator**, **FCO**, **ICS Name**, and **Month**. Each item has `key`, `heading`, `all_option`, and live `options`.

Apply selected filters to any box URL using:

```text
?main_activity=Farmers%27%20Training&sub_activity=...&fco=FCO-C%20Sausar&ics=...&month=August
```

## Remaining Admin box API URLs

All use `https://krai.ploughmanagro.com/api/v1/admin-dashboard/widgets/` before the last column value.

| Heading | Widget value in URL |
|---|---|
| Total Villages Count | `total_villages_count` |
| Total Farmer Count | `total_farmer_count` |
| Total Mapped Main Major Work Indicators | `total_mapped_main_activities` |
| Total Mapped Sub-Major Work Indicators | `total_mapped_sub_activities` |
| Mapped Farmer | `mapped_farmer` |
| No Training | `no_training` |
| Only 1 Training | `only_1_training` |
| 1+ Trainings | `one_plus_trainings` |
| OPG Training Target | `opg_training_target` |
| OPG Training Achievement | `opg_training_achievement` |
| General Training/Meeting | `general_training_meeting` |
| Input Demo INM | `input_demo_inm` |
| FFS | `ffs` |
| Input Demo PM | `input_demo_pm` |
| Sausar Required / Active / Vacant | `sausar_required` / `sausar_active` / `sausar_vacant` |
| Turekela Required / Active / Vacant | `turekela_required` / `turekela_active` / `turekela_vacant` |
| Sausar Male / Female | `sausar_male` / `sausar_female` |
| Turekela Male / Female | `turekela_male` / `turekela_female` |

## Jeevika Jankar dashboard box APIs

| Heading | URL |
|---|---|
| Mapped Villages | `/jeevika-jankar-dashboard/widgets/mapped_villages` |
| Main Activities | `/jeevika-jankar-dashboard/widgets/main_activities` |
| Sub Activities | `/jeevika-jankar-dashboard/widgets/sub_activities` |
| Assigned Farmers | `/jeevika-jankar-dashboard/widgets/mapped_farmers` |
| Assigned Target | `/jeevika-jankar-dashboard/widgets/assigned_target` |
| Achieved Target | `/jeevika-jankar-dashboard/widgets/achieved_target` |
| Pending Target | `/jeevika-jankar-dashboard/widgets/pending_target` |

Use `?month=August` to select a month. Example: `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/widgets/assigned_target?month=August`

## CC / Agronomist / FCO dashboard box APIs

| Heading | URL |
|---|---|
| Total Registered JJ | `/user-dashboard/widgets/total_registered` |
| Final Approved | `/user-dashboard/widgets/final_approved` |
| Pending Approval | `/user-dashboard/widgets/pending_approval` |
| Target Records | `/user-dashboard/widgets/target_records` |
| Activities Assigned | `/user-dashboard/widgets/activities_assigned` |
| Bill Approved | `/user-dashboard/widgets/bill_approved` |
| Bill Pending | `/user-dashboard/widgets/bill_pending` |
| Total Mapped Villages | `/user-dashboard/widgets/total_mapped_villages` |
| Targeted Farmers | `/user-dashboard/widgets/targeted_farmers` |
| Farmer-wise Achievement | `/user-dashboard/widgets/farmer_wise_achievement` |
| Farmer-wise Pending Achievement | `/user-dashboard/widgets/farmer_wise_pending_achievement` |

The logged-in user's CC/Agronomist/FCO scope is applied automatically.

## Dynamic list and export APIs

For every box, replace `:list_type` with the required type, for example `total_ics_count`, `target_records`, `mapped_villages`, `training_green`, `weekly_completed`, or `bill_pending`.

| Purpose | URL |
|---|---|
| Admin View List | `/admin-dashboard/lists/:list_type` |
| Admin XLSX Export | `/admin-dashboard/lists/:list_type/export` |
| User View List | `/user-dashboard/lists/:list_type` |
| User XLSX Export | `/user-dashboard/lists/:list_type/export` |
| JJ View List | `/jeevika-jankar-dashboard/lists/:list_type` |
| JJ XLSX Export | `/jeevika-jankar-dashboard/lists/:list_type/export` |

Widget response format: `{ success, dashboard_type, widget, heading, value, filters, generated_at }`.
