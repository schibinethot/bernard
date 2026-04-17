#!/usr/bin/env node
// sync-routines.mjs
// Sync les routines scheduled (triggers) Claude Code a partir des YAML dans routines/.
//
// Usage:
//   CLAUDE_SESSION_TOKEN=sk-ant-sid01-... node scripts/sync-routines.mjs
//   CLAUDE_SESSION_TOKEN=... node scripts/sync-routines.mjs nova            # sync juste celle qui matche "nova"
//   DRY_RUN=1 CLAUDE_SESSION_TOKEN=... node scripts/sync-routines.mjs       # parse + affiche le payload, pas d'API call
//
// Comportement:
//   - Si le YAML a un `id`, UPDATE via PATCH /triggers/:id
//   - Sinon CREATE via POST /triggers, et ecrit l'id retourne dans le YAML (commit a faire a la main apres)
//   - Si le prompt_file contient la chaine "TODO" non commentee en haut, skip (placeholder) sauf avec --force
//
// Zero dependance npm. Node 20+ (fetch natif).

import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const ROOT = resolve(__dirname, '..');
const ROUTINES_DIR = join(ROOT, 'routines');

// ---------- config API ----------
const CLAUDE_API_BASE = process.env.CLAUDE_API_BASE || 'https://claude.ai/api';
const TOKEN = process.env.CLAUDE_SESSION_TOKEN;
const DRY_RUN = process.env.DRY_RUN === '1' || process.env.DRY_RUN === 'true';
const FORCE = process.argv.includes('--force');

if (!TOKEN && !DRY_RUN) {
  console.error('[sync-routines] ERREUR : variable env CLAUDE_SESSION_TOKEN manquante.');
  console.error('');
  console.error('Comment obtenir le token :');
  console.error('  1. Ouvre claude.ai dans Chrome, connecte-toi');
  console.error('  2. DevTools (F12) > Application > Cookies > https://claude.ai');
  console.error('  3. Copie la valeur du cookie `sessionKey` (commence par sk-ant-sid01-...)');
  console.error('  4. Relance : CLAUDE_SESSION_TOKEN=sk-ant-sid01-... node scripts/sync-routines.mjs');
  console.error('');
  console.error('Ou bien DRY_RUN=1 pour juste valider les YAML sans push.');
  process.exit(2);
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

    // charger le prompt
    let prompt = '';
    let promptIsPlaceholder = false;
    if (data.prompt_file) {
      const promptPath = join(ROOT, data.prompt_file);
      try {
        prompt = readFileSync(promptPath, 'utf8');
        // detecte placeholder : marqueur "TODO" dans les 20 premieres lignes en dehors de commentaires md
        const head = prompt.split('\n').slice(0, 20).join('\n');
        if (/^\s*TODO\s*$/m.test(head) || /PLACEHOLDER/.test(head)) {
          promptIsPlaceholder = true;
        }
      } catch (err) {
        console.warn(`[sync-routines] ${f} : prompt_file ${data.prompt_file} introuvable.`);
        prompt = '';
      }
    }

    routines.push({
      file: f,
      filePath,
      data,
      prompt,
      promptIsPlaceholder,
    });
  }

  return routines;
}

// ---------- API calls ----------
async function apiCall(method, path, body) {
  const url = `${CLAUDE_API_BASE}${path}`;
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Cookie': `sessionKey=${TOKEN}`,
    'User-Agent': 'bernard-cc-plugin/0.6.0 (sync-routines)',
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

  console.log(`[sync-routines] ${routines.length} routine(s) a sync${DRY_RUN ? ' (DRY_RUN)' : ''}.`);
  console.log('');

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
