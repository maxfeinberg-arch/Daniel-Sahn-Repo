# Contentful Update Schema

When updating Contentful entries, you **must read the full entry first** to get:
1. The current `version` (required for the `X-Contentful-Version` header)
2. All existing `fields` (PUT replaces the entire fields object — omitted fields are erased)

**Do not begin updating until you know which entry to modify and what changes to make.**

---

## Updateable Fields by Content Type

### pageProduct / pageSolution / pageUseCase

```json
{
  "entry_id": "EXISTING_ENTRY_ID",
  "changes": {
    "title": "Updated page title",
    "seo.title": "Updated SEO Title | Telnyx",
    "seo.description": "Updated meta description (~155 chars).",
    "hero.copy": "Updated hero body copy.",
    "hero.ctaButtons": [
      { "label": "New CTA", "url": "/new-path" }
    ],
    "sections": ["add or reorder section entry IDs"]
  }
}
```

### sectionHero / sectionAbout / sectionCtaBanner / sectionFeatureList

```json
{
  "entry_id": "EXISTING_ENTRY_ID",
  "changes": {
    "title": "Updated internal title",
    "heading": "Updated heading text",
    "copy": "Updated body copy",
    "ctaButtons": [
      { "label": "Updated CTA", "url": "/updated-path" }
    ],
    "media_asset_id": "new-asset-id",
    "backgroundColor": "white"
  }
}
```

### moduleCta

```json
{
  "entry_id": "EXISTING_ENTRY_ID",
  "changes": {
    "label": "Updated button text",
    "url": "/updated-path",
    "type": "button"
  }
}
```

---

## Field Rules

| Field | Rule |
|---|---|
| `slug` | **NEVER change** — this is a human-only decision. Do not touch under any circumstances. |
| `seo.title` | Format: `{Page Title} \| Telnyx` |
| `seo.description` | ~155 chars, keyword-intentional |
| `hero.ctaButtons` | Minimum 1 required for heroProduct |
| `media_asset_id` | Must be a published Contentful asset ID |
| `backgroundColor` | Accepted values: `white`, `black`, `tan`, `gray` (confirm with Max) |
| `sections` | Array of entry IDs — reordering changes page layout |

## Read-Merge-Write Pattern (CRITICAL)

Every update follows this pattern:

1. **Read** the full entry (GET) — capture `version` and all `fields`
2. **Merge** your changes into the existing `fields` object — only modify fields you were asked to change
3. **Write** the complete `fields` object back (PUT with `X-Contentful-Version`)

**If you skip the merge step, you will erase all fields you didn't include.** This is the most common mistake.

## Before You Start

- Confirm the entry ID exists (GET it first)
- Confirm which fields to change with the user
- Never change fields you weren't asked to change
- If the entry is already published, your update creates a new draft — inform Max and ask if he wants to re-publish
