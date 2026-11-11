# nuxt-ai-editor

A Notion-like editor — the [Nuxt UI editor template](https://github.com/nuxt-ui-templates/editor):
rich text with headings, lists, tables, task lists and code blocks, bubble
and fixed toolbars, a drag handle, slash commands, mentions, emoji, image
uploads, and AI inline completions and rewrites — as one Nuxt app on
**Cloudflare Workers + Static Assets** through Nitro's `cloudflare_module`
preset. The AI is **Workers AI**, through the Worker's own binding, so it
completes and rewrites text with no AI key. The images are in an **R2**
bucket provisioned by Terraform per environment.

## Live deployment

<!-- 02-docs:begin -->
Not recorded yet. The bootstrap's last phase writes the live URLs, the
workspace and the secrets the site uses into
[ai/context/deployment.md](ai/context/deployment.md); how the site deploys
and how to operate it is in
[ai/context/operations.md](ai/context/operations.md).
<!-- 02-docs:end -->

## What is here

| Surface | Where |
|---|---|
| The editor page, its toolbars, slash menu, drag handle, mentions and emoji | `apps/web/app/pages/index.vue`, `apps/web/app/composables` |
| The image upload node and the inline completion | `apps/web/app/components/editor` |
| The API: the streamed completion, the upload, the images served back | `apps/web/server/api`, `apps/web/server/routes/images` |
| Which model answers — Workers AI, or the AI Gateway once its key is set | `apps/web/server/utils/models.ts` |
| The site's name | `apps/web/shared/utils/site.ts` |
| Workers build, bindings and deploy contract | `apps/web/nuxt.config.ts`, `wrangler.template.jsonc` + `wiring.fixture.json` (→ `wrangler.jsonc`), `component.yaml` |
| The R2 bucket (stage, prod) | `infra/terraform/cloudflare-r2` |
| Tests | `tests/web` (vitest) |

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
pnpm --filter @app/web dev       # nuxt dev on http://localhost:3000, the bindings through wrangler's platform proxy
```

Workers AI has no local mode, so both reach it remotely: run `wrangler login`
first.

## The AI

Every inline completion and every toolbar rewrite — fix spelling and grammar,
extend, reduce, simplify, summarize, translate — runs on **Workers AI** (GLM
4.7 Flash, its reasoning off) through the Worker's `AI` binding, on the
Cloudflare account it deploys into: nothing to configure, and the account's
Workers AI usage is what it costs. The template's own model —
`deepseek/deepseek-v4.1-flash` through the [Vercel AI Gateway](https://vercel.com/docs/ai-gateway),
with its routing and data-retention options — is used instead once you give
it the gateway's key: store it as the product's Orun secret
`AI_GATEWAY_API_KEY` on each environment, then redeploy (below).

Both routes the editor writes through — the completion and the upload — are
public, as in the template: anybody who can open the page can use your
Workers AI and your bucket. Put the site behind Cloudflare Access, or add a
rate limit, before you share it widely.

## Images

An image dropped into the editor is uploaded to the environment's R2 bucket
(2 MB at most, images only) and served back by the Worker at
`/images/<name>` with a locked-down Content-Security-Policy. Its name ends in
a random suffix; anybody with the link can fetch it.

## Collaboration

Real-time collaboration is optional and off, as in the template. To turn it
on, deploy a [PartyKit](https://partykit.io) server (`npm create
partykit@latest`, `npx partykit deploy`), set the Worker variable
`NUXT_PUBLIC_PARTYKIT_HOST` to its host (dashboard → Workers & Pages →
`nuxt-ai-editor-web-<env>` → Settings → Variables), and open the editor with
`?room=<name>`: everyone on the same room edits together.

## Secrets

The AI Gateway's key is the one optional secret. It reaches the Worker as a
Worker secret: the deploy runs the build without it, then sets it on the
Worker (`tooling/wire/worker-secrets.mjs`), so no bundle carries it. A secret
you delete from Orun stays on the Worker until
`pnpm exec wrangler secret delete AI_GATEWAY_API_KEY --name nuxt-ai-editor-web-<env>`
(from `apps/web`) removes it there.

## How it deploys

Merges to `main` converge through [Orun](https://github.com/sourceplane/orun):
`.github/workflows/ci.yml` plans the changed components and runs each lane
against the workspace in `intent.yaml`. Per environment, the R2 bucket
applies first, then the editor builds with that environment's bucket and
deploys — to `stage`, then to `prod` once stage has converged on the same
commit; `dev` only verifies. The Worker is `nuxt-ai-editor-web-<env>` on your
account's workers.dev subdomain, and every deploy is smoke-tested over HTTP:
the page with its CSRF token, and the image route answering from the bucket.
A pull request runs the same pipeline's verify lanes: the editor type-checked,
linted, tested, built and dry-deployed for each environment, the bucket
planned, nothing deployed. (A push to `main` applies, builds and deploys.)

The pipeline holds one credential, GitHub's own `GITHUB_TOKEN`. The
Cloudflare tokens (one to deploy, one scoped to R2) and the account id are
brokered per run from the workspace's Cloudflare connection, and the bucket
names travel as Orun secrets; nothing provider-shaped is stored in the
repository or in GitHub.

**Deploy by hand.** Orunbase's **Deploy** button on a component, or **Run
workflow** on the CI workflow in GitHub's Actions tab (on `main`), runs
`ci.yml` for the environment and components you pick, and each one deploys
exactly as a merge would deploy it. Leave the component blank to redeploy
every component in that environment, with nothing changed: after storing a
secret, say. A component with nothing to run in that environment (a test
suite in `prod`) is left out with a notice.

## Custom domain

The site answers on workers.dev from its first deploy. To serve it on your
own domain, add the domain to the Cloudflare account the site deploys into
and attach it to the Worker (dashboard → Workers & Pages →
`nuxt-ai-editor-web-prod` → Settings → Domains & Routes → Add → Custom
domain). The editor builds no absolute link of its own, so nothing else
changes.

The site was born with the reserved placeholder `nuxt-ai-editor.example.com`
where its domain goes: `BASE_DOMAIN` under each environment in `intent.yaml`.
Replace it with your domain, and land it with a change under `apps/web` so
the merge redeploys the site.

## Credits

The editor is the Nuxt UI editor template
([nuxt-ui-templates/editor](https://github.com/nuxt-ui-templates/editor), MIT —
`apps/web/LICENSE`), Vercel's Nuxt AI-powered Notion-like WYSIWYG editor. The
Workers AI stand-in its tests use follows
[sourceplane/nuxt-ai-chatbot](https://github.com/sourceplane/nuxt-ai-chatbot).
