# Payload Update Schema

When updating Payload entries, you **must read the entry first** to confirm it exists and understand its current state.

Payload PATCH is a true partial update — only include fields you are changing. Omitted fields stay as-is.

**Do not begin updating until you know the id and what changes to make.**

---

## resources — `/resources/{slug}`

```json
{
  "id": 123,
  "changes": {
    "title": "Updated article title",
    "seoTitle": "Updated Title | Telnyx",
    "seoDescription": "Updated meta description (~155 chars).",
    "excerpt": "Updated listing card summary.",
    "content": "Updated full article body (markdown).",
    "dynamicSections": [
      {
        "copy": "Updated section content in markdown.",
        "backgroundColor": "white",
        "spacingTop": "default",
        "spacingBottom": "default",
        "fullWidth": false,
        "blockType": "markdown-section"
      }
    ],
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
}
```

Only include fields you are changing. Omitted fields stay as-is.

**Exception:** `dynamicSections` must be sent as the full array — you cannot partially update individual sections.

---

## Field Rules

| Field | Rule |
|---|---|
| `slug` | **NEVER change** — human-only decision, do not touch under any circumstances. |
| `seoTitle` | Format: `{Title} \| Telnyx` |
| `seoDescription` | ~155 chars, keyword-intentional |
| `excerpt` | 1-2 sentences for listing cards |
| `content` | Full body markdown (legacy approach) |
| `dynamicSections` | Array of `markdown-section` blocks (preferred for new content) |
| `publishDate` | Do not change unless explicitly asked — this is the original publish date |
| `modifiedDate` | Update to current timestamp **once, right before publishing** (not on every draft edit, not during revalidation) |
| `backgroundColor` | Known values: `tan`, `black`, `white` |
| `author` | Numeric author ID |
| `category` | Numeric category ID |
| `topic` | Numeric topic ID |
| `featureImage.file` | Payload media library numeric ID |

## Before You Start

- Confirm the entry exists (GET it first)
- Confirm which fields to change with the user
- Never change the slug
- Never change fields you weren't asked to change
- If republishing, update `modifiedDate` to current timestamp before setting `_status: published`
