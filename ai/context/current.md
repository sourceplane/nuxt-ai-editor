# nuxt-ai-editor — where this repository stands

The entry page for anyone (or any agent) picking this repository up. It is
this repository's own state and does not ship to a site built from it; the
two pages that do are [operations.md](operations.md) and
[deployment.md](deployment.md).

## What it is

Vercel's Nuxt AI-powered Notion-like WYSIWYG editor (nuxt-ui-templates/editor)
— a Notion-like editor with tables, task lists, code blocks, slash commands,
a drag handle, mentions, emoji, image uploads and AI completions and
rewrites, one Nuxt app — built by Nitro into one Cloudflare Worker with
Static Assets, its AI on Workers AI through the Worker's own binding and its
images in an R2 bucket that Terraform provisions per environment, packaged as
an Orun baseline: `orun new --blueprint repo-blueprint.yaml` builds a new
editor in its own repository and takes it to live on stage and prod in one
landing (`01-product`), then records what went live (`02-docs`). Workers Free
is enough (the Worker is about 2.6 MiB gzipped).

## Release

| | |
|---|---|
| Latest tag | `baseline-v1` — NE0 to NE2: the repository, the editor on Workers with R2 and Workers AI, and the baseline (blueprint, phases, tests) |
| Proven live | Not yet: proven offline in Baseline CI only, a Workers AI stand-in answering the completions (risks NE-A, NE-B) |

## Where to read

| Question | Page |
|---|---|
| What shipped, and every departure from upstream | `specs/epics/nuxt-ai-editor/IMPLEMENTATION-STATUS.md` |
| Why it is built this way | [decisions.md](decisions.md), then `specs/epics/nuxt-ai-editor/design.md` |
| What could still go wrong | [open-risks.md](open-risks.md), then `specs/epics/nuxt-ai-editor/risks-and-open-questions.md` |
| How to instantiate it | `BOOTSTRAP.md`, `docs/phases/` |
| What the components are | each component's `docs/` (generated; `python3 tooling/catalog/gen-component-docs.py`) |

## Next

1. Bootstrap one editor from `baseline-v1` into a workspace with Cloudflare
   connected, accept an inline completion and run a toolbar rewrite on
   Workers AI, drop in an image, and record the timings against the
   7-minute estimate (closes NE-A and NE-B).
