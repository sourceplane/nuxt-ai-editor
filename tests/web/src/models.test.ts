import { generateText } from "ai";
import { afterEach, describe, expect, it } from "vitest";
import { completionModel, gatewayConfigured, GATEWAY_MODEL, WORKERS_AI_MODEL } from "@/server/utils/models";

// server/utils/models.ts: every completion and rewrite runs on Workers AI
// through the Worker's AI binding unless its owner has set the AI Gateway's
// key; with the key, upstream's own gateway model and options are used.
type Event = Parameters<typeof completionModel>[0];
function eventWith(env: Record<string, unknown>): Event {
  return { context: { cloudflare: { env } } } as unknown as Event;
}

afterEach(() => {
  delete process.env.AI_GATEWAY_API_KEY;
});

describe("without the AI Gateway's key", () => {
  it("runs the completion on Workers AI through the request's binding, with no key", async () => {
    expect(gatewayConfigured()).toBe(false);
    const calls: { model: string; inputs: Record<string, unknown> }[] = [];
    const AI = {
      async run(model: string, inputs: Record<string, unknown>) {
        calls.push({ model, inputs });
        return { response: "jumps over the lazy dog.", usage: { prompt_tokens: 3, completion_tokens: 5, total_tokens: 8 } };
      },
    };
    const choice = completionModel(eventWith({ AI }));
    expect(choice.reasoning).toBeUndefined();
    const { text } = await generateText({ ...choice, prompt: "The quick brown fox" });
    expect(text).toBe("jumps over the lazy dog.");
    expect(calls).toHaveLength(1);
    expect(calls[0]?.model).toBe(WORKERS_AI_MODEL);
    // Reasoning off: an inline completion is one short sentence.
    expect(calls[0]?.inputs.chat_template_kwargs).toEqual({ enable_thinking: false });
  });

  it("uses a Workers AI model", () => {
    expect(WORKERS_AI_MODEL.startsWith("@cf/")).toBe(true);
  });

  it("fails plainly when the Worker has no AI binding", () => {
    expect(() => completionModel(eventWith({}))).toThrow(/AI binding is missing/);
  });
});

describe("with the AI Gateway's key", () => {
  it("sends the completion through the gateway with upstream's model and options, never the binding", () => {
    process.env.AI_GATEWAY_API_KEY = "an-owner-set-gateway-key";
    expect(gatewayConfigured()).toBe(true);
    let touched = false;
    const AI = { run: () => { touched = true; return {}; } };
    const choice = completionModel(eventWith({ AI }));
    expect(GATEWAY_MODEL).toBe("deepseek/deepseek-v4.1-flash");
    expect(typeof choice.model === "object" && choice.model.modelId).toBe(GATEWAY_MODEL);
    expect(choice.reasoning).toBe("none");
    expect(choice.providerOptions).toEqual({
      gateway: { order: ["baseten"], zeroDataRetention: true, disallowPromptTraining: true },
    });
    expect(touched).toBe(false);
  });
});
