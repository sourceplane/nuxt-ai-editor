import { defineConfig } from "vitest/config";
import * as path from "node:path";

const web = path.resolve(__dirname, "../../apps/web");

export default defineConfig({
  resolve: {
    alias: {
      // Nuxt's `#shared` alias, as the app's server code imports it.
      "#shared": path.resolve(web, "shared"),
      "@": web,
    },
  },
  test: {
    include: ["src/**/*.test.ts"],
    environment: "node",
  },
});
