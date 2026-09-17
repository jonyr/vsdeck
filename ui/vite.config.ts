import { defineConfig, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import { viteSingleFile } from 'vite-plugin-singlefile';

// Same policy as modules/deck/panel.html. Only added to the build: the dev
// server needs websocket and module requests that this policy blocks.
const CSP = "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'";

const contentSecurityPolicy = (): Plugin => ({
  name: 'deck-csp',
  apply: 'build',
  transformIndexHtml: () => [
    { tag: 'meta', attrs: { 'http-equiv': 'Content-Security-Policy', content: CSP }, injectTo: 'head-prepend' },
  ],
});

// Hammerspoon loads the panel as an HTML string with no base URL, so everything
// must be inlined into one file.
export default defineConfig({
  plugins: [react(), viteSingleFile(), contentSecurityPolicy()],
  build: { outDir: 'dist', emptyOutDir: true },
});
