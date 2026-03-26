---
name: payload-create
description: Create new entries in Telnyx's Payload CMS. Use when creating new /resources pages from scratch.
---

# Payload Create Skill

## Configuration

```
Base URL: https://cms.telnyx.com/api
Admin: https://cms.telnyx.com/admin
API Key: 535a9fb8-8f88-415e-be2f-a82fb883f496
Auth Header: Authorization: users API-Key 535a9fb8-8f88-415e-be2f-a82fb883f496
Staging Preview: https://www.dev.telnyx.com
```

## URL Ownership

This skill handles:
- `/resources/*` — Collection: `resources`

## Collections

| Collection | Endpoint | Purpose |
|---|---|---|
| `resources` | `/api/resources` | Blog/resource posts |
| `authors` | `/api/authors` | Post authors (58 total) |
| `categories` | `/api/categories` | Post categories (8 total) |
| `topics` | `/api/topics` | Post topics (29 total) |
| `media` | `/api/media` | Media library (images) |

## Critical Rules

1. **Never set slug without confirmation** — confirm the exact slug with Max before creating
2. **Draft first** — always create as draft (Payload defaults to draft, do NOT set `_status: published`)
3. **Never publish** without explicit approval from Max
4. **Always populate SEO fields** — `seoTitle`, `seoDescription`
5. **Share staging link** after creating — `https://www.dev.telnyx.com/resources/{slug}`

---

## Input Requirement

**Do not begin until a complete JSON input block is provided.**
See `INPUT_SCHEMA.md` (same directory) for required fields. If the user asks what fields are needed, return the template from INPUT_SCHEMA.md.

## Workflow: Draft -> Staging -> Prod

1. **Confirm slug** with Max before creating
2. **Look up author, category, and topic IDs** — use the lookup patterns below
3. **Upload or identify media** — get the media library ID for featureImage
4. **Create as draft** — POST (Payload defaults to draft)
5. **Share staging preview** — `https://www.dev.telnyx.com/resources/{slug}`
6. **Revise** based on feedback
7. **Wait for approval #1** — get Max's explicit approval before publishing
8. **Publish to prod** — PATCH with `_status: published` and set `modifiedDate` to now
9. **Wait for approval #2** — get Max's explicit approval before revalidating
10. **Revalidate** — trigger cache revalidation so the live site reflects the change

---

## Content Model

Entries support two content approaches:

- **`content`** (string) — Full markdown body in a single field. Used by older/migrated entries.
- **`dynamicSections`** (array of blocks) — Structured sections with per-section settings. Preferred for new content.

For **new entries**, use `dynamicSections` with `markdown-section` blocks:

```json
{
  "dynamicSections": [
    {
      "copy": "## Section heading\n\nMarkdown content here...",
      "backgroundColor": "white",
      "spacingTop": "default",
      "spacingBottom": "default",
      "fullWidth": false,
      "blockType": "markdown-section"
    }
  ]
}
```

You can also use the flat `content` field if the article doesn't need per-section styling. Both work — but don't use both on the same entry.

---

## API Patterns

### Create Entry (Draft)

```bash
curl -s -X POST "https://cms.telnyx.com/api/resources" \
  -H "Authorization: users API-Key 535a9fb8-8f88-415e-be2f-a82fb883f496" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Article Title",
    "slug": "article-slug",
    "seoTitle": "Article Title | Telnyx",
    "seoDescription": "Meta description (~155 chars).",
    "excerpt": "Short summary for listing cards.",
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
    "author": 20,
    "category": 4,
    "topic": 17,
    "featureImage": {
      "file": 123,
      "useParallax": false
    }
  }'
```

Payload creates entries as drafts by default. Do NOT include `_status` in the request body.

### Look Up Authors

```bash
curl -s "https://cms.telnyx.com/api/authors?limit=100" \
  -H "Authorization: users API-Key 535a9fb8-8f88-415e-be2f-a82fb883f496" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['docs']:
    print(item['id'], '|', item.get('firstName',''), item.get('lastName',''))
"
```

### Look Up Categories

```bash
curl -s "https://cms.telnyx.com/api/categories?limit=100" \
  -H "Authorization: users API-Key 535a9fb8-8f88-415e-be2f-a82fb883f496" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['docs']:
    print(item['id'], '|', item.get('name',''), '|', item.get('slug',''))
"
```

### Look Up Topics

```bash
curl -s "https://cms.telnyx.com/api/topics?limit=100" \
  -H "Authorization: users API-Key 535a9fb8-8f88-415e-be2f-a82fb883f496" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['docs']:
    print(item['id'], '|', item.get('name',''), '|', item.get('slug',''))
"
```

### Upload Media

```bash
curl -s -X POST "https://cms.telnyx.com/api/media" \
  -H "Authorization: users API-Key 535a9fb8-8f88-415e-be2f-a82fb883f496" \
  -F "file=@/path/to/image.png" \
  -F "alt=Image alt text" | python3 -c "
import sys, json
data = json.load(sys.stdin)
doc = data['doc']
print('Media ID:', doc['id'])
print('Filename:', doc['filename'])
print('URL:', doc['url'])
"
```

Use the returned `id` (numeric) as the `file` value in `featureImage`, `thumbnail`, and `metaImage`.

### Search Media Library

```bash
curl -s "https://cms.telnyx.com/api/media?where[filename][contains]=search-term&limit=10" \
  -H "Authorization: users API-Key 535a9fb8-8f88-415e-be2f-a82fb883f496" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['docs']:
    print(item['id'], '|', item['filename'], '|', item.get('url', ''))
"
```

### Publish to Prod (ONLY with explicit approval)

Publishing is a two-step process: set `modifiedDate`, then set `_status` to `published`.

```bash
# Publish (sets modifiedDate and _status in one PATCH)
curl -s -X PATCH "https://cms.telnyx.com/api/resources/{id}" \
  -H "Authorization: users API-Key 535a9fb8-8f88-415e-be2f-a82fb883f496" \
  -H "Content-Type: application/json" \
  -d '{
    "modifiedDate": "'"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"'",
    "_status": "published"
  }'
```

## Relationship Fields

In Payload CMS, relationships use the numeric `id` directly (not a nested object):

```json
{
  "author": 20,
  "category": 4,
  "topic": 17
}
```

## featureImage / thumbnail / metaImage Format

```json
{
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

`file` is the numeric ID from the Payload media library.

## Staging Preview URL

```
https://www.dev.telnyx.com/resources/{slug}
```

Always share this after creating. Do not publish to prod until Max reviews and approves.

## Revalidate Cache (ONLY with explicit approval — separate from publish approval)

After publishing, the live site still serves the cached version. Revalidation pushes the update to the live site.

**This is a separate approval step. Do not revalidate just because Max approved publishing. Ask again: "Published. Ready to revalidate and push live?"**

```bash
# Revalidate a /resources page (no auth required)
curl -s -X POST "https://telnyx.com/api/revalidate?path=/resources/{slug}" \
  -H "Content-Type: application/json" -d ''
```

## Error Handling

If the Payload API returns an error:

- **400** — Validation error. Check required fields, data types. The response body contains field-level errors.
- **401** — Not authenticated. Verify the API key.
- **403** — Not authorized. The API key user doesn't have permission for this operation.
- **404** — Endpoint or entry not found. Check the collection name and ID.

Always report the full error response to the user before retrying.

## Memory

Create the `memory/` directory if it doesn't exist, then append to:
- **New entries created** -> `memory/pages-created.md`
- **Patterns learned** -> `memory/learnings.md`
