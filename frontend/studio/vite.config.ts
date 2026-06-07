import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

// The Studio SPA — served by IRIS at /fhir-agent-studio/ in production (same base
// in dev so asset + API paths line up). Shares the design system + component
// library with the Clinical SPA via the @shared alias.
export default defineConfig({
  root: __dirname,
  base: "/fhir-agent-studio/",
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
      "@shared": path.resolve(__dirname, "../shared"),
    },
  },
  server: {
    port: 5173,
    proxy: {
      "/fhir-agent-studio/api": { target: "http://localhost:42773", changeOrigin: true },
      "/csp": { target: "http://localhost:42773", changeOrigin: true },
    },
  },
  build: {
    outDir: "../dist/studio",
    emptyOutDir: true,
  },
});
