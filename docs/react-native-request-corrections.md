# React Native request and performance follow-up

## Farmer Training 422

The supplied production requests send `selected_farmers: "[]"` and omit both upload fields. The API requires `selected_farmer_ids` plus `training_register_upload` and `training_photo_upload_with_geo_tag`. Returning 422 for those requests is the existing validation behavior; accepting them would change the business rules.

Read the response's `errors` array and display it to the user. Obtain valid pending farmer IDs from the filtered `/api/v1/farmer-trainings/farmers` endpoint. Submit all existing required form fields, and append the selected IDs and files using multipart form data:

```javascript
const body = new FormData();
Object.entries(fields).forEach(([key, value]) => {
  body.append(`farmer_training[${key}]`, String(value));
});
selectedFarmerIds.forEach(id => {
  body.append('farmer_training[selected_farmer_ids][]', String(id));
});
body.append('farmer_training[training_register_upload]', registerFile);
photos.forEach(photo => {
  body.append('farmer_training[training_photo_upload_with_geo_tag][]', photo);
});
const response = await fetch(`${baseUrl}/api/v1/farmer-trainings`, {
  method: 'POST',
  headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' },
  body,
});
const result = await response.json();
// Surface result.errors when response.status === 422.
```

`fields` contains the existing required scalar form fields. React Native file objects need `uri`, `name`, and `type`. Let the client set the multipart Content-Type boundary. Do not replace empty selections with unrelated farmer IDs or fabricated uploads.

## Weekly participation

The web dashboard uses `weekly_target_week=1..4`; participation drill-down links use `week=1..4`. Weeks follow existing training-date rules: days 1–7, 8–14, 15–21, and 22–month end. Monthly mappings remain the same; attendance and no-training status are evaluated within the selected week. Unique monthly farmer counts are not divided by four, and weekly distinct counts need not add up to monthly distinct counts when a farmer attends in multiple weeks. Omit the week for existing all-weeks behavior.

The JJ weekly-plan API uses `target_week=week_1..week_4`, returns the existing `week_plan` and `week_achieved`, and now includes `week_pending` (plan minus achieved, floored at zero).

## Translation configuration

The screenshot's `translation_not_configured` response means the production Rails process is missing `GOOGLE_TRANSLATE_API_KEY`. A valid server-side Google Cloud Translation key must be configured in the Puma service environment and the service restarted by the deployment operator. A browser GET to `/api/v1/translate` is not the translation operation; use authenticated POST with `Content-Type: application/json` and `q`, `source`, `target`. See [translation API setup](react-native-translation-api.md). No provider key was created or configured in this task.

## Performance validation

Bill profiling found repeated rebuilding of an already calculated achievement index when an individual target had no entry. Reusing that missing result reduced index construction from 14 to 2 calls for a local 58-bill sample. Further changes index candidate targets by JJ/month and avoid loading global assignment groups for a target with no group key. Profiling used TracePoint, so its elapsed times are not production request benchmarks.

Farmer-training creation no longer hydrates the entire farmer picker just to match target metadata. Empty selections skip unnecessary pending-farmer scans. The filtered form/farmer endpoints now filter metadata before hydrating farmer details; the months endpoint does not hydrate farmers. API response fields and validation requirements are preserved.

Final database verification of the latest weekly/filter changes was blocked by the automatic approval review usage limit. Earlier API/bill regressions had one unrelated existing web-label failure (`Internal Trainer Name 1` expectation). Production millisecond latency has not been verified and no deployment was performed.
