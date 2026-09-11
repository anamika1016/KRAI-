# Translation API for React Native

Use your application's backend URL:

```http
POST https://krai.ploughmanagro.com/api/v1/translate
Authorization: Bearer <APPLICATION_LOGIN_TOKEN>
Content-Type: application/json
```

```json
{
  "q": ["Dashboard", "Training Form", "Mapped Villages"],
  "source": "en",
  "target": "hi"
}
```

Response shape (illustrative translated text):

```json
{
  "success": true,
  "source": "en",
  "target": "hi",
  "translations": [
    {"text": "Dashboard", "translated_text": "डैशबोर्ड"},
    {"text": "Training Form", "translated_text": "प्रशिक्षण फ़ॉर्म"},
    {"text": "Mapped Villages", "translated_text": "मैप किए गए गाँव"}
  ]
}
```

`GET https://krai.ploughmanagro.com/api/v1/translate/languages` returns supported languages. Both endpoints require the application's Bearer token, obtained from `/api/v1/jeevika-jankar-login` or the existing application login API. This repository contains the implementation; deployment to the production host was not performed or verified in this task.

## Required server configuration

The Rails process must have `GOOGLE_TRANSLATE_API_KEY` set to a Google Cloud Translation Basic API key. Enable Cloud Translation and billing in that Google Cloud project, restrict the key to that API and applicable server IPs, and restart/redeploy the Rails service with the environment variable. No key was created or installed by this task. Keep it on the server, never in the React Native bundle or a shared Postman collection.

The backend calls `https://translation.googleapis.com/language/translate/v2` with the Google key in `X-Goog-Api-Key`. Your application token authenticates to the Rails backend only. Sending it directly to Google causes authentication errors like the earlier `401 ACCESS_TOKEN_TYPE_UNSUPPORTED` screenshot.

Official Google authentication reference: https://docs.cloud.google.com/translate/docs/authentication
Official REST reference: https://docs.cloud.google.com/translate/docs/reference/rest/v2/translate

## Request rules

- `q`: one nonblank string or 1–100 nonblank strings; at most 5,000 characters total.
- `source`: defaults to `en`; `target` is required.
- Languages: English `en`, Hindi `hi`, Marathi `mr`, Odia `or`, Gujarati `gu`.
- Source equal to target returns original strings without calling Google.
- Duplicate strings are translated once per request; response preserves input order and duplicates.
- Network timeouts are bounded. Provider bodies and credentials are not returned in errors.
- Configured request limit: 60 per user per minute, using the application's Rails cache store. Multi-instance enforcement requires a shared cache supporting atomic increments; a null cache does not enforce it.

## Errors

| Status | Meaning |
| --- | --- |
| 401 | Missing/invalid application login token |
| 422 `invalid_request` | Invalid language, text or batch size |
| 503 `translation_not_configured` | Google key missing from server environment |
| 502 `translation_unavailable` | Google authentication/billing/quota/network or response failure |
| 504 `translation_timeout` | Google request timed out |
| 429 `rate_limited` | Configured request limit exceeded |

## Translating the whole mobile application

Call this endpoint with the labels and dynamic text for each screen, in bounded batches. Store translations in React state/context and switch the displayed text when the selected language changes. Cache static labels by original text/source/target and ignore stale responses from a previous language selection. Preserve IDs, field values, numbers and payload keys used by business APIs.

This endpoint translates supplied strings; it does not inspect or translate a native screen automatically. The existing web Google Translate widget remains separate and unchanged.

Import `docs/postman/jj-dashboard-and-translation.postman_collection.json` for login, all dashboard boxes/lists/exports and translation examples. An English-to-English request and the language catalog work without a Google key; Hindi/Marathi/Odia/Gujarati translation requires the server setup above.
