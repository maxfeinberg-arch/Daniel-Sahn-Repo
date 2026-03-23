# Strapi Input Schema

All Strapi page creation requires structured JSON input submitted upfront.
**Do not begin creating entries until all required fields are provided.**

---

## rc-posts — `/resources/{slug}`

```json
{
  "page_type": "rc-post",
  "title": "Article title",
  "slug": "article-slug",
  "seoTitle": "Article Title | Telnyx",
  "seoDescription": "Meta description (~155 chars, keyword-intentional).",
  "excerpt": "Short summary shown in listing cards (~1–2 sentences).",
  "content": "Full article body (markdown or HTML).",
  "publishDate": "2026-03-12T12:00:00.000Z",
  "modifiedDate": "2026-03-12T12:00:00.000Z",
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
    "title": "Image alt text",
    "file": 12345
  },
  "thumbnail": {
    "title": "Thumbnail alt text",
    "file": 12345
  },
  "metaImage": {
    "title": "OG image alt text",
    "file": 12345
  }
}
```

**Required:** `title`, `slug`, `seoTitle`, `seoDescription`, `excerpt`, `content`, `publishDate`, `author`, `category`, `featureImage`

---

## Field Notes

| Field | Notes |
|---|---|
| `slug` | Confirm with Max — never change after publish |
| `seoTitle` | Format: `{Title} \| Telnyx` |
| `seoDescription` | ~155 chars |
| `excerpt` | Shown in resource listing cards — keep tight, 1–2 sentences |
| `content` | Full body content — markdown accepted |
| `publishDate` | ISO 8601 UTC format |
| `backgroundColor` | Affects card display — known values: `tan`, `black`, `white` |
| `author.documentId` | Must be a valid Strapi author documentId |
| `category.documentId` | Must be a valid Strapi category documentId |
| `topic.documentId` | Optional but recommended |
| `featureImage.file` | Strapi media library numeric ID |
| `thumbnail.file` | Strapi media library numeric ID (often same as featureImage) |
| `metaImage.file` | Strapi media library numeric ID (used for OG/social share) |

## If Fields Are Missing

If a required field is not provided, ask for it before proceeding. Do not invent values for slug, author, category, or image IDs.
