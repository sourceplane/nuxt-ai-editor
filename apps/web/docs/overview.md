# web

The editor (the Nuxt UI editor template on Cloudflare Workers + Static Assets through Nitro's cloudflare_module preset, with R2 and Workers AI, per environment)

A Cloudflare Worker with Static Assets (server rendering plus static files), deployed per environment by its CI lane.

|              |                                                                                                                    |
| ------------ | ------------------------------------------------------------------------------------------------------------------ |
| Type         | `cloudflare-workers-assets-turbo`                                                                                  |
| Source       | `apps/web`                                                                                                         |
| Package      | `@app/web`                                                                                                         |
| Environments | `dev`: `verify` · `stage`: `verify`, `deploy` on a push to `main` · `prod`: `verify`, `deploy` on a push to `main` |

## Depends on

- **cloudflare-r2** — Provisions the Cloudflare R2 bucket the editor stores its uploaded images in (stage and prod)

## Depended on by

- (none)
