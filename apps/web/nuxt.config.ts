// https://nuxt.com/docs/api/configuration/nuxt-config
//
// Vercel's hosting becomes Nitro's Cloudflare Workers preset: `nuxt build`
// emits .output/server/index.mjs — the Worker, which renders the page and
// answers the API — and .output/public, the static assets, both deployed by one
// `wrangler deploy` of the committed wrangler.jsonc.
//
// NuxtHub keeps the template's own `hub:blob` (the image uploads), with
// Cloudflare R2 through the Worker's `BLOB` binding in place of Vercel Blob;
// the template's `/images/<pathname>` route serves them back. The AI features
// run on Workers AI through the `AI` binding by default (server/utils/models.ts);
// the AI Gateway's model, as upstream names it, is used once its key is set.
export default defineNuxtConfig({
  modules: [
    '@nuxt/eslint',
    '@nuxt/ui',
    '@nuxthub/core',
    'nuxt-csurf'
  ],

  devtools: {
    enabled: true
  },

  css: ['~/assets/css/main.css'],

  ui: {
    experimental: {
      componentDetection: true
    }
  },

  runtimeConfig: {
    public: {
      partykitHost: ''
    }
  },

  compatibilityDate: '2026-06-30',

  nitro: {
    preset: 'cloudflare_module',
    cloudflare: {
      deployConfig: false,
      nodeCompat: true
    }
  },

  hub: {
    blob: {
      driver: 'cloudflare-r2',
      binding: 'BLOB'
    }
  },

  vite: {
    optimizeDeps: {
      include: [
        '@nuxt/ui > prosemirror-state',
        'yjs',
        'y-partykit/provider'
      ]
    }
  },

  hooks: {
    // NuxtHub turns Nitro's `deployConfig` on, which writes a wrangler.json
    // of its own into .output and a .wrangler/deploy redirect that wrangler
    // would follow instead of the committed wrangler.jsonc. The deploy config
    // is wrangler.jsonc (rendered from wrangler.template.jsonc), so it goes
    // back off once the modules have run.
    'nitro:config'(config) {
      config.cloudflare = { ...config.cloudflare, deployConfig: false }
    }
  },

  eslint: {
    config: {
      stylistic: {
        commaDangle: 'never',
        braceStyle: '1tbs'
      }
    }
  },

  // Every icon the app names — in its components and its composables (the
  // toolbars, the slash menu, the drag handle) — is bundled with it. On a
  // serverless host Nuxt Icon's server falls back to fetching a whole
  // collection (megabytes of JSON) from a CDN for an icon it lacks, which on a
  // Worker would spend a request's CPU budget; the bundle leaves that fallback
  // for a name only known at runtime.
  icon: {
    clientBundle: {
      scan: {
        globInclude: ['{app,shared}/**/*.{vue,ts}']
      }
    }
  }
})
