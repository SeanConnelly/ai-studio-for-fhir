import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

// The Clinical SPA — a clinician-facing mini-EHR served by IRIS at /clinical/.
// Shares the design system + CC component library with the Studio via @shared.
export default defineConfig({
  root: __dirname,
  base: "/clinical/",
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
      "@shared": path.resolve(__dirname, "../shared"),
    },
  },
  server: {
    port: 5174,
    proxy: {
      "/fhir-agent-studio/api": { target: "http://localhost:42773", changeOrigin: true },
      "/csp": { target: "http://localhost:42773", changeOrigin: true },
    },
  },
  build: {
    outDir: "../dist/clinical",
    emptyOutDir: true,
  },
});
