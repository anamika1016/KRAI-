# Training Form, Other Target and Demonstration Method — React handoff

Code is implemented in this repository. Production URLs below become available after this version is deployed; no production deployment was performed. No web views, CSS, JavaScript or web controller behavior is changed by this API work.

Base URL: `https://krai.ploughmanagro.com/api/v1`
Local base URL: `http://localhost:3000/api/v1`

Use `Authorization: Bearer <token>` and `Accept: application/json` on every request except login. Login: `POST /login` with `{"login":"your-login","password":"your-password"}`; save the returned `token` using the app's existing secure token storage. JJ accounts must accept the existing agreement before API login. Never embed credentials in source code.

## Endpoints

| Method | Path (append to base URL) | Purpose |
| --- | --- | --- |
| GET | `/farmer-trainings/form-options` | Months, training methods, mapped targets/farmers, trainer defaults |
| GET | `/farmer-trainings/form-data` | Filtered dropdowns and mapping/farmer data |
| GET | `/farmer-trainings/months` | Available months |
| GET | `/farmer-trainings/farmers` | Available farmers (completed farmers excluded) |
| GET | `/farmer-trainings/mapped-farmers` | Mapped farmers with availability flags |
| GET / POST | `/farmer-trainings` | List / create training |
| GET | `/farmer-trainings/:id` | Training detail |
| GET | `/farmer-trainings/:id/photos` | Photo URLs |
| GET | `/other-targets/form-options` | Defaults and accessible Other activity mappings/farmers |
| GET / POST | `/other-targets` | List / create Other Target |
| GET | `/other-targets/:id` | Other Target detail |
| GET | `/demonstration-methods/summary?month=September` | FCO summary and aggregate target/achievement |
| GET | `/demonstration-methods?month=September&page=1&per_page=25` | JJ-level list |

These form endpoints support create/read. PATCH/DELETE and the web training edit-approval workflow are not exposed by this handoff. Lists return `farmer_trainings` / `other_targets`, with `count`; detail/create return `farmer_training` / `other_target`. Each record contains `id`, `module_slug`, timestamps and `data`. Training lists are currently unpaginated; demonstration lists are paginated.

## Training flow

1. Load `/farmer-trainings/form-data` and populate selections from returned options. Filter using `month`, `fco_id`, `ics`, `village`, `main_activity`, `sub_activity` (name values as returned by the mapping). Use `/farmers` with the same filters to refresh available farmers.
2. Select a mapped main/sub activity combination and available farmer IDs. Training methods: `General Training/Meeting`, `Input Demo INM`, `Input Demo PM`, `FFS`.
3. Male Count and Female Count are **manual nonnegative integer inputs**. Selecting farmers must not autofill these fields. Server computes `total_farmer_count = male_count + female_count`; `farmer_count` is the selected mapped farmer count. These two totals may differ, matching the current form rules.
4. Submit multipart data for files. Do not manually set `Content-Type` for FormData; fetch supplies the boundary. The API also accepts JSON for data with existing uploaded paths.

Example field object passed to `api.createTraining(fields, uploads)`:

```js
const fields = {
  month: mapping.month,
  ics_block: mapping.ics,
  gram_name: mapping.village,
  fco_name: mapping.fco_name,
  main_activity: mapping.main_activity,
  sub_activity: mapping.sub_activity,
  training_date: '2026-09-16',
  training_location: 'Village meeting hall',
  training_method: 'General Training/Meeting',
  training_description: 'Soil and crop training',
  male_count: maleCount,             // manual input
  female_count: femaleCount,         // manual input
  selected_farmer_ids: selectedIds,  // IDs from available farmers
  next_farmer_training_date: '2026-09-23'
};
await api.createTraining(fields, {
  training_register_upload: registerFile,
  photo_front_view: frontPhoto,
  photo_back_view: backPhoto
});
```

Trainer name/contact and creator identity come from the logged-in user. Required: mapped selection, FCO, training date/location, method/description, male/female counts, selected farmers, next training date, register upload and at least one training photo. Optional fields include `cluster_coordinator_name`, `agronomist_name`, `papl_staff_name`, `external_input`. Photo fields: `photo_front_view`, `photo_back_view`, `photo_close_up_view`, `photo_long_shot`, or legacy array `training_photo_upload_with_geo_tag`. Photos: JPEG/PNG/WEBP/HEIC/HEIF, maximum 5 MB each. Uploaded paths are returned inside record data; `/photos` returns absolute URLs.

## Other Target flow

