# nuxt-ai-editor — operating contract (for humans and agents)

This is the standing guide to how this editor is deployed and operated.
Instance facts (live URLs, workspace, the secrets it uses) live in
[deployment.md](deployment.md), rendered from probed reality by the
bootstrap's `02-docs` phase; this file is the contract that stays true
between deployments. It is written to give an agent with repository read
access enough context to reason about and operate the editor without any
other source.

## What this system is

A Notion-like AI editor — the Nuxt UI editor template — on Cloudflare
alone, expressed as an Orun component-native desired-state repo.

- **`infra/terraform/cloudflare-r2`** — one R2 bucket per deployed
  environment (`stage`, `prod`), where the uploaded images live, applied by
  Terraform. After each apply it publishes a wiring document —
  `{r2_bucket_name}` — as the Orun secret `WIRING_CLOUDFLARE_R2` on that
  environment.
- **`apps/web`** — the editor: Nuxt 4, Nuxt UI and TipTap, built by Nitro's
  `cloudflare_module` preset into one Worker plus Static Assets. The page's
  shell (and its CSRF token) renders per request and the editor itself in
  the browser; `/api/completion` streams an inline completion or a rewrite
  from Workers AI through the `AI` binding (`server/utils/models.ts`), or
  from the Vercel AI Gateway's model once `AI_GATEWAY_API_KEY` is set;
  `/api/upload` writes an image to R2 through the `BLOB` binding (NuxtHub's
  `hub:blob`), served back at `/images/<pathname>`. Real-time collaboration
  (PartyKit) is off unless `NUXT_PUBLIC_PARTYKIT_HOST` is set.
- **`tests/web`** — the site's name, the model and its provider, and the
  Worker's bindings (vitest), verified on the `dev` rung.
- **`tooling/*`** — shared TypeScript and ESLint configuration, the wrangler
  renderer that turns `wrangler.template.jsonc` plus the wiring document into
  `wrangler.jsonc`, and the hand-off of the owner's secret to the Worker
  (`tooling/wire/worker-secrets.mjs`).

Environments: **`stage`** and **`prod`** are deployed; **`dev` is
verify-only by design** — lanes build and test, nothing deploys, and no
bucket exists for it (its build renders the committed fixture).

## Identity and tenancy

Every remote operation runs against ONE Orun workspace, declared in
`intent.yaml` under `execution.state.workspace` — committed, enforced, and
what CI uses. Do not remove it; headless credentials depend on it. If it
reads `ws_SET_ME`, the bootstrap had no workspace to write: set the real one
before anything else.

## How deployment works

