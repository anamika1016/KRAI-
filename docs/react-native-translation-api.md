# Translation handoff for React Native

## Current website integration

The website uses Google's browser TranslateElement widget plus local UI dictionaries in `app/javascript/layout.js`. It loads:

`https://translate.google.com/translate_a/element.js?cb=googleTranslateElementInit`

This is a browser JavaScript widget, not a JSON translation API. The website integration does not contain a Google Cloud translation API key. No new mobile endpoint or Google Cloud account has been provisioned in this change.

Languages used by the website: English `en`, Hindi `hi`, Marathi `mr`, Odia `or`, Gujarati `gu`. Source language is `en`.

## API for native text

Google Cloud Translation Basic:

```http
POST https://translation.googleapis.com/language/translate/v2
Authorization: Bearer <SERVER_ACCESS_TOKEN>
x-goog-user-project: <GOOGLE_CLOUD_PROJECT_ID>
Content-Type: application/json
```

```json
{
  "q": ["Dashboard", "Training Form"],
  "source": "en",
  "target": "hi",
  "format": "text"
}
```

Response shape:

```json
{
  "data": {
    "translations": [
      { "translatedText": "डैशबोर्ड" },
      { "translatedText": "प्रशिक्षण फ़ॉर्म" }
    ]
  }
}
```

Example translations are illustrative; Google's output can vary.

Enable Cloud Translation in a Google Cloud project with billing and server credentials. Call Google from an authenticated backend; keep credentials off the React Native client. The mobile app should call that backend with its normal login token. This repository does not currently provide that proxy endpoint.

For fixed screen labels, bundle dictionaries and update React state/context immediately when the language changes. For dynamic text, batch requests, cache by source text and target language, and discard stale responses if the user selects another language. Translate display labels only: retain original IDs, dropdown values and request payload values.

Official reference: https://docs.cloud.google.com/translate/docs/reference/rest/v2/translate
Setup and examples: https://docs.cloud.google.com/translate/docs/basic/translating-text
