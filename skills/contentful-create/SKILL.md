---
name: contentful-create
description: Create new entries in Telnyx's Contentful CMS (Rebrand-2022 space). Use when creating new pages, sections, media, or CTA entries from scratch.
---

# Contentful Create Skill

## Configuration

```
Space: Rebrand-2022
Space ID: 2vm221913gep
Environment: master
API Base: https://api.contentful.com/spaces/2vm221913gep/environments/master
Upload Base: https://upload.contentful.com/spaces/2vm221913gep
Staging Base: https://www.dev.telnyx.com
```

**Tokens:**
- Content Management API (write/publish): `CFPAT-YOUR_CMA_TOKEN_HERE`
- Content Delivery API (read): `YOUR_CDA_TOKEN_HERE`
- Content Preview API (read): `YOUR_CPA_TOKEN_HERE`

## ⚠️ Token Note

Delivery and Preview tokens are **
read-only**. All write operations require the CMA token (`CFPAT-...`).

## Input Requirement

**Do not begin until a complete JSON input block is provided.**
See `INPUT_SCHEMA.md` (same directory) for required fields per page type.
If the user asks what fields are needed, return the relevant template from INPUT_SCHEMA.md.

## Workflow

1. **Receive JSON input** — validate all required fields are present before touching the API
2. **Draft first** — create entries with draft state (no publish call)
3. **Share link** — `https://app.contentful.com/spaces/2vm221913gep/entries/{ENTRY_ID}`
4. **Share staging preview** — `https://www.dev.telnyx.com/{path}/{slug}`
5. **Wait for approval #1** — get Max's explicit approval before publishing
6. **Publish** — publish the entry in Contentful
7. **Wait for approval #2** — get Max's explicit approval before revalidating
8. **Revalidate** — trigger cache revalidation so the live site reflects the change
9. **Never overwrite** existing entries — use contentful-update for edits

---

## API Patterns

### Inspect Content Type Schema
```bash
curl -s "https://api.contentful.com/spaces/2vm221913gep/environments/master/content_types/{TYPE_ID}" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" | python3 -c "
import sys, json
ct = json.load(sys.stdin)
for f in ct['fields']:
    print(f['id'], '|', f['name'], '|', f['type'], '| required:', f.get('required', False))
"
```

### Create Entry (Draft)
```bash
curl -s -X POST "https://api.contentful.com/spaces/2vm221913gep/environments/master/entries" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" \
  -H "Content-Type: application/vnd.contentful.management.v1+json" \
  -H "X-Contentful-Content-Type: {CONTENT_TYPE}" \
  -d '{
    "fields": {
      "title": {"en-US": "My Title"},
      "slug": {"en-US": "my-slug"}
    }
  }'
```

### Publish Entry (ONLY with explicit approval)
```bash
VERSION=$(curl -s "https://api.contentful.com/spaces/2vm221913gep/environments/master/entries/{ENTRY_ID}" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" | python3 -c "import sys,json; print(json.load(sys.stdin)['sys']['version'])")

curl -s -X PUT "https://api.contentful.com/spaces/2vm221913gep/environments/master/entries/{ENTRY_ID}/published" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" \
  -H "X-Contentful-Version: $VERSION"
```

### Upload Asset
```bash
# Step 1: Upload binary
UPLOAD_ID=$(curl -s -X POST "https://upload.contentful.com/spaces/2vm221913gep/uploads" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @/path/to/file | python3 -c "import sys,json; print(json.load(sys.stdin)['sys']['id'])")

# Step 2: Create asset entry
ASSET_ID=$(curl -s -X POST "https://api.contentful.com/spaces/2vm221913gep/environments/master/assets" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" \
  -H "Content-Type: application/vnd.contentful.management.v1+json" \
  -d "{\"fields\":{\"title\":{\"en-US\":\"My Asset\"},\"file\":{\"en-US\":{\"contentType\":\"image/png\",\"fileName\":\"file.png\",\"uploadFrom\":{\"sys\":{\"type\":\"Link\",\"linkType\":\"Upload\",\"id\":\"$UPLOAD_ID\"}}}}}}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['sys']['id'])")

# Step 3: Process (fetch version first)
ASSET_VERSION=$(curl -s "https://api.contentful.com/spaces/2vm221913gep/environments/master/assets/$ASSET_ID" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" | python3 -c "import sys,json; print(json.load(sys.stdin)['sys']['version'])")

curl -s -X PUT "https://api.contentful.com/spaces/2vm221913gep/environments/master/assets/$ASSET_ID/files/en-US/process" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" \
  -H "X-Contentful-Version: $ASSET_VERSION"

# Step 4: Publish asset (required before it can be linked to entries)
sleep 2  # wait for processing to complete

ASSET_VERSION=$(curl -s "https://api.contentful.com/spaces/2vm221913gep/environments/master/assets/$ASSET_ID" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" | python3 -c "import sys,json; print(json.load(sys.stdin)['sys']['version'])")

curl -s -X PUT "https://api.contentful.com/spaces/2vm221913gep/environments/master/assets/$ASSET_ID/published" \
  -H "Authorization: Bearer CFPAT-YOUR_CMA_TOKEN_HERE" \
  -H "X-Contentful-Version: $ASSET_VERSION"
```

## Field Localization

All fields must be wrapped in locale:
```json
{"title": {"en-US": "My Title"}}
```

## Linking Entries / Assets
```json
{"sections": {"en-US": [{"sys": {"type": "Link", "linkType": "Entry", "id": "ENTRY_ID"}}]}}
{"media": {"en-US": {"sys": {"type": "Link", "linkType": "Asset", "id": "ASSET_ID"}}}}
```

## Common Content Types

| Content Type ID | Use For |
|----------------|---------|
| `pageSolution` | Solution pages (/solutions/...) |
| `pageProduct` | Product pages (/products/...) |
| `sectionHero` | Hero section |
| `sectionTabs` | Tabbed carousel |
| `sectionAbout` | Text + image sections |
| `sectionCtaBanner` | CTA banner sections |
| `sectionFeatureList` | Feature bullet lists |
| `widgetTabContent` | Individual tab items |
| `moduleMedia` | Media entries |
| `moduleCta` | CTA buttons |

## Staging Preview URL

After creating a draft, share the staging link based on the page path:
```
https://www.dev.telnyx.com/solutions/{slug}
https://www.dev.telnyx.com/products/{slug}
https://www.dev.telnyx.com/blog/{slug}
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
- **404** — Entry, asset, or content type not found. Verify the ID exists.
- **409** — Version conflict. Re-fetch the entry to get the latest version and retry.
- **422** — Validation error. Check required fields, field types, and link targets. The response body contains details.
- **429** — Rate limited. Wait and retry.

Always report the full error response to the user before retrying.

## Memory

Create the `memory/` directory if it doesn't exist, then append to:
- **New entries created** → `memory/pages-created.md`
- **Patterns learned** → `memory/learnings.md`
