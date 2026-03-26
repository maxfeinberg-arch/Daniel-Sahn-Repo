# Payload Input Schema

All Payload page creation requires structured JSON input submitted upfront.
**Do not begin creating entries until all required fields are provided.**

---

## resources — `/resources/{slug}`

```json
{
  "page_type": "resource",
  "title": "Article title",
  "slug": "article-slug",
  "seoTitle": "Article Title | Telnyx",
  "seoDescription": "Meta description (~155 chars, keyword-intentional).",
  "excerpt": "Short summary shown in listing cards (~1-2 sentences).",
  "dynamicSections": [
    {
      "copy": "Full article body in markdown.",
      "backgroundColor": "white",
      "spacingTop": "default",
      "spacingBottom": "default",
      "fullWidth": false,
      "blockType": "markdown-section"
    }
  ],
  "publishDate": "2026-03-26T12:00:00.000Z",
  "backgroundColor": "tan",
  "applyNoIndex": false,
  "author": 20,
  "category": 4,
  "topic": 17,
  "featureImage": {
    "file": 123,
    "useParallax": false
  },
  "thumbnail": {
    "file": 123
  },
  "metaImage": {
    "file": 123
  }
}
```

**Required:** `title`, `slug`, `seoTitle`, `seoDescription`, `excerpt`, `dynamicSections` (or `content`), `publishDate`, `author`, `category`, `featureImage`

---

## Field Notes

| Field | Notes |
|---|---|
| `slug` | Confirm with Max — never change after publish |
| `seoTitle` | Format: `{Title} \| Telnyx` |
| `seoDescription` | ~155 chars |
| `excerpt` | Shown in resource listing cards — keep tight, 1-2 sentences |
| `content` | Full body markdown (legacy approach — use for simple single-section articles) |
| `dynamicSections` | Array of `markdown-section` blocks (preferred for new content) |
| `publishDate` | ISO 8601 UTC format |
| `backgroundColor` | Affects card display — known values: `tan`, `black`, `white` |
| `applyNoIndex` | Boolean — set `true` to add noindex meta tag |
| `author` | Numeric author ID (use lookup to find) |
| `category` | Numeric category ID (use lookup to find) |
| `topic` | Numeric topic ID (optional but recommended) |
| `featureImage.file` | Payload media library numeric ID |
| `featureImage.useParallax` | Boolean — parallax effect on feature image (default `false`) |
| `thumbnail.file` | Payload media library numeric ID (often same as featureImage) |
| `metaImage.file` | Payload media library numeric ID (used for OG/social share) |

## Known Category IDs

| ID | Name |
|---|---|
| 1 | Customer Service |
| 2 | Events |
| 3 | Guides and Tutorials |
| 4 | Insights and Resources |
| 5 | New Products and Features |
| 6 | Partnerships |
| 7 | Video |
| 8 | News and Events |

## If Fields Are Missing

If a required field is not provided, ask for it before proceeding. Do not invent values for slug, author, category, or image IDs.
