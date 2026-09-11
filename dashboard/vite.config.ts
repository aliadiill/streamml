import {defineConfig} from "vite";

export default defineConfig(({mode}) => {
  const demo = mode === "pages";
  return {
    define: {"import.meta.env.VITE_DEMO_ONLY": JSON.stringify(demo ? "true" : "false")},
    plugins: demo ? [{
      name: "demo-network-policy",
      transformIndexHtml: () => [{
        tag: "meta",
        attrs: {"http-equiv": "Content-Security-Policy", content:
          "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'; object-src 'none'; base-uri 'self'; form-action 'none'"},
        injectTo: "head-prepend" as const,
      }],
    }] : [],
  };
});
