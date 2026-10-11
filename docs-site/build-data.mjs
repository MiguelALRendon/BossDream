import { readFileSync, readdirSync, statSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..');
const core = join(repo, 'plugins', 'bossdream-core');

const GROUPS = {
  agents: {
    'Implementación': ['bossdream-coder'],
    'Auditoría de código': ['bossdream-solid-auditor', 'bossdream-design-auditor', 'bossdream-endless-verifier', 'bossdream-evidence-auditor', 'bossdream-traceability-watcher', 'bossdream-scope-enforcer'],
    'Plan': ['bossdream-planner-auditor', 'bossdream-assumption-breaker', 'bossdream-flow-breaker', 'bossdream-completeness-auditor', 'bossdream-document-explorer'],
    'Pruebas y QA': ['bossdream-qa-auditor', 'bossdream-qa-gatekeeper', 'bossdream-qa-planner', 'bossdream-smoker'],
    'Documentos': ['bossdream-document-auditor']
  },
  skills: {
    'Ciclo de entrega': ['bossdream', 'brainstorming', 'ctx', 'arch', 'plan-new', 'plan-checks', 'execution-checks', 'context-router', 'repo-map'],
    'Pruebas y QA': ['test-gen', 'test-checks', 'gherkin-gen', 'qa-run', 'qa-increment', 'bossdream-qa-planner', 'flow-test-gen'],
    'Calidad': ['pipeline', 'rules-comentarios', 'theme-first', 'tech-debt', 'sobriety-audit'],
    'Documentación': ['docs-rewrite', 'adr-new', 'skill-exploration'],
    'Gobernanza de negocio': ['epic-planner', 'validation-run', 'validation-exemption-advisor', 'traceability-sync']
  },
  commands: {
    'Arranque': ['bossdream-init', 'bossdream-new', 'helpers', 'bossdream-sync', 'bossdream-sync-models'],
    'Ciclo de entrega': ['bossdream-plan', 'bossdream-implement', 'bossdream-mode', 'bossdream-qa-mode'],
    'Gobernanza de negocio': ['bossdream-project', 'bossdream-validate', 'bossdream-testcase', 'bossdream-update-docs', 'bossdream-set-active-project', 'bossdream-report', 'bossdream-override'],
    'Mantenimiento': ['bossdream-skill-exploration', 'bossdream-learning-review']
  }
};

const TEMPLATE_NOTES = {
  'CLAUDE.md': 'Instrucciones del agente: ciclo requerido, comentarios, stack.',
  'bossdream.json': 'plan-lock, extensiones de código, pruebas, estilos, QA y ruteo de modelos.',
  'completion.json': 'Gates del Completion Criteria y tope de reintentos.',
  'pipeline.json': 'Etapas agnósticas del pipeline (theme-check, gherkin, docdrift).',
  'settings.hooks-snippet.json': 'Hooks de gobernanza que se fusionan en settings.json.',
  'validation-rules.json': 'Reglas del Document Validation.',
  'validation.json': 'Estado inicial del gate de validación (blocked).',
  'traceability.json': 'Grafo REQ → Epic → Feature → US → AC → TC.',
  'plan-progress.json': 'Avance de un plan por increments.',
  'project.json': 'Metadatos del proyecto de negocio.',
  'procedural-tutorial.md': 'Plantilla de tutorial procedural.',
  'gitignore-snippet.txt': 'Entradas que se añaden al .gitignore.',
  'CLAUDE.stack.md': 'Punto de partida para la sección Stack de CLAUDE.md.',
  'codeExtensions.json': 'Extensiones de código que leen los hooks.',
  'editorconfig.snippet': 'Fragmento de .editorconfig del lenguaje.',
  'settings.snippet.json': 'Permisos de Bash del lenguaje.',
  'stryker-config.json': 'Configuración de mutation testing.',
  'vitest.config.ts': 'Configuración de Vitest con cobertura.'
};

const MCP_NOTES = {
  sequentialthinking: 'Razonamiento estructurado multipaso.',
  context7: 'Documentación actualizada de librerías.',
  fetch: 'Trae páginas web como md, txt o json.',
  'codebase-memory': 'Grafo de código y búsqueda semántica.',
  playwright: 'Navegador: capturas, snapshot de accesibilidad, red y consola.',
  dbhub: 'SQL de solo lectura sobre MySQL, MariaDB, PostgreSQL, SQL Server o SQLite.',
  a11y: 'Auditoría de accesibilidad (axe-core) sobre páginas http(s).',
  mdn: 'Compatibilidad de CSS, HTML y JS por navegador.',
  colors: 'Paletas, escalas y contraste de color.',
  mermaid: 'Renderiza diagramas Mermaid.',
  serena: 'Navegación y edición a nivel de símbolo vía LSP.'
};

const read = (p) => readFileSync(p, 'utf8').replace(/^\uFEFF/, '');

function frontmatter(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  const fm = {};
  if (!m) return fm;
  for (const line of m[1].split(/\r?\n/)) {
    const kv = line.match(/^([A-Za-z][\w-]*):\s*(.*)$/);
    if (kv) fm[kv[1]] = kv[2].replace(/^"(.*)"$/s, '$1').trim();
  }
  fm.args = [...m[1].matchAll(/^\s+- name:\s*(\S+)/gm)].map((x) => x[1]);
  return fm;
}

function groupOf(kind, name) {
  for (const [group, names] of Object.entries(GROUPS[kind])) if (names.includes(name)) return group;
  throw new Error(`${kind} sin grupo en build-data.mjs: ${name}`);
}

function load(kind, dir, fileFor) {
  const items = readdirSync(join(core, dir))
    .map((entry) => ({ entry, file: fileFor(entry) }))
    .filter(({ file }) => existsSync(file) && statSync(file).isFile())
    .map(({ entry, file }) => {
      const text = read(file);
      const fm = frontmatter(text);
      const name = fm.name || entry.replace(/\.md$/, '');
      return {
        name,
        group: groupOf(kind, name),
        description: fm.description || '',
        args: fm.args,
        userOnly: fm['disable-model-invocation'] === 'true',
        tools: fm.tools ? fm.tools.split(',').map((t) => t.trim()) : [],
        model: fm.model || '',
        source: kind === 'agents' ? text : ''
      };
    });
  for (const names of Object.values(GROUPS[kind]))
    for (const n of names) if (!items.some((i) => i.name === n)) throw new Error(`${kind}: ${n} listado en build-data.mjs pero no existe`);
  return items.sort((a, b) => a.name.localeCompare(b.name));
}

function walk(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(join(dir, e.name)) : [join(dir, e.name)]);
}

