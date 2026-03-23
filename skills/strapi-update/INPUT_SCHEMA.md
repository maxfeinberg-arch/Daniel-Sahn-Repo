# Strapi Update Schema

When updating Strapi entries, you **must read the entry first** to confirm it exists and understand its current state.

Unlike Contentful, Strapi PUT only updates fields you include — omitted fields are left unchanged. But you should still read first to avoid blind edits.

**Do not begin updating until you know the documentId and what changes to make.**

---

## rc-posts — `/resources/{slug}`

```json
{
  "documentId": "EXISTING_DOCUMENT_ID",
  "changes": {
    "title": "Updated article title",
    "seoTitle": "Updated Title | Telnyx",
    "seoDescription": "Updated meta description (~155 chars).",
    "excerpt": "Updated listing card summary.",
    "content": "Updated full article body (markdown).",
    "modifiedDate": "2026-03-23T12:00:00.000Z",
    "backgroundColor": "tan",
    "readTime": null,
    "applyNoIndex": null,
    "author": {
      "documentId": "author-document-id"
    },
    "category": {
      "documentId": "category-document-id"
    },
    "topic": {
      "documentId": "topic-document-id"
    },
    "featureImage": {
      "title": "Updated alt text",
      "file": 12345
    },
    "thumbnail": {
      "title": "Updated thumbnail alt text",
      "file": 12345
    },
    "metaImage": {
      "title": "Updated OG image alt text",
      "file": 12345
    }
  }
}
```

Only include fields you are changing. Omitted fields stay as-is.

---

## Field Rules

| Field | Rule |
|---|---|
| `slug` | **NEVER change** — human-only decision, do not touch under any circumstances. |
| `seoTitle` | Format: `{Title} \| Telnyx` |
| `seoDescription` | ~155 chars, keyword-intentional |
| `excerpt` | 1–2 sentences for listing cards |
| `content` | Full body — markdown accepted |
| `publishDate` | Do not change unless explicitly asked — this is the original publish date |
| `modifiedDate` | Update to current timestamp **only before revalidating** (not on every edit) |
| `backgroundColor` | Known values: `tan`, `black`, `white` |
| `author.documentId` | Must be a valid Strapi author documentId |
| `category.documentId` | Must be a valid Strapi category documentId |
| `featureImage.file` | Strapi media library numeric ID |

## Before You Start

- Confirm the documentId exists (GET it first)
- Confirm which fields to change with the user
- Never change the slug
- Never change fields you weren't asked to change
- If republishing, update `modifiedDate` to current timestamp before revalidating
