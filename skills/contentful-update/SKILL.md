---
name: contentful-update
description: Update and publish existing entries in Telnyx's Contentful CMS (Rebrand-2022 space). Use when editing, modifying, or publishing existing pages, sections, or assets.
---

# Contentful Update Skill

## Configuration

```
Space: Rebrand-2022
Space ID: 2vm221913gep
Environment: master
API Base: https://api.contentful.com/spaces/2vm221913gep/environments/master
Staging Base: https://www.dev.telnyx.com
```

**Tokens:**
- Content Management API (write/publish): `CFPAT-YOUR_CMA_TOKEN_HERE`
- Content Delivery API (read): `YOUR_CDA_TOKEN_HERE`
- Content Preview API (read): `YOUR_CPA_TOKEN_HERE`

## ⚠️ Rules

1. **Always read the full entry first** before updating — you need both the version AND all existing fields
2. **Never overwrite** fields you aren't explicitly asked to change — merge your changes into the full fields object
3. **Draft by default** — do not publish unless explicitly approved
4. **Share link** after every update — `https://app.contentful.com/spaces/2vm221913gep/entries/{ENTRY_ID}`
5. **Published entries** — if an entry is already published, your update creates a new draft. Inform Max and ask if he wants to re-publish.
6. **Two-step go-live** — publishing and revalidating are separate approval steps. After publishing, ask Max again before revalidating.

---

## API Patterns

### Get Entry (read current state + version)
```bash
curl -s "https://api.contentful.com/spaces/2vm221913gep/environments/master/entries/{ENTRY_ID}" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE"
```

### Search Entries by Content Type
```bash
curl -s "https://api.contentful.com/spaces/2vm221913gep/environments/master/entries?content_type={TYPE}&limit=10" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data['items']:
    print(item['sys']['id'], '|', item['fields'].get('title', {}).get('en-US', '(no title)'))
"
```

### Search Entry by Slug
```bash
curl -s "https://api.contentful.com/spaces/2vm221913gep/environments/master/entries?content_type={TYPE}&fields.slug={SLUG}&limit=1" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if data['total'] == 0:
    print('NOT FOUND')
else:
    item = data['items'][0]
    print('Entry ID:', item['sys']['id'])
    print('Version:', item['sys']['version'])
    print('Title:', item['fields'].get('title', {}).get('en-US', '(no title)'))
    print('Slug:', item['fields'].get('slug', {}).get('en-US', '(no slug)'))
"
```

### Update Entry (read-merge-write pattern)

**⚠️ CRITICAL: Contentful PUT replaces the ENTIRE `fields` object. If you only send the fields you want to change, all other fields will be erased. You MUST read all current fields, merge your changes, then send the complete fields object.**

```bash
# Step 1: Read the full entry (get version + all fields)
ENTRY=$(curl -s "https://api.contentful.com/spaces/2vm221913gep/environments/master/entries/{ENTRY_ID}" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE")

VERSION=$(echo "$ENTRY" | python3 -c "import sys,json; print(json.load(sys.stdin)['sys']['version'])")

# Step 2: Merge changes into existing fields (example: update title only)
UPDATED_FIELDS=$(echo "$ENTRY" | python3 -c "
import sys, json
entry = json.load(sys.stdin)
fields = entry['fields']

# Apply your changes here — only modify the fields you need to change
fields['title'] = {'en-US': 'Updated Title'}

print(json.dumps({'fields': fields}))
")

# Step 3: Write the full fields object back
curl -s -X PUT "https://api.contentful.com/spaces/2vm221913gep/environments/master/entries/{ENTRY_ID}" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" \
  -H "Content-Type: application/vnd.contentful.management.v1+json" \
  -H "X-Contentful-Version: $VERSION" \
  -d "$UPDATED_FIELDS"
```

### Publish Entry (ONLY with explicit approval)
```bash
VERSION=$(curl -s "https://api.contentful.com/spaces/2vm221913gep/environments/master/entries/{ENTRY_ID}" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['sys']['version'])")

curl -s -X PUT "https://api.contentful.com/spaces/2vm221913gep/environments/master/entries/{ENTRY_ID}/published" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" \
  -H "X-Contentful-Version: $VERSION"
```

### Unpublish Entry
```bash
VERSION=$(curl -s "https://api.contentful.com/spaces/2vm221913gep/environments/master/entries/{ENTRY_ID}" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['sys']['version'])")

curl -s -X DELETE "https://api.contentful.com/spaces/2vm221913gep/environments/master/entries/{ENTRY_ID}/published" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" \
  -H "X-Contentful-Version: $VERSION"
```

## Field Localization

All fields must be wrapped in locale:
```json
{"title": {"en-US": "Updated Title"}}
```

## Staging Preview URL

After saving a draft, share the staging link based on the page path:
```
https://www.dev.telnyx.com/solutions/{slug}
https://www.dev.telnyx.com/products/{slug}
https://www.dev.telnyx.com/use-cases/{slug}
https://www.dev.telnyx.com/{path}/{slug}
```
Always share this link for review. Do not publish to prod until Max explicitly approves.

## Revalidate Cache (ONLY with explicit approval — separate from publish approval)

After publishing, the live site still serves the cached version. Revalidation pushes the update to the live site.

**⚠️ This is a separate approval step. Do not revalidate just because Max approved publishing. Ask again: "Published. Ready to revalidate and push live?"**

```bash
# Revalidate a specific page path (no auth required)
curl -s -X POST "https://telnyx.com/api/revalidate?path=/{page_path}/{slug}" \
  -H "Content-Type: application/json" -d ''
```

**Path examples:**
```bash
# Solutions page
curl -s -X POST "https://telnyx.com/api/revalidate?path=/solutions/my-solution" -H "Content-Type: application/json" -d ''

# Products page
curl -s -X POST "https://telnyx.com/api/revalidate?path=/products/my-product" -H "Content-Type: application/json" -d ''

# Use cases page
curl -s -X POST "https://telnyx.com/api/revalidate?path=/use-cases/my-use-case" -H "Content-Type: application/json" -d ''
```

## Error Handling

If the Contentful API returns an error:
- **400** — Malformed request. Check field names, locale wrapping, and JSON structure.
- **401** — Token is invalid or expired. Verify you are using the CMA token (`CFPAT-...`), not a delivery/preview token.
- **404** — Entry or content type not found. Verify the ID exists.
- **409** — Version conflict. Another edit happened since you read the entry. Re-fetch to get the latest version and retry.
- **422** — Validation error. Check required fields, field types, and link targets. The response body contains details.
- **429** — Rate limited. Wait and retry.

Always report the full error response to the user before retrying.

## Memory

Create the `memory/` directory if it doesn't exist, then append to:
- **Updated entries** → `memory/pages-updated.md`
- **Patterns learned** → `memory/learnings.md`
