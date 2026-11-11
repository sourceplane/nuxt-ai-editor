# nuxt-ai-editor — risks and open questions

| ID | Risk | State | Notes |
|---|---|---|---|
| NE-A | `baseline-v1` is not yet proven live | OPEN | Proven offline in Baseline CI: the offline bootstrap with the blueprint's own hooks, the lane's own steps in a staged job tree, the built Worker served by `wrangler dev` — completions and six rewrites streamed through a Workers AI stand-in, an image written to R2 and back, the owner's gateway key handed to the Worker |
| NE-B | A real Workers AI answer is not exercised offline | OPEN | Workers AI has no local mode; the stand-in answers the binding's shape. GLM 4.7 Flash with its reasoning off is nuxt-ai-chatbot's fast model; the first live build proves it completes |
| NE-C | `workers-ai-provider` is deprecated | WATCH | In favour of `agents/models/ai-sdk`'s `createAI`, built around the AI Gateway. It works on the binding; move when the replacement drives the binding without a gateway |
| NE-D | The template moves on `main` | ACCEPTED | The repository has no tags; this port is `main` at `c7bc6b6`, the lockfile seeded from upstream's, and a bump is a deliberate change |
| NE-E | The Worker is close to Workers Free's limit | WATCH | About 2.6 MiB gzipped (Shiki's grammars and TipTap are most of it), under the 3 MiB; the e2e refuses a Worker over it |
| NE-F | The completion and upload routes are public | ACCEPTED | As in the template: CSRF-checked, not signed in. They spend the account's Workers AI and fill its bucket; the product's README says to put Access or a rate limit in front before sharing it widely |
| NE-G | An invalid upload answers 500 | ACCEPTED | NuxtHub 0.10's `handleUpload` wraps every validation error ("File type is invalid", "File size must be less than 2MB") as a 500 "Storage error"; on Vercel too. The editor shows the message |
| NE-H | Icons not in the scanned bundle | WATCH | Every literal icon name in `app/` and `shared/` is bundled; a name built at runtime would fall back to Nuxt Icon's remote collections, a CDN fetch on the Worker |
| NE-I | nuxt-csurf's encryption secret is per build | ACCEPTED | Upstream's behaviour: generated at build, baked into the runtime config; CSRF tokens issued before a deploy stop validating after it |
| NE-J | AbortSignal over RPC in the e2e | ACCEPTED | The stream passes an AbortSignal to its model; the real binding takes it, and the e2e's stand-in is reached over RPC with `enable_abortsignal_rpc` set in the e2e's config only |
| NE-K | The server renders the editor's shell | ACCEPTED | Upstream mounts the editor behind `v-if="collaborationReady"`, true only in the browser; the server renders the head (title, Open Graph, CSRF token) and the shell |
| NE-L | The gateway path is unit-tested, not served | ACCEPTED | The gateway provider has no base-URL override from the environment, so a served test would call Vercel; `tests/web/src/models.test.ts` holds the choice and its options |
| NE-M | Collaboration is unexercised | WATCH | y-partykit is kept and off; an owner who sets `NUXT_PUBLIC_PARTYKIT_HOST` runs it as upstream does |
