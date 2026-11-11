import { createError } from 'nuxt/server'
import type { streamText } from 'ai'
import { gateway } from 'ai'
import { createWorkersAI } from 'workers-ai-provider'

// WHERE THE COMPLETIONS COME FROM. Upstream sends every call through the
// Vercel AI Gateway, which needs a key nobody brokers. Here the default is
// Workers AI, through the Worker's own `AI` binding (wrangler.jsonc): it needs
// no key, so a fresh deployment completes and rewrites text with nothing
// configured. Upstream's own gateway model is used once its owner sets
// AI_GATEWAY_API_KEY as a Worker secret.

// Workers AI's fast model, its reasoning off: inline completions are one short
// sentence, and every toolbar action is a rewrite of the selection.
export const WORKERS_AI_MODEL = '@cf/zai-org/glm-4.7-flash'

// Upstream's model, as upstream names it, through the AI Gateway.
export const GATEWAY_MODEL = 'deepseek/deepseek-v4.1-flash'

export function gatewayConfigured(): boolean {
  return Boolean(process.env.AI_GATEWAY_API_KEY)
}

// What a route hands this: the request event, whose context carries the
// request's Cloudflare bindings under Nitro's cloudflare_module preset.
interface WithContext {
  context: object
}
type CloudflareContext = { cloudflare?: { env?: { AI?: unknown } } }

// The part of streamText's options that names the model.
export type CompletionModel = Pick<Parameters<typeof streamText>[0], 'model' | 'providerOptions' | 'reasoning'>

// The model and its provider options for one request: the gateway's with its
// key (upstream's routing and data-retention options, unchanged), Workers AI's
// otherwise. The binding is read per request — it lives on the request's
// Cloudflare context, not at module scope.
export function completionModel(event: WithContext): CompletionModel {
  if (gatewayConfigured()) {
    return {
      model: gateway(GATEWAY_MODEL),
      reasoning: 'none',
      providerOptions: {
        gateway: {
          order: ['baseten'],
          zeroDataRetention: true,
          disallowPromptTraining: true
        }
      }
    }
  }
  const ai = (event.context as CloudflareContext).cloudflare?.env?.AI
  if (!ai) {
    throw createError({
      statusCode: 500,
      statusMessage: 'AI binding missing',
      message: 'The AI binding is missing: wrangler.jsonc must declare "ai": { "binding": "AI" }'
    })
  }
  return {
    model: createWorkersAI({ binding: ai as Parameters<typeof createWorkersAI>[0]['binding'] })(WORKERS_AI_MODEL),
    providerOptions: { 'workers-ai': { chat_template_kwargs: { enable_thinking: false } } }
  }
}
