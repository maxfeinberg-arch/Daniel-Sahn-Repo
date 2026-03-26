---
name: payload-update
description: Update and publish existing entries in Telnyx's Payload CMS. Use when editing or publishing existing /resources pages.
---

# Payload Update Skill

## Configuration

```
Base URL: https://cms.telnyx.com/api
Admin: https://cms.telnyx.com/admin
API Key: REDACTED
Auth Header: Authorization: users API-Key REDACTED
Staging Preview: https://www.dev.telnyx.com
```

## URL Ownership

This skill handles:
- `/resources/*` — Collection: `resources`

## Critical Rules

1. **Never change slug** — human-only decision, do not touch under any circumstances
2. **Read before writing** — always fetch the entry first to see current fields and avoid conflicts
3. **Draft by default** — save as draft, share staging link, publish only on explicit approval
4. **PATCH is partial** — Payload PATCH only updates fields you include; omitted fields stay as-is

---

## Workflow: Draft -> Staging -> Prod

1. **Find the post** — search by slug to get the `id`
2. **Read the draft** — `GET /api/resources/{id}?draft=true`
3. **Update the draft** — `PATCH /api/resources/{id}` with only the changed fields
4. **Share staging link** — `https://www.dev.telnyx.com/resources/{slug}`
5. **Wait for approval #1** — get Max's explicit approval before publishing
6. **Publish to prod** — PATCH with `modifiedDate` set to now and `_status: published`
7. **Wait for approval #2** — get Max's explicit approval before revalidating
8. **Revalidate** — bust the cache so the live site reflects the change

---

## API Patterns

### Find Entry by Slug

```bash
curl -s "https://cms.telnyx.com/api/resources?where[slug][equals]=my-slug&draft=true&depth=1" \
  -H "Authorization: users API-Key REDACTED" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data['docs']:
    item = data['docs'][0]
    print('id:', item['id'])
    print('slug:', item['slug'])
    print('title:', item['title'])
    print('_status:', item['_status'])
else:
    print('NOT FOUND')
"
```

### Get Full Entry (draft version)

```bash
curl -s "https://cms.telnyx.com/api/resources/{id}?draft=true&depth=1" \
  -H "Authorization: users API-Key REDACTED"
```

### Update Entry Fields (PATCH — partial update)

```bash
# Payload PATCH is a true partial update — only include fields you are changing
curl -s -X PATCH "https://cms.telnyx.com/api/resources/{id}" \
  -H "Authorization: users API-Key REDACTED" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Updated Title",
    "seoTitle": "Updated Title | Telnyx",
    "seoDescription": "Updated description."
  }'
```

This updates ONLY the specified fields. All other fields remain unchanged.

### Update dynamicSections

When updating `dynamicSections`, you must send the **entire array** (not a partial diff), because it's an array field:

```bash
curl -s -X PATCH "https://cms.telnyx.com/api/resources/{id}" \
  -H "Authorization: users API-Key REDACTED" \
  -H "Content-Type: application/json" \
  -d '{
    "dynamicSections": [
      {
        "copy": "## Updated section\n\nNew markdown content...",
        "backgroundColor": "white",
        "spacingTop": "default",
        "spacingBottom": "default",
        "fullWidth": false,
        "blockType": "markdown-section"
      }
    ]
  }'
```

### Publish to Prod (ONLY with explicit approval from Max)

Publishing is done by PATCHing `_status` to `published`. Set `modifiedDate` at the same time.

```bash
# Publish (sets modifiedDate and _status in one PATCH)
curl -s -X PATCH "https://cms.telnyx.com/api/resources/{id}" \
  -H "Authorization: users API-Key REDACTED" \
  -H "Content-Type: application/json" \
  -d '{
    "modifiedDate": "'"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"'",
    "_status": "published"
  }'
```

### Unpublish Entry

```bash
curl -s -X PATCH "https://cms.telnyx.com/api/resources/{id}" \
  -H "Authorization: users API-Key REDACTED" \
  -H "Content-Type: application/json" \
  -d '{
    "_status": "draft"
  }'
```

### List Entries (with filters)

```bash
# By status
curl -s "https://cms.telnyx.com/api/resources?where[_status][equals]=published&limit=10&sort=-publishDate" \
  -H "Authorization: users API-Key REDACTED"

# By category
curl -s "https://cms.telnyx.com/api/resources?where[category][equals]=4&limit=10&draft=true" \
  -H "Authorization: users API-Key REDACTED"

# By author
curl -s "https://cms.telnyx.com/api/resources?where[author][equals]=20&limit=10&draft=true" \
  -H "Authorization: users API-Key REDACTED"

# Use draft=false for published (not where clause)
curl -s "https://cms.telnyx.com/api/resources?draft=false&limit=10" \
  -H "Authorization: users API-Key REDACTED"
```

### Look Up Authors

```bash
curl -s "https://cms.telnyx.com/api/authors?limit=100" \
  -H "Authorization: users API-Key REDACTED" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['docs']:
    print(item['id'], '|', item.get('firstName',''), item.get('lastName',''))
"
```

### Look Up Categories

```bash
curl -s "https://cms.telnyx.com/api/categories?limit=100" \
  -H "Authorization: users API-Key REDACTED" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['docs']:
    print(item['id'], '|', item.get('name',''), '|', item.get('slug',''))
"
```

### Look Up Topics

```bash
curl -s "https://cms.telnyx.com/api/topics?limit=100" \
  -H "Authorization: users API-Key REDACTED" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['docs']:
    print(item['id'], '|', item.get('name',''), '|', item.get('slug',''))
"
```

### Upload Media

```bash
curl -s -X POST "https://cms.telnyx.com/api/media" \
  -H "Authorization: users API-Key REDACTED" \
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

### Search Media Library

```bash
curl -s "https://cms.telnyx.com/api/media?where[filename][contains]=search-term&limit=10" \
  -H "Authorization: users API-Key REDACTED" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['docs']:
    print(item['id'], '|', item['filename'], '|', item.get('url', ''))
"
```

## Relationship Fields

In Payload CMS, relationships use the numeric `id` directly:

```json
{
  "author": 20,
  "category": 4,
  "topic": 17
}
```

## featureImage Format

```json
{
  "featureImage": {
    "file": 123,
    "useParallax": false
  }
}
```

## Staging Preview URL

```
https://www.dev.telnyx.com/resources/{slug}
```

Always share this after saving. Do not publish to prod until Max reviews and approves.

## Revalidate Cache (ONLY with explicit approval — separate from publish approval)

After publishing, the live site still serves the cached version. Revalidation pushes the update to the live site.

**This is a separate approval step. Do not revalidate just because Max approved publishing. Ask again: "Published. Ready to revalidate and push live?"**

Revalidation is just a cache bust — no data changes happen here. `modifiedDate` was already set during the publish step above.

```bash
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
- **Updated entries** -> `memory/pages-updated.md`
- **Patterns learned** -> `memory/learnings.md`
