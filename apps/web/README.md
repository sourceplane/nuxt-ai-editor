# apps/web — the editor

The Nuxt UI editor template ([nuxt-ui-templates/editor](https://github.com/nuxt-ui-templates/editor),
MIT — `LICENSE`): a Notion-like WYSIWYG editor with tables, task lists, code
blocks, slash commands, a drag handle, mentions, emoji, image uploads and AI
completions, built by Nuxt's Nitro (`cloudflare_module` preset) into one
Cloudflare Worker with Static Assets.

- `/` — the editor (rendered in the browser; the server renders its shell and
  the CSRF token); `/?room=<name>` — the same, with collaboration once a
  PartyKit host is set
- `/api/completion` — streams an inline completion or a rewrite of the
  selection (POST, CSRF-checked)
- `/api/upload` — an image to R2 (POST, CSRF-checked, 2 MB, images only);
  `/images/<pathname>` — an image served back

NuxtHub keeps the template's `hub:blob`: the images are the `BLOB` binding
(R2), rendered into `wrangler.jsonc` from `wrangler.template.jsonc`. The AI is
Workers AI through the `AI` binding (`server/utils/models.ts`); the
template's own model, through the Vercel AI Gateway, is used once
`AI_GATEWAY_API_KEY` is set. The site's name is `shared/utils/site.ts`.

```bash
pnpm build              # nuxt build → .output/ (the Worker and its static assets)
pnpm preview            # wrangler dev over the built Worker, on a local R2 bucket
pnpm dev                # nuxt dev on http://localhost:3000, the bindings through wrangler's platform proxy
```

Workers AI has no local mode: `pnpm dev` and `pnpm preview` reach it
remotely, so run `wrangler login` first (`pnpm dev` cannot start its bindings
proxy without it).

How it is deployed — per environment, on merge to `main` — is the
repository's README and `component.yaml` beside this file.
