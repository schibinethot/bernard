#!/usr/bin/env node
// sync-routines.mjs
// Sync les routines scheduled (triggers) Claude Code a partir des YAML dans routines/.
//
// Usage:
//   CLAUDE_SESSION_TOKEN=sk-ant-sid01-... node scripts/sync-routines.mjs
//   CLAUDE_SESSION_TOKEN=... node scripts/sync-routines.mjs nova            # sync juste celle qui matche "nova"
//   DRY_RUN=1 CLAUDE_SESSION_TOKEN=... node scripts/sync-routines.mjs       # parse + affiche le payload, pas d'API call
//   node scripts/sync-routines.mjs --keep-templates                         # ne PAS substituer les ${VAR} (debug)
//
// Comportement:
//   - Charge `.env` a la racine du plugin (simple key=value parser, zero dep npm)
//   - Substitue `${VAR}` dans les prompts AVANT envoi, a partir des env vars locales
//   - Si une ${VAR} du prompt n'est pas definie en env : ERREUR explicite, pas de push (sauf --keep-templates)
//   - Si le YAML a un `id`, UPDATE via PATCH /triggers/:id
//   - Sinon CREATE via POST /triggers, et ecrit l'id retourne dans le YAML
//   - Si le prompt_file contient un marqueur TODO non commente en haut, skip (placeholder) sauf avec --force
//
// Zero dependance npm. Node 20+ (fetch natif).

import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const ROOT = resolve(__dirname, '..');
const ROUTINES_DIR = join(ROOT, 'routines');
const ENV_PATH = join(ROOT, '.env');

// ---------- mini loader .env (key=value, # comments, quoted values) ----------
function loadDotEnv(envPath) {
  if (!existsSync(envPath)) return {};
  const text = readFileSync(envPath, 'utf8');
  const out = {};
  for (const raw of text.split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    // strip surrounding quotes
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    out[key] = value;
  }
  return out;
}

// Merge .env file into process.env (process.env wins — env-vars set on command line override .env)
const fileEnv = loadDotEnv(ENV_PATH);
for (const [k, v] of Object.entries(fileEnv)) {
  if (process.env[k] === undefined || process.env[k] === '') {
    process.env[k] = v;
  }
}

// ---------- config API ----------
const CLAUDE_API_BASE = process.env.CLAUDE_API_BASE || 'https://claude.ai/api';
const TOKEN = process.env.CLAUDE_SESSION_TOKEN;
const DRY_RUN = process.env.DRY_RUN === '1' || process.env.DRY_RUN === 'true';
const FORCE = process.argv.includes('--force');
const KEEP_TEMPLATES = process.argv.includes('--keep-templates');

if (!TOKEN && !DRY_RUN) {
  console.error('[sync-routines] ERREUR : variable env CLAUDE_SESSION_TOKEN manquante.');
  console.error('');
  console.error('Comment obtenir le token :');
  console.error('  1. Ouvre claude.ai dans Chrome, connecte-toi');
  console.error('  2. DevTools (F12) > Application > Cookies > https://claude.ai');
  console.error('  3. Copie la valeur du cookie `sessionKey` (commence par sk-ant-sid01-...)');
  console.error('  4. Ajoute-le dans `.env` a la racine du plugin : CLAUDE_SESSION_TOKEN=sk-ant-sid01-...');
  console.error('  5. Relance : node scripts/sync-routines.mjs');
  console.error('');
  console.error('Ou bien DRY_RUN=1 pour juste valider les YAML sans push.');
  process.exit(2);
}

// ---------- substitution ${VAR} ----------
// Matche ${NOM_DE_VAR} avec lettres, chiffres et underscores.
const VAR_PATTERN = /\$\{([A-Z][A-Z0-9_]*)\}/g;

function findAllVars(text) {
  const vars = new Set();
  let m;
  VAR_PATTERN.lastIndex = 0;
  while ((m = VAR_PATTERN.exec(text)) !== null) {
    vars.add(m[1]);
  }
  return [...vars];
}

function substituteVars(text, envObj) {
  return text.replace(VAR_PATTERN, (_, name) => {
    const v = envObj[name];
    if (v === undefined || v === '') {
      // laisse intact, la detection des missing vars est faite avant
      return `\${${name}}`;
    }
    return v;
  });
}

