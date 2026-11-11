# nuxt-ai-editor — decisions

The choices that shape this repository, one line each, with where the full
reasoning lives. Superseded decisions stay listed, marked, so the history
reads in order.

| # | Decision | Why | Source |
|---|---|---|---|
| 1 | The template from `main` at `c7bc6b6`, the lockfile seeded from upstream's own (its second YAML document, the root importer moved to `apps/web`), every direct dependency pinned to the version it resolves, plus `rolldown 1.2.15` | The repository has no tags; a fresh pnpm 10 resolution picks a nuxt 4.6.4 whose rolldown lacks `./utils`, and a second `@tiptap/core` that breaks the Link extension's commands | risk NE-D |
| 2 | Nitro's `cloudflare_module` preset; the committed `wrangler.jsonc` is the deploy config, so Nitro writes none (a `nitro:config` hook undoes NuxtHub's `deployConfig: true`) | One Worker + Static Assets, deployed the way every sibling deploys | `apps/web/nuxt.config.ts` |
| 3 | Workers AI (GLM 4.7 Flash, reasoning off) through the `AI` binding by default; upstream's gateway model and options only with `AI_GATEWAY_API_KEY` | A fresh editor completes text with no key; the gateway is not a composition Orun has — nuxt-ai-chatbot's choice | `apps/web/server/utils/models.ts` |
| 4 | NuxtHub's `cloudflare-r2` driver for Vercel Blob; images served back by the template's own `/images/<pathname>` | The template's `hub:blob` and its upload node stay as they are: the node already falls back to that route when an object has no URL | design.md |
| 5 | The AI Gateway's key is an optional Orun secret; the build runs without it and the deploy sets it on the Worker | No bundle carries a secret; the editor works before it is connected | `apps/web/component.yaml`, `tooling/wire/worker-secrets.mjs` |
| 6 | Collaboration (y-partykit) kept and off, as upstream ships it | No PartyKit server is a composition; the editor works standalone | risk NE-M |
| 7 | Every icon the editor names is bundled | Nuxt Icon's serverless fallback fetches whole collections from a CDN at render | risk NE-H |
| 8 | Three brokered keys in one reconcile: `workers-deploy`, `r2-data`, the account id | The deploy token cannot create buckets; Workers AI needs none | `repo-blueprint.yaml` |
| 9 | One landing (`01-product`) then the record (`02-docs`), each checked in the build box | turso-starter's shape: the plan carries the order (bucket, then Worker) | `docs/phases/README.md` |
| 10 | `ci.yml` plans nothing while `intent.yaml` names `ws_CHANGE_ME`; no Checks workflow; stack-tectonic 0.19.0 | As every sibling | `.github/workflows/ci.yml`, `intent.yaml` |
| 11 | The smoke reads `/images/<a name nobody uploaded>` and wants a 404 | A read-only check that only a bound bucket can pass (without `BLOB` the route answers 500); no model is called | `apps/web/component.yaml` |
| 12 | Component docs are generated from the manifests and checked in CI | A hand-written copy drifts silently | `tooling/catalog/gen-component-docs.py` |
| 13 | `subdomain` is read from the Cloudflare connection, never asked; the console asks for no domain | Both belong to the account or the owner, not to the build | `blueprint.yaml` |
