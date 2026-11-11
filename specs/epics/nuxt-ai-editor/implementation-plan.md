# nuxt-ai-editor — implementation plan

## NE0 — the spec (NE-1)

The repository is born: `intent.yaml` with the placeholder workspace
`ws_CHANGE_ME`, the three environments and the trigger bindings; `ci.yml`
byte for byte turso-starter's; the shared tooling; the spec index. Then this
doc set and the three task contracts.

## NE1 — the editor on Workers and R2 (NE-2)

- The template into `apps/web` at `c7bc6b6`; the lockfile seeded from
  upstream's own, every direct dependency pinned to its resolution.
- `nuxt.config.ts`: Nitro's `cloudflare_module` preset, `deployConfig` off,
  NuxtHub's `cloudflare-r2` driver, the icon bundle.
- `server/utils/models.ts` and the completion route on it: Workers AI by
  default, the gateway's model with its key.
- `wrangler.template.jsonc` (R2 as `BLOB`, Workers AI as `AI`), its fixture
  and the committed render; `infra/terraform/cloudflare-r2`.
- `tests/web`: the name seam, the model choice, the bindings.
- Proven under `wrangler dev`: the page, completions and rewrites through a
  Workers AI stand-in, an image to R2 and back.

## NE2 — a baseline (NE-3)

nuxt-ai-chatbot's machinery on this tree, without its database:
`blueprint.yaml` (three brokered keys, the subdomain read from the
connection, no domain asked), `repo-blueprint.yaml` (one landing, then the
record), `.baseline/` (identity, the product's README, task contracts), the
rename engine, the bootstrap helpers, the record hook, the context pack and
the tiers (contract, wiring, leak, placement with the product's own plan,
e2e serving the editor).