// ---------- mini parser YAML (flat + listes simples + blocs imbriques pour mcp_connections) ----------
function parseYaml(text) {
  const lines = text.split('\n');
  const out = {};
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];
    const trimmed = line.replace(/\s+$/, '');

    if (!trimmed || trimmed.trimStart().startsWith('#')) {
      i++;
      continue;
    }

    // cle scalaire : "key: value"
    const scalarMatch = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$/);
    if (scalarMatch && !line.startsWith(' ')) {
      const [, key, rawValue] = scalarMatch;
      const value = rawValue.trim();

      if (value === '') {
        // bloc (liste ou objet) — peek la prochaine ligne
        const next = lines[i + 1] || '';
        const nextTrim = next.trimStart();

        if (nextTrim.startsWith('- ')) {
          // liste (soit scalaire soit d'objets)
          const listItems = [];
          i++;
          // determiner l'indent
          const indent = next.length - nextTrim.length;
          while (i < lines.length) {
            const l = lines[i];
            if (!l.trim() || l.trimStart().startsWith('#')) { i++; continue; }
            const ind = l.length - l.trimStart().length;
            if (ind < indent) break;
            if (l.trimStart().startsWith('- ')) {
              // nouveau item
              const rest = l.trimStart().slice(2);
              if (rest.includes(':')) {
                // objet sur plusieurs lignes : la 1ere cle est inline
                const obj = {};
                const [k, ...vparts] = rest.split(':');
                obj[k.trim()] = coerce(vparts.join(':').trim());
                i++;
                // consomme les cles suivantes de l'objet (meme indent + 2)
                const subIndent = indent + 2;
                while (i < lines.length) {
                  const ll = lines[i];
                  if (!ll.trim() || ll.trimStart().startsWith('#')) { i++; continue; }
                  const llInd = ll.length - ll.trimStart().length;
                  if (llInd < subIndent) break;
                  if (ll.trimStart().startsWith('- ')) break;
                  const m = ll.trimStart().match(/^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$/);
                  if (m) {
                    obj[m[1]] = coerce(m[2]);
                    i++;
                  } else {
                    i++;
                  }
                }
                listItems.push(obj);
              } else {
                // scalaire simple
                listItems.push(coerce(rest));
                i++;
              }
            } else {
              break;
            }
          }
          out[key] = listItems;
          continue;
        } else {
          // bloc objet — pas utilise ici, on skip
          i++;
          continue;
        }
      } else {
        out[key] = coerce(value);
        i++;
        continue;
      }
    }

    i++;
  }

  return out;
}

function coerce(raw) {
  if (raw == null) return null;
  let v = raw.trim();
  if (v === 'null' || v === '~' || v === '') return null;
  if (v === 'true') return true;
  if (v === 'false') return false;
  if (/^-?\d+$/.test(v)) return parseInt(v, 10);
  if (/^-?\d+\.\d+$/.test(v)) return parseFloat(v);
  // strip quotes
  if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
    v = v.slice(1, -1);
  }
  return v;
}

// ---------- chargement routines ----------
function loadRoutines(filterTerm) {
  const files = readdirSync(ROUTINES_DIR).filter((f) => f.endsWith('.yml') || f.endsWith('.yaml'));
  const routines = [];

  for (const f of files) {
    const filePath = join(ROUTINES_DIR, f);
    const yaml = readFileSync(filePath, 'utf8');
    const data = parseYaml(yaml);

    if (!data.name) {
      console.warn(`[sync-routines] ${f} : pas de champ 'name', skip.`);
      continue;
    }

    if (filterTerm && !data.name.toLowerCase().includes(filterTerm.toLowerCase())) {
      continue;
    }

    // charger le prompt (template brut, substitution plus tard)
    let promptTemplate = '';
    let promptIsPlaceholder = false;
    if (data.prompt_file) {
      const promptPath = join(ROOT, data.prompt_file);
      try {
        promptTemplate = readFileSync(promptPath, 'utf8');
        // detecte placeholder : marqueur "TODO" dans les 20 premieres lignes en dehors de commentaires md
        const head = promptTemplate.split('\n').slice(0, 20).join('\n');
        if (/^\s*TODO\s*$/m.test(head) || /PLACEHOLDER/.test(head)) {
          promptIsPlaceholder = true;
        }
      } catch (err) {
        console.warn(`[sync-routines] ${f} : prompt_file ${data.prompt_file} introuvable.`);
        promptTemplate = '';
      }
    }

    routines.push({
      file: f,
      filePath,
      data,
      promptTemplate,
      promptIsPlaceholder,
    });
  }

  return routines;
}

// ---------- validation + substitution des vars ----------
function resolvePrompts(routines) {
  // 1. detecte toutes les vars referencees dans les prompts
  const allVars = new Set();
  const varsByRoutine = new Map();
  for (const r of routines) {
    const vars = findAllVars(r.promptTemplate);
    varsByRoutine.set(r.file, vars);
    for (const v of vars) allVars.add(v);
  }

  if (KEEP_TEMPLATES) {
    console.log('[sync-routines] --keep-templates : aucune substitution (prompts bruts envoyes).');
    for (const r of routines) r.prompt = r.promptTemplate;
    return { ok: true, vars: [...allVars] };
  }

  // 2. verifie que toutes sont definies
  const missing = [...allVars].filter((v) => process.env[v] === undefined || process.env[v] === '');
  if (missing.length > 0) {
    console.error('[sync-routines] ERREUR : variables d\'env manquantes pour substitution des prompts.');
    console.error('');
    console.error('  Variables referencees dans les prompts :');
    for (const v of [...allVars].sort()) {
      const status = missing.includes(v) ? 'MANQUANTE' : 'OK';
      console.error(`    - ${v.padEnd(30)} [${status}]`);
    }
    console.error('');
    console.error('  Detail par routine :');
    for (const [file, vars] of varsByRoutine) {
      if (vars.length === 0) continue;
      const miss = vars.filter((v) => missing.includes(v));
      if (miss.length > 0) {
        console.error(`    ${file} : manque ${miss.join(', ')}`);
      }
    }
    console.error('');
    console.error('  Solution : ajoute ces cles dans `.env` a la racine du plugin.');
    console.error('  Voir `.env.example` pour la liste complete.');
    console.error('  Ou passe --keep-templates pour sync les prompts bruts (debug uniquement).');
    return { ok: false, missing };
  }

  // 3. substitue dans chaque prompt
  for (const r of routines) {
    r.prompt = substituteVars(r.promptTemplate, process.env);
  }

  console.log(`[sync-routines] Substitution OK : ${allVars.size} variable(s) injectee(s) dans ${routines.length} prompt(s).`);
  return { ok: true, vars: [...allVars] };
}

