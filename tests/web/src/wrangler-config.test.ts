import { readFileSync } from "node:fs";
import * as path from "node:path";
import { describe, expect, it } from "vitest";

// apps/web/wrangler.template.jsonc (and its committed fixture render,
// wrangler.jsonc): the Worker is Nitro's output, and it binds what the app
// reads — the R2 bucket as BLOB (NuxtHub's driver) and Workers AI as AI — and
// never carries a secret as a plain var.
const web = path.resolve(__dirname, "../../../apps/web");
const strip = (jsonc: string) => JSON.parse(jsonc.replace(/^\s*\/\/.*$/gm, "").replace(/\/\/[^"\n]*$/gm, ""));

for (const file of ["wrangler.template.jsonc", "wrangler.jsonc"]) {
  describe(`apps/web/${file}`, () => {
    const config = strip(readFileSync(path.join(web, file), "utf8"));

    it("deploys Nitro's Worker and its static assets", () => {
      expect(config.main).toBe("./.output/server/index.mjs");
      expect(config.assets).toEqual({ directory: "./.output/public", binding: "ASSETS" });
      expect(config.compatibility_flags).toContain("nodejs_compat");
    });

    it("binds R2 as BLOB and Workers AI as AI, and nothing else", () => {
      expect(config.r2_buckets.map((b: { binding: string }) => b.binding)).toEqual(["BLOB"]);
      expect(config.ai).toEqual({ binding: "AI" });
      for (const absent of ["d1_databases", "kv_namespaces", "durable_objects", "services", "hyperdrive"]) {
        expect(config[absent]).toBeUndefined();
      }
    });

    it("sets no secret as a var", () => {
      const vars = Object.keys(config.vars ?? {});
      expect(vars).not.toContain("AI_GATEWAY_API_KEY");
    });
  });
}

describe("the committed render", () => {
  it("names the stage fixture's bucket, and the template leaves it to the wiring", () => {
    const template = readFileSync(path.join(web, "wrangler.template.jsonc"), "utf8");
    const rendered = strip(readFileSync(path.join(web, "wrangler.jsonc"), "utf8"));
    const fixture = JSON.parse(readFileSync(path.join(web, "wiring.fixture.json"), "utf8"));
    expect(template).toContain("@@wiring(cloudflare-r2/__ENV__:r2_bucket_name)@@");
    expect(rendered.r2_buckets[0].bucket_name).toBe(fixture["cloudflare-r2/stage"].r2_bucket_name);
  });
});
