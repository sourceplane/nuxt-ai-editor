# nuxt-ai-editor — open risks

What is not yet proven or not yet decided. The full write-up of every risk,
including the accepted and resolved ones, is
`specs/epics/nuxt-ai-editor/risks-and-open-questions.md`; this page lists
only what is still live, so it should be short.

| ID | Risk | State | What closes it |
|---|---|---|---|
| NE-A | `baseline-v1` is not yet proven live; it is proven offline in Baseline CI (the offline bootstrap, the lane's own steps, the editor served by `wrangler dev`: completions answered through a Workers AI stand-in, an image in R2, the owner's key connected) | OPEN | One console bootstrap from `baseline-v1` |
| NE-B | No real Workers AI answer offline — Workers AI has no local mode | OPEN | The live build's first completion |
| NE-C | `workers-ai-provider` is deprecated in favour of a gateway-centred `createAI` | WATCH | A replacement that drives the binding without a gateway |
| NE-E | The Worker is about 2.6 MiB gzipped, under Workers Free's 3 MiB with little room | WATCH | The e2e refuses a Worker over 3 MiB before a tag |
| NE-H | An icon name built at runtime would be fetched from a CDN by the Worker | WATCH | Keep icon names literal; the bundle scan covers `app/` and `shared/` |
| NE-M | Collaboration (PartyKit) is unexercised on this port | WATCH | Off by default; a PartyKit host set by an owner |

Accepted, and worth knowing before you change them: NE-D (the template from
`main`, pinned), NE-F (the completion and upload routes are public, as in
the template), NE-G (an invalid upload answers 500 with NuxtHub's message),
NE-I (nuxt-csurf's per-build secret), NE-J (the e2e's AbortSignal flag),
NE-K (the server renders the editor's shell; the editor needs JavaScript),
NE-L (the gateway path is unit-tested, not served).
