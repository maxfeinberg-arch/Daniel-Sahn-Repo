# AGENTS.md — website-update Agent

**Purpose:** Create and manage webpage content on telnyx.com via Contentful CMS.

## Structured JSON Input (REQUIRED)

**All page creation requires a complete JSON input block before any work begins.**
Do not start building entries based on prose descriptions. Ask for the JSON.

If the requester asks *"what fields do I need?"*, respond with the appropriate template from:
- Contentful: `skills/contentful-create/INPUT_SCHEMA.md` → pageProduct, pageSolution, pageUseCase
- Strapi: `skills/strapi-create/INPUT_SCHEMA.md` → rc-posts (/resources)

Required fields must all be present. If any are missing, ask — do not invent values.

## Workflow

1. Receive brief or doc
2. Ask clarifying questions (above)
3. Inspect reference pages if provided
4. Create entries in Contentful (DRAFT only)
5. Share Contentful link for review
6. Revise based on feedback
7. Publish ONLY when explicitly approved

## ⚠️ Critical Rules

1. **NEVER publish to production without explicit approval**
2. **NEVER create fake content** — use placeholders if info is missing
3. **NEVER upload copyrighted media** — user must provide assets
4. **ALWAYS create as draft first**
5. **ALWAYS share the Contentful link for review**

## Content Types (Rebrand-2022 Space)

| Type | Use For |
|------|---------|
| `pageSolution` | Solution pages (/solutions/...) |
| `pageBlogPost` | Blog posts |
| `sectionHero` | Page hero with headline, subhead, CTA |
| `sectionTabs` | Tabbed carousel (like Contact Center) |
| `sectionAbout` | Text + image/video section |
| `sectionCtaBanner` | CTA banner block |
| `sectionFeatureList` | Bullet feature list |
| `widgetTabContent` | Individual tab content |
| `moduleMedia` | Video/image entries |
| `moduleCta` | CTA buttons |

## CMS Routing — Which CMS Owns Which URLs

Before creating or editing any page, check this table first:

| URL Pattern | CMS | Skill File |
|-------------|-----|------------|
| `/resources/*` | **Strapi** | `skills/strapi/SKILL.md` |
| `/release-notes/*` | **Strapi** | `skills/strapi/SKILL.md` |
| `/products/*` | **Contentful** | `skills/contentful/SKILL.md` |
| `/use-cases/*` | **Contentful** | `skills/contentful/SKILL.md` |
| `/solutions/*` | **Contentful** | `skills/contentful/SKILL.md` |
| `/blog/*` | **Contentful** | `skills/contentful/SKILL.md` |

> ⚠️ This table is a work in progress. When in doubt, ask Max which CMS owns the URL.

## Configuration

```
Contentful Space: Rebrand-2022
Space ID: 2vm221913gep
Environment: master
API Base: https://api.contentful.com/spaces/2vm221913gep/environments/master
```

**Tokens:** stored in respective skill files (do not commit to git)
- Contentful: `skills/contentful/SKILL.md`
- Strapi: `skills/strapi/SKILL.md`

## Memory

- `memory/pages-created.md` — log of all created pages/entries
- `memory/learnings.md` — content patterns and feedback from reviews
