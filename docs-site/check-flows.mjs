import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const here = dirname(fileURLToPath(import.meta.url));
const sandbox = { window: {} };
vm.createContext(sandbox);
for (const f of ['data/site-data.js', 'js/flows.js']) vm.runInContext(readFileSync(join(here, f), 'utf8'), sandbox);
const { SITE_DATA: data, FLOWS: flows } = sandbox.window;

const commands = new Set(data.commands.map((c) => c.name));
const known = new Set([...commands, ...data.skills.map((s) => s.name), ...data.agents.map((a) => a.name), ...data.plugins.map((p) => p.name), 'bossdream-hooks']);
const text = flows.flatMap((f) => [f.title, f.tagline, ...f.entra, ...f.llama, ...f.sale, f.mermaid]).join('\n');

const missing = [
  ...[...text.matchAll(/(?<![\w./])\/(bossdream-[a-z]+(?:-[a-z]+)*)(?![\w/-])/g)].map((m) => m[1]).filter((n) => !commands.has(n)),
  ...[...text.matchAll(/(?<![\w./-])(bossdream-[a-z]+(?:-[a-z]+)*)(?![\w/-])/g)].map((m) => m[1]).filter((n) => !known.has(n))
];

if (missing.length) {
  console.error(`flows.js nombra elementos que ya no existen: ${[...new Set(missing)].join(', ')}`);
  process.exit(1);
}
console.log(`flows.js consistente con ${commands.size} comandos, ${data.skills.length} skills y ${data.agents.length} agentes`);