1. Merge (or push) to `main`.
2. CI (`.github/workflows/ci.yml`) runs `orun plan --changed` — only
   components whose files changed are planned — then runs each planned lane
   with `orun run --remote-state`, authenticated by GitHub OIDC (the
   exchange resolves this repository's linked workspace server-side).
3. **The bucket, then the Worker**, per environment. `cloudflare-r2` applies
   and publishes its wiring document. `apps/web` declares an enforced
   `dependsOn` on `cloudflare-r2` for pushes to `main`, so it starts after
   that apply — a job resolves its secrets when it starts, so the document is
   there.
4. `apps/web` renders `wrangler.jsonc` from that document (the real bucket
   name), builds with `nuxt build` — without the owner's optional secret in
   its environment — then sets it on the Worker as a secret if the
   environment has it (`wrangler secret bulk`), `wrangler deploy` ships
   `nuxt-ai-editor-web-<env>`, and a smoke test fetches `/` (the page and its
   CSRF token) and `/images/<a name nobody uploaded>` (a 404 the R2 bucket
   answers).
5. `prod` deploys after `stage` has converged on the same commit
   (`environments.prod.promotion` in intent.yaml).
6. **The convergence run is the deployment.** A green run means every
   planned lane applied. Failed lanes are retried with
   `gh run rerun --failed`, which resumes the same execution.

On a pull request nothing applies or deploys: the R2 root plans, the editor
builds and dry-deploys, and the edge in step 3 is advisory.

Caveats that matter:

- A push that touches no component files plans zero lanes — that run is
  green and deployed nothing. Never treat "latest run green" as "site
  converged"; probe the URLs instead.
- A change to `intent.yaml`'s `environments` maps to no component and
  redeploys nothing on its own. Land it with a change under `apps/web`.
- `wrangler.jsonc` is generated. Edit `wrangler.template.jsonc`, run
  `pnpm run wire:fixture` and commit both; the deploy renders its own
  config from the template, so a stale committed render misleads local work.
- Storing or changing the owner's secret redeploys nothing: run a deploy
  (below) so the build hands it to the Worker. A secret deleted from Orun
  stays on the Worker until `wrangler secret delete` removes it there.
- `/api/completion` and `/api/upload` are open to anyone who can load the
  page (CSRF-checked, not signed in), as in the template: they spend the
  account's Workers AI and fill its bucket. Put the site behind Cloudflare
  Access or a rate limit before sharing it widely.

## Secrets model

- **Brokered provider secrets**, minted per run from the workspace's
  Cloudflare connection — no long-lived values at rest, nothing to rotate by
  hand:
  - `CLOUDFLARE_API_TOKEN` (`workers-deploy`: Workers Scripts) — the
    editor's deploy, and setting the owner's secret on the Worker;
  - `CLOUDFLARE_R2_TOKEN` (`r2-data`: R2) — the R2 root's apply; the deploy
    token cannot create buckets;
  - `CLOUDFLARE_ACCOUNT_ID` — a connection fact both bind.
- **Wiring**: `WIRING_CLOUDFLARE_R2` on `stage` and `prod`, written by the
  root's apply (lease-published), read by the Worker's build as
  `WIRING_CLOUDFLARE_R2_<ENV>`. It holds a name, not a credential.
- **Workers AI** needs no secret: the `AI` binding runs on the account the
  Worker deploys into, and its usage is that account's.
- **The owner's optional secret**, an Orun secret of the product on each
  environment, set on the Worker by the deploy: `AI_GATEWAY_API_KEY` — the
  Vercel AI Gateway, for the template's own model in place of Workers AI.
- nuxt-csurf's encryption secret is generated at build time and baked into
  the Worker's runtime config, as in the template: every deploy issues new
  CSRF tokens (an open editor's next write asks the page for a fresh one).
- Inspect by NAME only: `orun secrets list --org <ws> --project` and
  `--env stage|prod`. No tooling in this repository prints a secret value,
  and no document in `ai/context/` may contain one.

## Verifying the system

```bash
# the editor on each environment (also recorded, probed, in deployment.md);
# /images/<missing> answers 404 from the R2 bucket the Worker binds
curl -s -o /dev/null -w '%{http_code}\n' https://nuxt-ai-editor-web-stage.your-workers-subdomain.workers.dev/
curl -s -o /dev/null -w '%{http_code}\n' https://nuxt-ai-editor-web-prod.your-workers-subdomain.workers.dev/images/probe-missing.png

# the wiring the deploys read, and workspace readiness
orun secrets list --org <ws> --env stage && orun secrets list --org <ws> --env prod
orun integrations list --org <ws> --json && orun cloud check --org <ws>
```

## Common operations

| task | how |
|---|---|
| change the editor's code | `apps/web/app` (the page, the toolbars, the composables), `apps/web/server` (the API), its name `apps/web/shared/utils/site.ts`; merge |
| change the model | `apps/web/server/utils/models.ts` (the Workers AI model, the gateway's model and its options); merge |
| change what each AI action asks | `apps/web/server/api/completion.post.ts` (the instructions and token budget per mode); merge |
| connect the AI Gateway | `AI_GATEWAY_API_KEY` as an Orun secret on the environment, then deploy by hand |
| turn on collaboration | a PartyKit server, then the Worker variable `NUXT_PUBLIC_PARTYKIT_HOST` (dashboard → the Worker → Settings → Variables); open the editor with `?room=<name>` |
| deploy a change | merge to `main`; watch the run; failed lanes → `gh run rerun --failed` |
| deploy by hand | Orunbase's Deploy button, or `gh workflow run ci.yml --ref main -f environment=<env> [-f component=<a,b>]` — the named components (blank: every one) run in that environment as a merge runs them; started off `main` it is refused |
| redeploy without a change | edit the last line of `apps/web/component.yaml` (`# orun: redeploy <reason> <stamp>`) and merge — it is a deploy trigger, nothing reads it |
| list or remove uploaded images | `wrangler r2 object list <bucket>` / `wrangler r2 object delete <bucket>/<name>` (the bucket is in the environment's `WIRING_CLOUDFLARE_R2`) |
| remove the owner's secret | delete it from Orun, then `pnpm exec wrangler secret delete AI_GATEWAY_API_KEY --name nuxt-ai-editor-web-<env>` from `apps/web` |
| add a binding (D1, KV, another bucket) | a Terraform root under `infra/terraform/` that publishes `WIRING_<ROOT>`, a token in `wrangler.template.jsonc`, its fixture entry, the root in the build's `--components`, the `WIRING_<ROOT>_<ENV>` secretEnv and an enforced `dependsOn` on it in `apps/web/component.yaml` |
| serve a custom domain | attach it to the Worker in Cloudflare, then replace the placeholder `nuxt-ai-editor.example.com` in `intent.yaml`'s `BASE_DOMAIN` with it (README, "Custom domain") |
| headless credentials | `ORUN_TOKEN` (workspace-scoped) + `GITHUB_TOKEN` |

The deployment record is the bootstrap's `02-docs` phase. Re-running it (the
Orun console's Retry on that phase, or `orun new … --phase 02-docs`)
re-probes the URLs and re-renders [deployment.md](deployment.md); it is
idempotent.

## Evolution

The Worker is about 2.6 MiB gzipped, under Workers Free's 3 MiB: a change
that grows it past that (more Shiki languages, another editor extension)
needs Workers Paid, and the baseline's e2e refuses it before a tag.
Structural changes follow the same contract that deployed the editor: add a
component under `apps/`, `infra/` or `packages/` with a `component.yaml`,
land it as a pull request, and the convergence run applies it.
