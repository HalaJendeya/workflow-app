// Render-check fallback when no Android emulator exists.
// Usage: node web_render.mjs <build/web dir> <out dir> [route ...]
// Serves the mock-mode web build and screenshots each route at the
// phone viewports used by test/helpers/viewport.dart.
import { createServer } from 'node:http';
import { readFile, mkdir } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const [root, out, ...routes] = process.argv.slice(2);
if (!root || !out) { console.error('usage: web_render.mjs <build/web> <out> [route...]'); process.exit(64); }
const viewports = { small: [320, 640], compact: [360, 740], standard: [390, 844], large: [430, 932] };
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.ttf': 'font/ttf', '.otf': 'font/otf' };

const server = createServer(async (req, res) => {
  const path = normalize(decodeURIComponent(req.url.split('?')[0])).replace(/^(\.\.[/\\])+/, '');
  for (const p of [join(root, path), join(root, 'index.html')]) {
    try { const body = await readFile(p); res.writeHead(200, { 'content-type': types[extname(p)] ?? 'application/octet-stream' }); return res.end(body); } catch {}
  }
  res.writeHead(404); res.end();
}).listen(0);
const port = server.address().port;
await mkdir(out, { recursive: true });
const browser = await chromium.launch();
let failures = 0;
for (const route of routes.length ? routes : ['/']) {
  for (const [name, [w, h]] of Object.entries(viewports)) {
    const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    page.on('console', m => m.type() === 'error' && errors.push(m.text()));
    await page.goto(`http://127.0.0.1:${port}/#${route}`);
    await page.waitForSelector('flt-glass-pane, flutter-view', { timeout: 60000 });
    await page.waitForTimeout(4000);
    const file = join(out, `${route.replace(/\W+/g, '_').replace(/^_+|_+$/g, '') || 'root'}_${name}.png`);
    await page.screenshot({ path: file });
    console.log(`${errors.length ? 'ERR ' : 'ok  '}${file}${errors.length ? '  ' + errors.join(' | ') : ''}`);
    failures += errors.length ? 1 : 0;
    await page.close();
  }
}
await browser.close(); server.close();
process.exit(failures ? 1 : 0);
