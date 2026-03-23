---
name: strapi-create
description: Create new entries in Telnyx's Strapi CMS. Use when creating new /resources or /release-notes pages from scratch.
---

# Strapi Create Skill

## Configuration

```
Base URL: https://strapi.telnyx.tech/api
API Token: [REDACTED_STRAPI_TOKEN]
Staging Preview: https://www.dev.telnyx.com
```

## URL Ownership

This skill handles:
- `/resources/*` — Collection type: `rc-posts` (`api::rc-post.rc-post`)
- `/release-notes/*` — Product release notes

## ⚠️ Critical Rules

1. **Never set slug without confirmation** — confirm the exact slug with Max before creating
2. **Draft first** — always create with `"publishedAt": null`
3. **Never publish** without explicit approval from Max
4. **Always populate SEO fields** — `slug`, `seoTitle`, `seoDescription`
5. **featureImage format** — `{"title": "...", "file": MEDIA_ID}`
6. **Share staging link** after creating — `https://www.dev.telnyx.com/resources/{slug}`

---

## Input Requirement

**Do not begin until a complete JSON input block is provided.**
See `INPUT_SCHEMA.md` (same directory) for required fields.
If the user asks what fields are needed, return the template from INPUT_SCHEMA.md.

## Workflow: Draft → Staging → Prod

1. **Confirm slug** with Max before creating
2. **Look up author, category, and topic IDs** — use the lookup patterns below
3. **Upload or identify media** — get the media library ID for featureImage
4. **Create as draft** — POST with `"publishedAt": null`
5. **Share staging preview** — `https://www.dev.telnyx.com/resources/{slug}`
6. **Revise** based on feedback
7. **Wait for approval #1** — get Max's explicit approval before publishing
8. **Publish to prod** — publish the entry in Strapi
9. **Wait for approval #2** — get Max's explicit approval before revalidating
10. **Revalidate** — trigger cache revalidation so the live site reflects the change

---

## API Patterns

**Note:** All examples below use the full API token inline. Always use the token from the Configuration section above.

### Create Entry (Draft)
```bash
curl -s -X POST "https://strapi.telnyx.tech/api/rc-posts" \
  -H "Authorization: Bearer [REDACTED_STRAPI_TOKEN]" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "title": "Article Title",
      "slug": "article-slug",
      "seoTitle": "Article Title | Telnyx",
      "seoDescription": "Meta description (~155 chars).",
      "excerpt": "Short summary for listing cards.",
      "content": "Full article body in markdown.",
      "publishDate": "2026-03-16T12:00:00.000Z",
      "modifiedDate": "2026-03-16T12:00:00.000Z",
      "backgroundColor": "tan",
      "author": {
        "documentId": "author-document-id"
      },
      "category": {
        "documentId": "category-document-id"
      },
      "featureImage": {
        "title": "Image alt text",
        "file": 12345
      },
      "publishedAt": null
    }
  }'
```

### Look Up Authors
```bash
curl -s "https://strapi.telnyx.tech/api/rc-authors?pagination[limit]=100" \
  -H "Authorization: Bearer [REDACTED_STRAPI_TOKEN]" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['data']:
    print(item['documentId'], '|', item.get('name', item.get('title', '(no name)')))
"
```

### Look Up Categories
```bash
curl -s "https://strapi.telnyx.tech/api/rc-categories?pagination[limit]=100" \
  -H "Authorization: Bearer [REDACTED_STRAPI_TOKEN]" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['data']:
    print(item['documentId'], '|', item.get('name', item.get('title', '(no name)')))
"
```

### Look Up Topics
```bash
curl -s "https://strapi.telnyx.tech/api/rc-topics?pagination[limit]=100" \
  -H "Authorization: Bearer [REDACTED_STRAPI_TOKEN]" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['data']:
    print(item['documentId'], '|', item.get('name', item.get('title', '(no name)')))
"
```

### Upload Media to Library
```bash
curl -s -X POST "https://strapi.telnyx.tech/api/upload" \
  -H "Authorization: Bearer [REDACTED_STRAPI_TOKEN]" \
  -F "files=@/path/to/image.png" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data:
    print('Media ID:', item['id'])
    print('Name:', item['name'])
    print('URL:', item['url'])
"
```

Use the returned `id` (numeric) as the `file` value in `featureImage`, `thumbnail`, and `metaImage`.

### Search Media Library
```bash
curl -s "https://strapi.telnyx.tech/api/upload/files?filters[name][$contains]=search-term&pagination[limit]=10" \
  -H "Authorization: Bearer [REDACTED_STRAPI_TOKEN]" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data:
    print(item['id'], '|', item['name'], '|', item.get('url', ''))
"
```

### Publish to Prod (ONLY with explicit approval)
```bash
# ⚠️ This publishes the entry — only run with Max's explicit approval
curl -s -X POST "https://strapi.telnyx.tech/api/rc-posts/{documentId}/actions/publish" \
  -H "Authorization: Bearer [REDACTED_STRAPI_TOKEN]" \
  -H "Content-Type: application/json"
```

## featureImage Format
```json
{
  "featureImage": {
    "title": "Image alt text",
    "file": 12345
  }
}
```

`file` is the numeric ID from the Strapi media library. Use the "Upload Media" or "Search Media Library" patterns above to get it.

## Staging Preview URL
```
https://www.dev.telnyx.com/resources/{slug}
```
Always share this after creating. Do not publish to prod until Max reviews and approves.

## Revalidate Cache (ONLY with explicit approval — separate from publish approval)

After publishing, the live site still serves the cached version. Revalidation pushes the update to the live site.

**⚠️ This is a separate approval step. Do not revalidate just because Max approved publishing. Ask again: "Published. Ready to revalidate and push live?"**

```bash
# Revalidate a /resources page (no auth required)
curl -s -X POST "https://telnyx.com/api/revalidate?path=/resources/{slug}" \
  -H "Content-Type: application/json" -d ''
```

## Error Handling

If the Strapi API returns an error:
- **400** — Malformed request. Check field names, data types, and JSON structure. The response body has details.
- **401** — Token is invalid or expired. Verify you are using the full API token from the Configuration section.
- **403** — Token doesn't have permission for this operation.
- **404** — Endpoint or entry not found. Check the collection name and documentId.
- **422** — Validation error. A required field is missing or has the wrong type. Check the response body for which field failed.

Always report the full error response to the user before retrying.

## Memory

Create the `memory/` directory if it doesn't exist, then append to:
- **New entries created** → `memory/pages-created.md`
- **Patterns learned** → `memory/learnings.md`
