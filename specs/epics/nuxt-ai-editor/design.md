# nuxt-ai-editor — design

## The template

[nuxt-ui-templates/editor](https://github.com/nuxt-ui-templates/editor) at
`c7bc6b6` (2026-10-28), MIT: one Nuxt 4.6 page around Nuxt UI 4.12's
`UEditor` (TipTap 3.32) — headings, lists, blockquotes, code blocks with
Shiki, tables, task lists, bubble and fixed toolbars, a drag handle, slash
commands, `@mentions`, `:emoji:`, an image upload node, and AI: inline
completions (accepted with Tab) and toolbar rewrites (fix, extend, reduce,
simplify, summarize, translate) through the AI SDK's `useCompletion` and one
route, `server/api/completion.post.ts`. Images go up through NuxtHub's
`hub:blob` (`server/api/upload.post.ts`) and come back through
`server/routes/images/[...pathname].ts`. Real-time collaboration (Y.js over
PartyKit) is optional and off unless `NUXT_PUBLIC_PARTYKIT_HOST` is set.
Every write is CSRF-checked by `nuxt-csurf`.

## How each Vercel piece maps

| Vercel | Cloudflare | Notes |
|---|---|---|
| Nitro's Vercel preset | Nitro's `cloudflare_module` preset: one Worker + Static Assets, deployed by `wrangler deploy` of the committed `wrangler.jsonc` | NuxtHub forces `deployConfig: true`; a `nitro:config` hook turns it back off so the committed config is the one deployed |
| The Vercel AI Gateway (`deepseek/deepseek-v4.1-flash`) | Workers AI through the `AI` binding (`workers-ai-provider`, `@cf/zai-org/glm-4.7-flash`, reasoning off) | `server/utils/models.ts`; the gateway's model, with upstream's provider options, is used once `AI_GATEWAY_API_KEY` is set (an optional Orun secret, set on the Worker by the deploy) |
| Vercel Blob through NuxtHub | R2 through NuxtHub's `cloudflare-r2` driver, the `BLOB` binding | The upload node uses `result.url || /images/<pathname>`; an R2 object has no URL, so the template's own image route serves it, unchanged |
| A blob store made in the dashboard | `infra/terraform/cloudflare-r2`, applied before the Worker on every merge | Its wiring (`WIRING_CLOUDFLARE_R2`) is rendered into `wrangler.jsonc` by the build |
| Nuxt Icon's serverless fallback | Every icon the app names bundled (`icon.clientBundle.scan` over `app/` and `shared/`) | A CDN fetch per missing icon would spend a request's CPU on a Worker |

## The repository

`apps/web` (the app), `infra/terraform/cloudflare-r2` (the bucket per
environment), `tests/web` (vitest: the name seam, the model choice, the
bindings), `tooling/{tsconfig,eslint,wire}`. The baseline's own machinery —
the card, the build document, `.baseline/`, the rename engine, the bootstrap
helpers, the record hook, the tiers — is nuxt-ai-chatbot's, without its
database: there is no D1 root, no migrations and no session key, because the
editor stores nothing but images.

## The build

One landing (`01-product`) places everything and one convergence applies the
bucket, then deploys the Worker that binds it, per environment; `02-docs`
records what answered. The deploy's smoke reads the page (and its CSRF
token) and `/images/<a name nobody uploaded>`, which answers 404 only through
a bound bucket — read-only, no model called.

## Alternatives rejected

- **Keeping `@vercel/blob`** (NuxtHub's Vercel driver): a token nobody
  brokers, and a store outside the account the editor runs in.
- **Binding R2 directly** instead of NuxtHub's driver: the template's
  `hub:blob` imports would change; the driver works on NuxtHub 0.10.11 as
  nuxt-ai-chatbot proved.
- **A PartyKit server or a `y-partyserver` Durable Object for
  collaboration**: not in the template's default, and no composition for it;
  it stays optional, as upstream ships it.
- **Rewriting the upload route to answer 400 for an invalid file**: NuxtHub's
  `handleUpload` answers 500 with a clear message, as on Vercel; the editor
  shows the message, and the route stays the template's.
