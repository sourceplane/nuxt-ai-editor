# nuxt-ai-editor — Vercel's Nuxt AI-powered Notion-like editor on Cloudflare

**The Nuxt UI editor template, kept as it is, on Cloudflare's own pieces:
Nitro's Workers preset for Vercel's hosting, NuxtHub's R2 driver for Vercel
Blob, Workers AI through the Worker's binding for the AI Gateway — so a fresh
editor completes and rewrites text with no key — and every icon bundled; and
the baseline that makes a copy of it somebody else's editor in one landing.**

| | |
|---|---|
| Status | In progress — NE1 on main: the site runs on Workers |
| Upstream | [nuxt-ui-templates/editor](https://github.com/nuxt-ui-templates/editor) (MIT), `main` at `c7bc6b6` (the repository has no tags) |
| Reference | [nuxt-ai-chatbot](https://github.com/sourceplane/nuxt-ai-chatbot) — the same template family on Workers: Nitro's preset, NuxtHub's R2 driver, Workers AI by default with the gateway's model on its key, the Workers AI stand-in; [blob-starter](https://github.com/sourceplane/blob-starter) — R2 |
| Key | `NE` |

## Read in this order

1. [design.md](design.md) — the template, how each Vercel piece maps to
   Cloudflare, the repository and the build, and the alternatives rejected.
2. [implementation-plan.md](implementation-plan.md) — the milestones.
3. [risks-and-open-questions.md](risks-and-open-questions.md) — what is not
   proven, and what was accepted.
4. [IMPLEMENTATION-STATUS.md](IMPLEMENTATION-STATUS.md) — what shipped, and
   every departure from the upstream template.

## Milestones

| Milestone | What it lands | Task |
|---|---|---|
| NE0 — the spec | the repository, its intent, CI, tooling and spec index; this doc set | NE-1 |
| NE1 — the editor on Workers and R2 | the template in `apps/web`, its AI on Workers AI, the R2 root, the tests | NE-2 |
| NE2 — a baseline | the console card, the build document, the context pack and the baseline's tests | NE-3 |
