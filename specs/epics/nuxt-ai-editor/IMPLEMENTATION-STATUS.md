# nuxt-ai-editor — implementation status

| Milestone | State | Landed |
|---|---|---|
| NE0 — the spec | ✅ | NE-1 |
| NE1 — the editor on Workers and R2 | ✅ | NE-2 |
| NE2 — a baseline | planned | NE-3 |

## Departures from the upstream template

Everything not listed here is the template as it is on `main` at `c7bc6b6`.

| # | What | Why |
|---|---|---|
| 1 | The app lives in `apps/web` of a pnpm workspace on pnpm 10.12.1; upstream's `pnpm@12` pin, its `.github` CI, `renovate.json` and `.editorconfig` are not carried | The workspace's package manager; the product's CI is Orun's |
| 2 | The lockfile is upstream's own (its second YAML document — pnpm 10 refuses pnpm 12's leading one — with the root importer moved to `apps/web`), every direct dependency pinned to its resolution; `h3` 1.15.11 a direct dependency (upstream's override); `rolldown` 1.2.15 a dev dependency; upstream's `swrv` and `h3` overrides in pnpm 10's form | A fresh pnpm 10 resolution picked a nuxt 4.6.4 whose rolldown lacks `./utils`, and a second `@tiptap/core` (3.32.2) that lost the Link extension's commands |
| 3 | `@vercel/blob` removed | Vercel Blob is replaced by R2 |
| 4 | `nuxt.config.ts`: Nitro's `cloudflare_module` preset, `deployConfig` off (a `nitro:config` hook, since NuxtHub forces it on), NuxtHub's `cloudflare-r2` driver, and Nuxt Icon's client bundle scanned over `app/` and `shared/` | Workers and R2; icons rendered without a CDN fetch |
| 5 | `server/utils/models.ts` (new); `server/api/completion.post.ts` takes its model and options from it (Workers AI's GLM 4.7 Flash with reasoning off, or upstream's gateway model and options with `AI_GATEWAY_API_KEY`) — the instructions and budgets per mode are upstream's | Workers AI by default |
| 6 | `shared/utils/site.ts` (`SITE_NAME`) is the page and Open Graph title (upstream: "Nuxt Editor Template") | One rename seam |
| 7 | The header's GitHub button links to the site's own repository (upstream: nuxt-ui-templates/editor) | The product's own source |
