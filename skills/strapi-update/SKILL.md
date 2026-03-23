---
name: strapi-update
description: Update and publish existing entries in Telnyx's Strapi CMS. Use when editing or publishing existing /resources or /release-notes pages.
---

# Strapi Update Skill

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

1. **Never change slug** — human-only decision, do not touch under any circumstances
2. **Read before writing** — always fetch the entry first to get current fields and avoid conflicts
3. **Draft by default** — save as draft, share staging link, publish to prod only on explicit approval
4. **featureImage format** — `{"title": "...", "file": MEDIA_ID}`

## Auth Header
```
Authorization: Bearer [REDACTED_STRAPI_TOKEN]
Content-Type: application/json
```

---

## Workflow: Draft → Staging → Prod

1. **Find the post** — search by slug to get the `documentId`
2. **Read the draft** — `GET /rc-posts/{documentId}?status=draft`
3. **Update the draft** — `PUT /rc-posts/{documentId}?status=draft` — **`?status=draft` is mandatory**, omitting it writes directly to the live published version
4. **Share staging link** — `https://www.dev.telnyx.com/resources/{slug}`
5. **Wait for approval #1** — get Max's explicit approval before publishing
6. **Publish to prod** — publish the entry in Strapi
7. **Wait for approval #2** — get Max's explicit approval before revalidating
8. **Revalidate** — trigger cache revalidation so the live site reflects the change

---

## API Patterns

### Find Entry by Slug (get documentId)
```bash
# Always read the draft version
curl -s -g "https://strapi.telnyx.tech/api/rc-posts?filters[slug][$eq]=my-slug&status=draft&populate=*" \
  -H "Authorization: Bearer [REDACTED_STRAPI_TOKEN]" | python3 -c "
import sys, json
data = json.load(sys.stdin)
item = data['data'][0]
print('documentId:', item['documentId'])
print('id:', item['id'])
print('slug:', item['slug'])
"
```

### Get Full Entry (draft version)
```bash
curl -s "https://strapi.telnyx.tech/api/rc-posts/{documentId}?status=draft&populate=*" \
  -H "Authorization: Bearer [REDACTED_STRAPI_TOKEN]"
```

### Update Entry Fields (ALWAYS use ?status=draft)
```bash
# ⚠️ ?status=draft is REQUIRED — omitting it updates the live published version directly
curl -s -X PUT "https://strapi.telnyx.tech/api/rc-posts/{documentId}?status=draft" \
  -H "Authorization: Bearer [REDACTED_STRAPI_TOKEN]" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "title": "Updated Title",
      "seoTitle": "Updated Title | Telnyx",
      "seoDescription": "Updated description."
    }
  }'
```

### Read Draft Version (before updating)
```bash
curl -s "https://strapi.telnyx.tech/api/rc-posts/{documentId}?status=draft&populate=*" \
  -H "Authorization: Bearer [REDACTED_STRAPI_TOKEN]"
```

### Publish to Prod (ONLY with explicit approval from Max)
```bash
curl -s -X PUT "https://strapi.telnyx.tech/api/rc-posts/{documentId}" \
  -H "Authorization: Bearer [REDACTED_STRAPI_TOKEN]" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "publishedAt": "'"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"'"
    }
  }'
```

### Unpublish Entry
```bash
curl -s -X PUT "https://strapi.telnyx.tech/api/rc-posts/{documentId}" \
  -H "Authorization: Bearer [REDACTED_STRAPI_TOKEN]" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "publishedAt": null
    }
  }'
```

## featureImage Format
```json
{
  "featureImage": {
    "title": "Image alt text",
    "file": MEDIA_ID
  }
}
```

## Staging Preview URL
```
https://www.dev.telnyx.com/resources/{slug}
```
Always share this after saving as draft. Do not publish to prod until Max reviews and approves.

## Revalidate Cache (ONLY with explicit approval — separate from publish approval)

After publishing, the live site still serves the cached version. Revalidation pushes the update to the live site.

**⚠️ This is a separate approval step. Do not revalidate just because Max approved publishing. Ask again: "Published. Ready to revalidate and push live?"**

**Before revalidating, update `modifiedDate` to the current timestamp:**
```bash
# Step 1: Set modifiedDate to now (use ?status=draft then publish)
curl -s -X PUT "https://strapi.telnyx.tech/api/rc-posts/{documentId}?status=draft" \
  -H "Authorization: Bearer [REDACTED_STRAPI_TOKEN]" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "modifiedDate": "'"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"'"
    }
  }'

# Step 2: Re-publish with the updated modifiedDate
curl -s -X POST "https://strapi.telnyx.tech/api/rc-posts/{documentId}/actions/publish" \
  -H "Authorization: Bearer [REDACTED_STRAPI_TOKEN]" \
  -H "Content-Type: application/json"

# Step 3: Revalidate (no auth required)
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
- **Updated entries** → `memory/pages-created.md`
- **Patterns learned** → `memory/learnings.md`
