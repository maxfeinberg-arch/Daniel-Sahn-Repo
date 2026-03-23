# Contentful Input Schema

All Contentful page creation requires structured JSON input submitted upfront.
**Do not begin creating entries until all required fields are provided.**

> **Note:** There is no `pageBlogPost` content type in Contentful. Blog/article content lives in **Strapi** under `/resources/*`. Use the `strapi-create` skill for those.

---

## pageProduct — `/products/{slug}`

```json
{
  "page_type": "pageProduct",
  "slug": "my-product",
  "title": "My Product",
  "seo": {
    "title": "My Product | Telnyx",
    "description": "Meta description (recommended ~155 chars).",
    "canonical": "",
    "robots": "index, follow",
    "featuredImage_asset_id": ""
  },
  "hero": {
    "type": "heroProduct",
    "title": "Internal entry title",
    "tagline": "Short eyebrow text",
    "copy": "Hero body copy (required).",
    "ctaButtons": [
      { "label": "Get started", "url": "/sign-up" },
      { "label": "Talk to sales", "url": "/contact" }
    ],
    "media_asset_id": "",
    "backgroundColor": ""
  },
  "sections": [
    "List section entry IDs or describe sections to build (e.g. sectionAbout, sectionFeatureList, sectionCtaBanner)"
  ]
}
```

**Required:** `slug`, `seo.title`, `seo.description`, `hero.copy`, `hero.ctaButtons`

---

## pageSolution — `/solutions/{slug}`

```json
{
  "page_type": "pageSolution",
  "slug": "my-solution",
  "title": "My Solution",
  "seo": {
    "title": "My Solution | Telnyx",
    "description": "Meta description (recommended ~155 chars).",
    "canonical": "",
    "robots": "index, follow",
    "featuredImage_asset_id": ""
  },
  "hero": {
    "type": "heroSolutions",
    "title": "Internal entry title",
    "tagline": "Short eyebrow text",
    "heading": "Hero headline (required).",
    "subheading": "Supporting text below heading.",
    "ctaButtons": [
      { "label": "Get started", "url": "/sign-up" },
      { "label": "Talk to sales", "url": "/contact" }
    ],
    "media_asset_id": "",
    "backgroundColor": "white"
  },
  "sections": [
    "List section entry IDs or describe sections to build"
  ]
}
```

**Required:** `slug`, `seo.title`, `seo.description`, `hero.heading`, `hero.backgroundColor`

---

## pageUseCase — `/use-cases/{slug}`

```json
{
  "page_type": "pageUseCase",
  "slug": "my-use-case",
  "title": "My Use Case",
  "category": ["category-entry-id"],
  "seo": {
    "title": "My Use Case | Telnyx",
    "description": "Meta description (recommended ~155 chars).",
    "canonical": "",
    "robots": "index, follow",
    "featuredImage_asset_id": ""
  },
  "hero": {
    "type": "heroOverview",
    "title": "Internal entry title",
    "heading": "Hero headline (required).",
    "copy": "Supporting body copy.",
    "ctaButtons": [
      { "label": "Get started", "url": "/sign-up" }
    ],
    "media_asset_id": "",
    "backgroundColor": ""
  },
  "sections": [
    "List section entry IDs or describe sections to build"
  ],
  "sort": "",
  "industries": [],
  "department": []
}
```

**Required:** `slug`, `category`, `seo.title`, `seo.description`, `hero.heading`

---

## Field Notes

| Field | Notes |
|---|---|
| `slug` | Confirm with Max before creating — never change after publish |
| `seo.title` | Recommended format: `{Page Title} \| Telnyx` |
| `seo.description` | ~155 chars, keyword-intentional |
| `hero.type` | Verified content type IDs: `heroProduct` for /products, `heroSolutions` for /solutions, `heroOverview` for /use-cases. Also available: `heroDemo`, `heroForm`, `heroIndustries`, `heroNumberSearch` |
| `ctaButtons` | Minimum 1 required for heroProduct |
| `media_asset_id` | Contentful asset ID — must be uploaded separately |
| `sections` | Can be existing entry IDs or descriptions of sections to create |
| `backgroundColor` | Accepted values: `white`, `black`, `tan`, `gray` (confirm with Max) |

## If Fields Are Missing

If a required field is not provided, ask for it before proceeding. Do not invent placeholder values for slug, CTA links, or SEO copy.