// ---------- API calls ----------
async function apiCall(method, path, body) {
  const url = `${CLAUDE_API_BASE}${path}`;
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Cookie': `sessionKey=${TOKEN}`,
    'User-Agent': 'bernard-cc-plugin/0.6.1 (sync-routines)',
  };

  if (DRY_RUN) {
    console.log(`[DRY_RUN] ${method} ${url}`);
    if (body) console.log('[DRY_RUN] body:', JSON.stringify(body, null, 2).slice(0, 500));
    return { ok: true, dry: true };
  }

  const res = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* noop */ }

  if (!res.ok) {
    throw new Error(`API ${method} ${path} -> ${res.status} ${res.statusText} : ${text.slice(0, 500)}`);
  }

  return json || { ok: true };
}

function buildPayload(routine) {
  const d = routine.data;
  return {
    name: d.name,
    cron_expression: d.cron_expression,
    enabled: d.enabled ?? true,
    environment_id: d.environment_id,
    model: d.model,
    allowed_tools: d.allowed_tools || [],
    mcp_connections: (d.mcp_connections || []).map((m) => ({
      name: m.name,
      connector_uuid: m.connector_uuid || null,
      url: m.url,
    })),
    prompt: routine.prompt,
  };
}

async function syncRoutine(routine) {
  const name = routine.data.name;
  const id = routine.data.id;

  if (routine.promptIsPlaceholder && !FORCE) {
    console.warn(`[sync-routines] ${name} : prompt placeholder (TODO), skip (utilise --force pour ignorer).`);
    return { skipped: true };
  }

  const payload = buildPayload(routine);

  if (id) {
    console.log(`[sync-routines] UPDATE ${name} (${id})`);
    const res = await apiCall('PATCH', `/triggers/${id}`, payload);
    console.log(`[sync-routines] ${name} : OK`);
    return { updated: true, id };
  } else {
    console.log(`[sync-routines] CREATE ${name}`);
    const res = await apiCall('POST', `/triggers`, payload);
    const newId = res?.id || res?.trigger_id || null;
    if (newId && !DRY_RUN) {
      // back-write id dans le YAML
      const yaml = readFileSync(routine.filePath, 'utf8');
      const updated = yaml.replace(/^id:\s*.*$/m, `id: ${newId}`);
      writeFileSync(routine.filePath, updated);
      console.log(`[sync-routines] ${name} : cree avec id=${newId} (YAML mis a jour)`);
    } else {
      console.log(`[sync-routines] ${name} : cree (id non retrouve dans la reponse)`);
    }
    return { created: true, id: newId };
  }
}

// ---------- main ----------
async function main() {
  const args = process.argv.slice(2).filter((a) => !a.startsWith('--'));
  const filter = args[0] || null;

  const routines = loadRoutines(filter);
  if (!routines.length) {
    console.error(`[sync-routines] Aucune routine trouvee${filter ? ` (filtre: ${filter})` : ''}.`);
    process.exit(1);
  }

  console.log(`[sync-routines] ${routines.length} routine(s) a sync${DRY_RUN ? ' (DRY_RUN)' : ''}${KEEP_TEMPLATES ? ' (KEEP_TEMPLATES)' : ''}.`);
  console.log('');

  // resolution des vars
  const resolution = resolvePrompts(routines);
  if (!resolution.ok) {
    process.exit(3);
  }

  let ok = 0, skipped = 0, errors = 0;

  for (const routine of routines) {
    try {
      const res = await syncRoutine(routine);
      if (res.skipped) skipped++;
      else ok++;
    } catch (err) {
      console.error(`[sync-routines] ${routine.data.name} : ERREUR — ${err.message}`);
      errors++;
    }
  }

  console.log('');
  console.log(`[sync-routines] Resume : ${ok} OK, ${skipped} skipped, ${errors} erreur(s).`);
  process.exit(errors > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error('[sync-routines] Fatal :', err);
  process.exit(1);
});
