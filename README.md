# nuxt-ai-editor

Vercel's [Nuxt AI-powered Notion-like WYSIWYG editor](https://vercel.com/templates/nuxt/nuxt-ai-editor)
— the [Nuxt UI editor template](https://github.com/nuxt-ui-templates/editor):
a Notion-like editor with rich text, tables, task lists, code blocks, slash
commands, a drag handle, mentions, emoji and image uploads, plus AI inline
completions and rewrites — running on **Cloudflare Workers + Static Assets**
through Nitro's `cloudflare_module` preset, with its AI on **Workers AI**
through the Worker's own binding and its images in an **R2** bucket
provisioned by Terraform through [Orun](https://github.com/sourceplane/orun), deployed by
[Orun](https://github.com/sourceplane/orun) to stage and prod on every merge.
Packaging it as an Orun baseline is the next milestone (NE2). Workers Free is enough: the Worker is about 2.6 MiB
gzipped, under the plan's 3 MiB.

The template's code is the code. NuxtHub keeps its `hub:blob` with
Cloudflare's driver — R2 in place of Vercel Blob — and the port changes what
the Workers runtime and an unattended deployment force: the AI defaults to
Workers AI, so a fresh product completes and rewrites text with no model key
(the template's own AI Gateway model is used once its key is set, as in
[nuxt-ai-chatbot](https://github.com/sourceplane/nuxt-ai-chatbot)), and every
icon the editor names is bundled with it. Real-time collaboration stays off,
as upstream ships it. See
[`specs/epics/nuxt-ai-editor`](specs/epics/nuxt-ai-editor/README.md) for the
design, the milestones and the as-built status.

## What is here (the product)

| Surface | Where |
|---|---|
| The editor: its page, toolbars, slash menu, drag handle, mentions, emoji and the image upload node | `apps/web/app` |
| The API: the streamed completion, the upload and the images served back | `apps/web/server/api`, `apps/web/server/routes/images` |
| The model (Workers AI by default, the AI Gateway's with its key) | `apps/web/server/utils/models.ts` |
| The site's name | `apps/web/shared/utils/site.ts` |
| Workers build, bindings and deploy contract | `apps/web/nuxt.config.ts`, `wrangler.template.jsonc` + `wiring.fixture.json` (→ the committed `wrangler.jsonc`), `component.yaml` |
| The R2 bucket (stage, prod) | `infra/terraform/cloudflare-r2` |
| The wrangler renderer and the Worker-secret hand-off | `tooling/wire` |
| Tests | `tests/web` (the name, the model and its provider, the bindings) |

## Getting started

```bash
pnpm install
pnpm run wire:fixture   # render apps/web/wrangler.jsonc from the offline fixture
pnpm typecheck
pnpm lint
pnpm test
pnpm build              # nuxt build → apps/web/.output (the Worker and its static assets)
```

```bash
pnpm --filter @app/web preview   # wrangler dev over the built Worker, on a local R2 bucket
pnpm --filter @app/web dev       # nuxt dev — the bindings through wrangler's platform proxy
```

Workers AI has no local mode: both reach it remotely, so `wrangler login`
first.

## How it maps to Vercel

| Vercel-side | Here |
|---|---|
| Nuxt on Vercel (Nitro's Vercel preset) | One Cloudflare Worker (`.output/server/index.mjs`, Nitro's `cloudflare_module` preset) + Static Assets |
| The Vercel AI Gateway for every completion (`AI_GATEWAY_API_KEY`, `deepseek/deepseek-v4.1-flash`) | Workers AI through the Worker's `AI` binding by default (`workers-ai-provider`, GLM 4.7 Flash with its reasoning off); upstream's gateway model, with its routing and data-retention options, used only once `AI_GATEWAY_API_KEY` is set |
| Vercel Blob through NuxtHub (`BLOB_READ_WRITE_TOKEN`, a public URL per file) | Cloudflare R2 through NuxtHub's `cloudflare-r2` driver, the `BLOB` binding; an R2 object has no URL of its own, so images are served back by the template's own `/images/<pathname>` route (the upload node already falls back to it) |
| Icons fetched by Nuxt Icon's server on a serverless host | Every icon the editor names bundled with it |
| A blob store created in the dashboard | `infra/terraform/cloudflare-r2`, applied by Orun before the Worker |
| PartyKit collaboration (`NUXT_PUBLIC_PARTYKIT_HOST`, optional) | Unchanged and off by default: set the variable to a PartyKit host to turn it on |
| Deploy on push | Orun applies the bucket and deploys `<repo>-web-{stage,prod}` on merge to `main` |
| "Deploy with Vercel" (clone the template) | `orun new --blueprint repo-blueprint.yaml` — a new repository, branded, deployed |

## How the bucket reaches the Worker

```
infra/terraform/cloudflare-r2 ──apply──► orun secret WIRING_CLOUDFLARE_R2 (stage, prod)
                                               │
                                               ▼
apps/web  dependsOn cloudflare-r2 (enforced on main)
          · secretEnv WIRING_CLOUDFLARE_R2_<ENV>
          · optionalSecretEnv the owner's AI Gateway key
  build:  tooling/wire/live.mjs → wrangler.jsonc with the environment's bucket
          (dev, verify-only, renders the fixture) → nuxt build (without the optional secret)
          → tooling/wire/worker-secrets.mjs → `wrangler secret bulk` (deploy lanes only)
```

`wrangler.jsonc` is committed as the fixture render of
`wrangler.template.jsonc`, because the deploy lane's `verify-app-structure`
step checks the config exists before it builds; `testing/e2e.test.sh` fails
if the two disagree.

## CI

| Workflow | What it runs | Ships to a product |
|---|---|---|
| `ci.yml` | the Orun pipeline, and the only workflow a product carries: `orun plan --changed`, then one job per lane. A pull request runs the verify lanes (the editor type-checked, linted, tested, built and dry-deployed per environment, the R2 root planned), except the bootstrap's own landings (`orun/BASE-*`), where `plan` alone is the check; a merge applies the R2 bucket, then deploys stage → prod. It plans nothing while `intent.yaml` names the placeholder workspace `ws_CHANGE_ME`, as this repository does. A manual run (Orunbase's Deploy button, or Run workflow on `main`) plans the environment and components it names under the push-to-main trigger, so they deploy as a merge deploys them | yes |