Load `/other-targets/form-options`. Each mapping includes `vrp_id`, JJ name/contact, department, month, ICS, village, main/sub activities, target, farmers, completed farmer IDs and `new_farmer_target`.

Filter these mappings in React as month/ICS/village/activity changes. Show target and JJ identity from the selected mapping. Available farmers are `mapping.farmers.filter(f => !mapping.completed_farmer_ids.includes(String(f.id)))`.

```js
import { otherTargetFields } from './farmerTargetApi.mjs';
await api.createOther(otherTargetFields(mapping, {
  achievement: 3,
  selectedFarmerIds: selectedIds,
  completionDate: '2026-09-16'
}));
```

JSON body shape:

```json
{
  "other_target": {
    "jeevika_jankar_id": "123",
    "month": "September",
    "ics": "ICS name from mapping",
    "village": "Village name from mapping",
    "main_activity": "Main activity from mapping",
    "sub_activity": "Sub activity from mapping",
    "achievement": 3,
    "selected_farmer_ids": ["11", "12", "13"],
    "completion_date": "2026-09-16"
  }
}
```

IDs above are illustrative; use actual options. The server derives target, JJ contact and department from the accessible mapping. Achievement must be numeric, nonnegative and no greater than mapped target. Mapped farmers are required unless `new_farmer_target` is true. Already completed farmer IDs are removed by the existing completion logic. Creates use the `other-target` slug and appear in the existing web Other Target list.

## Demonstration responses

Both endpoints accept `month`, `fco_id`, `vrp_id`, `ics_id`, `village_id`. Month is an English month name, case insensitive; omitted month defaults to the previous calendar month. Invalid month returns 422. This follows the existing month-name model; there is no year filter. The list additionally accepts `q` (JJ/FCO/coordinator search), `page` and `per_page` (1–100, default 25). `count` is the total matching row count before pagination.

Example summary (illustrative):

```json
{
  "success": true,
  "month": "september",
  "opg_target": 35,
  "total": { "target": 55, "achievement": 5 },
  "methods": {
    "general_training_meeting": { "target": 13, "achievement": 3 },
    "input_demo_inm": { "target": 15, "achievement": 1 },
    "input_demo_pm": { "target": 13, "achievement": 1 },
    "ffs": { "target": 14, "achievement": 0 }
  },
  "fcos": []
}
```

`fcos` contains the same `opg_target`, `total`, `methods` fields per FCO, plus `fco_id`/`fco_name` (empty here only to shorten the example).

List row:

```json
{
  "fco_id": "1004",
  "fco_name": "FCO name",
  "vrp_id": 123,
  "vrp_name": "JJ name",
  "cluster_coordinator": "Coordinator name",
  "total": { "target": 13, "achievement": 3 },
  "methods": {
    "general_training_meeting": { "target": 13, "achievement": 3 },
    "input_demo_inm": { "target": 0, "achievement": 0 },
    "input_demo_pm": { "target": 0, "achievement": 0 },
    "ffs": { "target": 0, "achievement": 0 }
  },
  "status": "Yellow"
}
```

Display Target and Achievement in two boxes within the same card. No parsing of `"13 / 3"` is needed in React. Summary deduplicates targets per FCO/village; list deduplicates per FCO/JJ/village. Achievements count training records by month, method and creator ID, following the existing SQL. The four methods make up `total`; `opg_target` is a separate measure. Shared villages can therefore make the sum of list targets differ from the FCO summary. Status: Red for positive target with zero achievement, Yellow for partial achievement, Green otherwise (including zero target). Access is constrained by the authenticated user's existing scope; JJ tokens see their own targets.

## Errors and client files

401: missing/expired token. 404: nonexistent or inaccessible record. 422: validation errors, e.g. `{"success":false,"errors":["Achievement Target se jyada nahi ho sakta."]}`. Display errors and keep the form values; do not automatically retry POST requests because duplicate creates are possible.

- `docs/react-examples/farmerTargetApi.mjs`: fetch client, multipart builder and Other Target payload builder, usable from React/React Native.
- `docs/react-examples/DemonstrationMethod.jsx`: React web summary/list component with separate metric boxes and pagination.

Create the client once: `const api = createFarmerTargetApi({ baseUrl, getToken: () => token });`. Render `<DemonstrationMethod api={api} month="September" />`. React Native can use the client and render the same JSON using native View/Text components.

React web on another origin needs an existing reverse proxy or a server CORS allowlist for that origin. No CORS/deployment settings were changed. For development, proxy `/api` to Rails; React Native does not use browser CORS.