function templatesOf(plugin) {
  const root = join(repo, 'plugins', plugin, 'templates');
  return walk(root).map((f) => {
    const rel = relative(root, f).split('\\').join('/');
    const base = rel.split('/').pop();
    const text = /\.(json|md|txt|snippet|ts|yml|yaml|gitignore)$/.test(base) && statSync(f).size <= 6000;
    return { path: rel, note: TEMPLATE_NOTES[base] || '', content: text ? read(f) : '' };
  });
}

function stages(plugin) {
  return JSON.parse(read(join(repo, 'plugins', plugin, 'templates', 'pipeline.json'))).stages
    .map((s) => ({ id: s.id, order: s.order, cmd: s.cmd || `interno: ${s.internal}`, tier: s.tier, blocking: s.blocking, enabled: s.enabled !== false }));
}

const mcp = JSON.parse(read(join(core, '.mcp.json'))).mcpServers;
const manifest = (p) => JSON.parse(read(join(repo, 'plugins', p, '.claude-plugin', 'plugin.json')));

const data = {
  generatedFrom: 'plugins/',
  plugins: ['bossdream-core', 'bossdream-dotnet', 'bossdream-nodejs'].map((p) => ({ name: p, version: manifest(p).version, description: manifest(p).description })),
  commands: load('commands', 'commands', (e) => join(core, 'commands', e)),
  skills: load('skills', 'skills', (e) => join(core, 'skills', e, 'SKILL.md')),
  agents: load('agents', 'agents', (e) => join(core, 'agents', e)),
  mcp: Object.entries(mcp).map(([name, c]) => ({ name, package: (c.args || []).find((a) => /^(git\+|@?[\w./-]+@v?\d)/.test(a)) || c.command, runner: c.command, note: MCP_NOTES[name] || '' })),
  templates: { core: templatesOf('bossdream-core'), dotnet: templatesOf('bossdream-dotnet'), nodejs: templatesOf('bossdream-nodejs') },
  pipeline: { dotnet: stages('bossdream-dotnet'), nodejs: stages('bossdream-nodejs') },
  debt: read(join(repo, 'docs', 'TECH_DEBT.md')).split(/\r?\n/).filter((l) => l.startsWith('| TD-')).map((l) => {
    const c = l.split('|').map((x) => x.trim());
    return { id: c[1], where: c[2].replace(/`/g, ''), kind: c[3], problem: c[4], fix: c[5], severity: c[6], status: c[7] };
  }),
  hooks: readdirSync(join(core, 'scripts')).filter((f) => f.endsWith('.ps1')).map((f) => f.replace('.ps1', ''))
};

const out = join(here, 'data');
if (!existsSync(out)) mkdirSync(out);
writeFileSync(join(out, 'site-data.js'), `window.SITE_DATA=${JSON.stringify(data)};\n`);
console.log(`commands=${data.commands.length} skills=${data.skills.length} agents=${data.agents.length} mcp=${data.mcp.length} templates=${data.templates.core.length}+${data.templates.dotnet.length}+${data.templates.nodejs.length}`);
