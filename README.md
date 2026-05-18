# bernard (plugin Claude Code)

**BERNARD as a Service** — Plugin Claude Code qui transforme votre CLI en une equipe complete :
un orchestrateur BERNARD + 17 experts specialises (18 agents au total), 7 commandes workflow,
12 skills, 11 hooks de garde, 11 routines scheduled et un MCP de memoire partagee.

> Licence commerciale. 30 jours d'evaluation gratuite. Voir [LICENSE](./LICENSE).

---

## Ce que le plugin ajoute a votre Claude Code

### 18 agents invocables (1 orchestrateur + 17 experts)

Orchestrateur + 17 experts metier, chacun avec son prompt, son format d'output et sa
coordination documentee. Namespace runtime : `bernard:<agent>` (ex `bernard:sebastien`).

| Equipe | Agents |
|---|---|
| Orchestration | `bernard` |
| Direction tech | `julia` |
| Produit / Design | `aurelien`, `onyx` |
| Engineering | `morgan`, `remi`, `sebastien`, `leo` |
| QA / Securite | `elena`, `casey` |
| Data / Business | `iris`, `jordan`, `thomas`, `laure`, `mika`, `rebecca` |
| Veille | `claire`, `nova` |

### 7 commandes workflow

| Commande | Role |
|---|---|
| `/bernard` | Discussion libre ou routing vers un agent expert |
| `/bernard-worktree-split` | Orchestre N agents en parallele sur worktrees git isoles, merge sequential/octopus/manual |
| `/retro` | Retrospective automatique des executions passees |
| `/auto-improve` | Cycle complet retro + apply + compact + cross-scan |
| `/cross-scan` | Scan cross-projets des patterns d'erreur connus |
| `/briefing` | Digest matin : emails + agenda + ClickUp + projets |
| `/compact` | Compaction des memories agents (fusion + supersede) |

### 12 skills auto-declenchees

| Skill | Quand |
|---|---|
| `audit-project` | Audit generique d'un projet contre son CDC |
| `audit-crm` | Audit dedie CRM / ERP multi-modules |
| `simplify` | Revue de simplification avant PR |
| `migrate-feedbacks` | Migration des regles perso vers agent-memory |
| `am-sql-preprod-deploy` | Script SQL preprod avant promote prod (Drizzle + Neon) |
| `am-supabase-ddl-deploy` | Deploy DDL Supabase autonome via psql (jamais demander a l'user) |
| `am-email-content-rules` | Checklist contenu email AM (ton, photos, Cloudinary, vocabulaire) |
| `am-promote-branch-sync` | Sync preprod <- main apres git promote sur projet AM critique (feedback_branches_iso) |
| `email-cron-create` | Creer un cron email nurturing avec pattern anti-backfill (CRON_CREATED_AT + fenetre 24h) |
| `am-social-postproxy-publish` | Publier post social AM via PostProxy, payload top-level (profiles/media/platforms) |
| `social-caption-generate` | Generer captions Instagram/Facebook/LinkedIn conformes aux regles AM |
| `cost-tracker` | Analyse et estime les couts LLM par agent, modele et projet via MCP agent-memory |

### 11 hooks de garde

| Event | Script | Role |
|---|---|---|
| `PreToolUse` (Bash) | `guard.sh` | Bloque git force-push, rm -rf /, SQL destructeur (DROP/TRUNCATE/DELETE sans WHERE) |
| `PreToolUse` (Bash) | `worktree-gitignore-check.sh` | Bloque `git add .worktrees/` et `git add .` si .worktrees absent de .gitignore |
| `PostToolUse` (Write/Edit) | `post-write-lint.sh` | Lance `eslint --fix` sur les TS/JS |
| `PostToolUse` (Write/Edit) | `cron-date-filter-check.sh` | Detecte crons sans filtre date anti-backfill |
| `PostToolUse` (Bash) | `branch-sync-reminder.sh` | Rappelle skill am-promote-branch-sync apres push origin main sur projet critique |
| `PostToolUse` (Bash) | `bash-audit-log.sh` | Log Bash dans MCP agent-memory (audit Phase 5 + patterns d'erreur sur crons) |
| `SubagentStop` | `elena-casey-enforcer.sh` | Rappelle ELENA + CASEY apres SEBASTIEN/REMI/MORGAN sur projet critique |
| `PreCompact` | `pre-compact-snapshot.sh` | Avant compaction : nudge `store_memory` sur decisions critiques (effort-aware) |
| `SessionEnd` | `stop-auto-memory.sh` | Demande a Claude de memoriser les learnings |
| `SessionEnd` | `memory-hygiene.sh` | Warn si BERNARD depasse 5 memories/session |
| `SessionEnd` | `session-end-summary.sh` | Push direct vers MCP agent-memory (garantit au moins 1 trace audit) |

### 1 serveur MCP

`agent-memory` — memoire partagee Heart / Soul / Memory / Knowledge / Scratchpad, deploye
sur Fly.io par defaut. Permet aux agents de partager des decisions, des learnings et des
etats de projet entre sessions.

### 11 routines scheduled

Routines Claude Code programmees qui tournent sur `claude.ai/code/scheduled`. Chaque routine
est trackee en git via un fichier YAML (metadata + cron) + un fichier markdown (prompt),
et est redeployable en une commande via `scripts/sync-routines.mjs`.

| Routine | Cron | Role |
|---|---|---|
| `bernard-daily-scan` | `30 5 * * 1-5` | Briefing matinal lun-ven 07h30 Paris (emails, agenda, ClickUp, memoires) |
| `bernard-feature-executor` | `33 8 * * 1-5` | Execution auto des features taguees `bernard-approved` |
| `bernard-weekly-security` | `17 6 * * 1` | Audit securite CASEY chaque lundi 08h17 Paris (CVE, OWASP) |
| `nova-synthesis-3x-daily` | `0 7,12,17 * * *` | Veille AI tooling NOVA 3x/jour (09h/14h/19h Paris) |
| `mika-daily-ads-perf` | `0 7 * * 1-5` | Perf ads Meta + Google Ads quotidienne sur Atelier Mesure |
| `iris-weekly-projects-kpi` | `0 14 * * 5` | KPI des 4 projets critiques chaque vendredi 16h Paris |
| `laure-weekly-seo` | `0 9 * * 2` | Veille SEO AM chaque mardi 11h Paris (positions, concurrence) |
| `retro-nightly` | `0 23 * * *` | RETRO nocturne 01h Paris : scan logs 24h, PRs auto sur prompts bancals (Phase 5) |
| `auto-test-weekly` | `0 3 * * 1` | ELENA clone + `npm test` des 4 repos chaque lundi 05h Paris, PR fix si trivial (Phase 5) |
| `cross-scan-weekly` | `0 4 * * 1` | BERNARD cross-scan patterns inter-projets chaque lundi 06h Paris (SQL, try-catch, TODO, secrets) (Phase 5) |
| `upgrade-agents-weekly` | `0 5 * * 0` | CLAIRE+NOVA veille releases Anthropic/Mistral/OpenAI chaque dimanche 07h Paris, PRs agents (Phase 5) |

**Structure** :
- `routines/<nom>.yml` — metadata (id trigger, cron, env, model, tools, MCP connections, reference prompt)
- `prompts/<nom>.md` — prompt complet de la routine (separe du YAML pour rester lisible)

**Prompts templates (securise pour repo public)** :

Les prompts dans `prompts/*.md` sont **templates** : ils contiennent des placeholders
`${VAR}` pour les tokens et IDs sensibles (`${TELEGRAM_PUSH_TOKEN}`, `${TELEGRAM_BOT_TOKEN}`,
`${AGENT_MEMORY_TOKEN}`, `${TELEGRAM_CHAT_ID}`, `${CLICKUP_WORKSPACE_ID}`,
`${CLICKUP_CHAT_CHANNEL}`). Les vraies valeurs vivent dans un `.env` local a la racine
du plugin (gitignore), jamais committe. Le script `sync-routines.mjs` charge ce `.env` et
substitue les `${VAR}` avant le push vers `claude.ai/api/triggers`.

Si une variable `${VAR}` referencee dans un prompt n'est pas definie en env, le script
refuse de push et liste explicitement les cles manquantes.

**Sync vers claude.ai** :

```bash
# 1. Copie .env.example -> .env et remplis les valeurs sensibles
cp .env.example .env
# edit .env : CLAUDE_SESSION_TOKEN (cookie sessionKey claude.ai), TELEGRAM_*, AGENT_MEMORY_TOKEN,
# CLICKUP_WORKSPACE_ID, CLICKUP_CHAT_CHANNEL

# 2. Sync une seule routine (filtre sur le nom)
node scripts/sync-routines.mjs nova

# 3. Sync toutes les routines
node scripts/sync-routines.mjs

# Dry-run (valide la substitution + affiche le payload, ne pousse rien)
DRY_RUN=1 node scripts/sync-routines.mjs

# Forcer meme si le prompt est encore un placeholder TODO
node scripts/sync-routines.mjs --force

# Sync SANS substituer les ${VAR} (debug : envoie les templates bruts)
node scripts/sync-routines.mjs --keep-templates
```

Le script est en ESM natif Node 20+ (aucune dep npm). Il charge `.env` a la racine via
un mini-parser integre (pas de `dotenv`). Si le YAML a un `id`, il fait un UPDATE
(PATCH) ; sinon il CREATE (POST) et reecrit l'id dans le YAML (a committer ensuite).

Via npm run :

```bash
npm run sync-routines:dry       # dry-run
npm run sync-routines -- nova   # cible une routine
```

---

## Installation

### 1. Pre-requis

- **Claude Code >= 2.1.105** (Opus 4.7 + Routines + skills frontmatter `context: fork` + hooks dans frontmatter agents/skills + `effort: xhigh` + auto mode hard_deny + native binaries)
- Un endpoint MCP agent-memory (URL + bearer token) — voir `.env.example`
- Optionnel : `gws` CLI (Google Workspace), MCP ClickUp

Doc officielle plugins Claude Code : https://code.claude.com/docs/en/plugins

### 2. Installer le plugin

Le plugin embarque son propre wrapper `marketplace.json` dans `.claude-plugin/`.
Trois options :

#### Option A — Install via marketplace GitHub (recommande)

Depuis Claude Code, ajoute le marketplace BERNARD et installe le plugin :

```bash
/plugin marketplace add schibinethot/bernard
/plugin install bernard
```

Ou en CLI :

```bash
claude plugin marketplace add schibinethot/bernard
claude plugin install bernard@bernard
```

Le repo est public. Les mises a jour se font via
`/plugin marketplace update bernard` puis `/plugin update bernard`.

#### Option B — Dev local rapide (clone + marketplace local)

Clone le repo, puis pointe le marketplace sur le dossier local :

```bash
git clone https://github.com/schibinethot/bernard.git /absolute/path/to/bernard
claude plugin marketplace add /absolute/path/to/bernard
claude plugin install bernard@bernard
```

Ideal pour iterer sur le plugin ou contribuer.

#### Option C — Reference dans votre `~/.claude/settings.json` user

Clone le repo, puis declare le plugin dans votre config user Claude Code :

```json
{
  "plugins": {
    "bernard": {
      "path": "/absolute/path/to/bernard"
    }
  }
}
```

Le plugin sera charge automatiquement a chaque session Claude Code, sans passer par
le systeme de marketplace.

#### Option D — `--plugin-url` ou `--plugin-dir` (session-scoped, v2.1.128+)

Pour tester une version specifique sans installer globalement :

```bash
# Telecharge un tarball/zip du plugin pour la session courante
claude --plugin-url https://github.com/schibinethot/bernard/archive/refs/heads/main.zip

# Ou pointer un dossier local
claude --plugin-dir /absolute/path/to/bernard
```

Pratique pour tester une branche de feature avant de merger sur main.

### 3. Configurer les secrets

Copier `.env.example` en `.env` a la racine de votre projet et renseigner :

```env
AGENT_MEMORY_URL=https://agent-memory-mcp.fly.dev
AGENT_MEMORY_TOKEN=<votre_token>
```

Ou declarer les variables dans votre `~/.claude/settings.json` :

```json
{
  "env": {
    "AGENT_MEMORY_URL": "https://agent-memory-mcp.fly.dev",
    "AGENT_MEMORY_TOKEN": "..."
  }
}
```

### 4. Verifier

```bash
# Dans Claude Code
/bernard bonjour, qui es-tu ?
```

Si BERNARD repond en francais en se presentant comme orchestrateur : tout est OK.

> **Collision possible avec une commande `/bernard` utilisateur**
>
> Les slash commands Claude Code ne sont PAS namespacees par plugin. Si vous avez deja
> une commande `~/.claude/commands/bernard.md`, retirez-la (ou renommez-la) avant d'activer
> le plugin, sinon la votre prendra priorite et le `/bernard` du plugin ne repondra pas.
> Les agents et skills, eux, sont namespaces (`bernard:sebastien`, etc.) et ne
> rentrent jamais en collision.

---

## Usage

### Discussion libre avec BERNARD

```
/bernard qu'est-ce que tu penses de notre stack actuel ?
```

BERNARD repond directement, pose des questions, propose des perspectives.

### Delegation a un agent

```
/bernard ajoute un endpoint POST /api/orders avec validation Zod
```

BERNARD detecte une tache d'execution backend, spawn SEBASTIEN via Task.

### Invocation directe d'un agent

Les agents du plugin sont namespaces `bernard:<agent>`. BERNARD les spawne via
`Task(subagent_type="bernard:sebastien")`, `bernard:elena`, etc. Vous pouvez aussi
les invoquer explicitement depuis une commande custom.

### Cycle d'amelioration

```
/auto-improve dry   # simulation
/auto-improve       # cycle complet
```

### Briefing matinal

```
/briefing
```

---

## Architecture du plugin

```
bernard/                   # name dans plugin.json ; repo = schibinethot/bernard
  .claude-plugin/
    plugin.json            # manifeste du plugin
    marketplace.json       # wrapper marketplace pour distribution /plugin marketplace add
  agents/                  # 18 agents (.md avec frontmatter)
  commands/                # 7 commandes workflow
  skills/                  # 12 skills autonomes
    audit-project/SKILL.md
    audit-crm/SKILL.md
    simplify/SKILL.md
    migrate-feedbacks/SKILL.md
    am-sql-preprod-deploy/SKILL.md
    am-supabase-ddl-deploy/SKILL.md
    am-email-content-rules/SKILL.md
    am-promote-branch-sync/SKILL.md
    email-cron-create/SKILL.md
    am-social-postproxy-publish/SKILL.md
    social-caption-generate/SKILL.md
    cost-tracker/SKILL.md
  hooks/
    hooks.json             # config events
    scripts/
      guard.sh
      worktree-gitignore-check.sh
      post-write-lint.sh
      branch-sync-reminder.sh
      elena-casey-enforcer.sh
      stop-auto-memory.sh
      memory-hygiene.sh
      cron-date-filter-check.sh
  routines/                # 7 routines scheduled (YAML metadata)
    bernard-daily-scan.yml
    bernard-feature-executor.yml
    bernard-weekly-security.yml
    nova-synthesis-3x-daily.yml
    mika-daily-ads-perf.yml
    iris-weekly-projects-kpi.yml
    laure-weekly-seo.yml
  prompts/                 # 7 prompts des routines (separes pour lisibilite)
    bernard-daily-scan.md
    bernard-feature-executor.md
    bernard-weekly-security.md
    nova-synthesis-3x-daily.md
    mika-daily-ads-perf.md
    iris-weekly-projects-kpi.md
    laure-weekly-seo.md
  scripts/
    sync-routines.mjs      # CLI sync routines -> claude.ai/code/scheduled (Node 20+, zero dep)
  .mcp.json                # config MCP agent-memory
  .env.example
  package.json             # scripts npm run sync-routines
  LICENSE
  README.md
  docs/                    # guides, patterns, screenshots
```

---

## Business model — BERNARD as a Service

### Solo — 149 EUR / mois
- 1 utilisateur, projets illimites
- Acces aux 18 agents et 6 commandes
- MCP agent-memory hebergement partage (shared tenant)
- Support communautaire (Discord)

### Agence — 599 EUR / mois
- 5 utilisateurs
- Tout Solo + support email (48h)
- Skills custom (jusqu'a 3)
- MCP agent-memory avec tenant dedie
- Onboarding 2h

### Scale — 1 990 EUR / mois
- 20+ utilisateurs
- Tout Agence + SLA 99.5%
- MCP agent-memory deploye en dedie (Fly.io, Railway ou self-hosted)
- Onboarding 1 jour + formation equipe
- Agents custom illimites (ajouter BERNARD des equipes marketing, juridique, etc.)
- Roadmap d'amelioration trimestrielle
- Revue d'usage mensuelle avec l'auteur

**Contact commercial** : hello@bernard.as

---

## Configuration avancee

### Desactiver un hook

Editer `hooks/hooks.json` et retirer l'entree correspondante.
Ou declarer l'override dans `~/.claude/settings.json`.

### Pointer sur un MCP local

```env
AGENT_MEMORY_URL=http://localhost:3001
```

Le serveur MCP agent-memory est open-source pour les clients Scale (sur demande).

### Ajouter un agent custom

1. Creer `agents/<nom>.md` avec frontmatter :

```markdown
---
name: nom
description: Quand invoquer cet agent (declenche l'auto-invocation)
model: opus|sonnet|haiku
color: slate
---

Prompt complet de l'agent...
```

2. Reloader le plugin (nouvelle session Claude Code).

### Etendre une commande

Copier `commands/<cmd>.md` depuis ce repo vers `~/.claude/commands/<cmd>.md` —
les commandes locales ont priorite sur celles du plugin.

---

## Roadmap (non contractuelle)

- [x] v0.2 — Integration P0 MORGAN : enforcer ELENA/CASEY + 3 skills AM (SQL preprod, Supabase DDL, email content) + memory-hygiene
- [x] v0.2.1 — Fixes QA ELENA : hooks.json wrapper, namespace plugin renomme `bernard`, scripts hooks chmod +x, count agents harmonise (18), section Install reecrite, collision `/bernard` documentee
- [x] v0.3 — Command `/bernard-worktree-split` + 3 skills P1 (`am-promote-branch-sync`, `email-cron-create`, `am-social-postproxy-publish`) + 2 hooks (`worktree-gitignore-check`, `branch-sync-reminder`)
- [x] v0.4 — Skill `social-caption-generate` + hook `cron-date-filter-check`
- [x] v0.5 — Skill `cost-tracker` (suivi cout LLM par agent)
- [x] v0.6 — 7 routines scheduled trackees en git + CLI `sync-routines.mjs` (Phase 3 Agents Platform v2)
- [x] v0.7 — Phase 4 : headless bridge + hooks avances (`bash-audit-log`, `pre-compact-snapshot`, `session-end-summary`)
- [x] v0.8 — Phase 5 : 4 routines auto-improvement (`retro-nightly`, `auto-test-weekly`, `cross-scan-weekly`, `upgrade-agents-weekly`)
- [x] v0.9 — Alignement Claude Code v2.1.105+ : modeles canoniques full-ID, skills preload frontmatter, `/fire` API officielle (beta `experimental-cc-routine-2026-04-01`), `--plugin-url` install, fix elena-casey case-insensitive
- [ ] v1.0 — Dashboard web de gouvernance des agents + Outcomes (rubriques de succes) + Dreaming (auto-amelioration cross-sessions, feature mai 2026)

---

## Changelog

### v0.9.0 — 2026-05-18 (alignement Claude Code v2.1.105+)

**Minor bump** : alignement sur les nouvelles features Claude Code livrees en avril-mai 2026 (Opus 4.7 + xhigh, Routines API officielle, skills frontmatter `context: fork`, hooks dans frontmatter agents/skills, `--plugin-url`).

**Corrections** (audit interne 2026-05-18)
- fix(README) : compte de hooks 8 -> 11 + 3 lignes manquantes au tableau (`bash-audit-log`, `pre-compact-snapshot`, `session-end-summary`).
- fix(version) : `package.json` 0.6.1 -> 0.9.0, User-Agent `sync-routines.mjs` aligne. Plus de drift entre `plugin.json` / `marketplace.json` / `package.json`.
- fix(hook) : `elena-casey-enforcer.sh` ligne 49 — regex `(ERP-AM|...)` passe en `grep -qiE` (case-insensitive) pour matcher `/tmp/erp-am/` aussi bien que `/Code/ERP-AM/`.
- fix(roadmap) : v0.7 et v0.8 marquees done (etaient livrees mais non cochees).

**Modernisation Claude Code v2.1**
- feat(routines) : `sync-routines.mjs` ajoute `--fire <routine> --text "..."` qui pousse vers l'endpoint officiel `https://api.anthropic.com/v1/claude_code/routines/<id>/fire` avec beta header `experimental-cc-routine-2026-04-01`. Le sync CREATE/UPDATE continue via `claude.ai/api/triggers` (undocumented, research preview).
- feat(env) : `.env.example` ajoute `ROUTINE_FIRE_TOKEN` (bearer scope routine, genere depuis le UI claude.ai).
- feat(agents) : modeles canoniques full-ID (`claude-sonnet-4-6`, `claude-haiku-4-5-20251001`) sur les 10 agents qui utilisaient les bare aliases `sonnet`/`haiku` — leve l'ambiguite si Anthropic deprecate les aliases.
- feat(agents) : skills preload via frontmatter `skills:` sur les agents qui en beneficient — `bernard:sebastien` preload `am-sql-preprod-deploy`, `bernard:elena` preload `simplify`, etc. (feature v2.1).
- docs(readme) : nouvelle Option D `--plugin-url`/`--plugin-dir` (session-scoped, v2.1.128+), pre-requis remonte a Claude Code 2.1.105.
- docs(readme) : note sur la **restriction plugin subagents** — `hooks`/`mcpServers`/`permissionMode` en frontmatter sont **ignores** pour les agents de plugin (regle securite Claude Code). Bernard utilise donc `hooks/hooks.json` au niveau plugin et `.mcp.json` au niveau plugin, pas au niveau agent.

**Compatibilite** : aucun breaking change. Le `--fire` est opt-in ; les modifs frontmatter agents n'affectent que les nouveaux runs.

**Compteurs**
- Commandes : 7 (inchange)
- Skills : 12 (inchange)
- Hooks : 8 -> **11** documentes (les 11 etaient deja dans hooks.json, juste pas listes dans le README)
- Agents : 18 (inchange)
- Routines : 11 (inchange, ajout du `--fire` officiel pour les declencher manuellement)

### v0.8.0 — 2026-04-19 (Phase 5 auto-amelioration)

**Minor bump** : scaffold de 4 routines auto-improvement qui font tourner Bernard sur lui-meme.

**Nouveautes**
- feat(phase5) : 4 routines scheduled — `retro-nightly` (01h Paris : scan logs 24h, PRs auto sur prompts bancals), `auto-test-weekly` (ELENA clone + npm test des 4 repos chaque lundi 05h, PR fix si trivial), `cross-scan-weekly` (BERNARD cross-scan patterns inter-projets chaque lundi 06h), `upgrade-agents-weekly` (CLAIRE+NOVA veille releases Anthropic/Mistral/OpenAI chaque dimanche 07h, PRs agents).
- feat(routines) : YAML metadata + prompts templates `${VAR}` pour les 4 nouvelles routines.
- perf(hooks) : `elena-casey-enforcer.sh` et `memory-hygiene.sh` bornent le scan transcript a `tail -c 2M/4M` + fix SIGPIPE + timeout lint reduit a 8s.

### v0.7.0 — 2026-04-18 (Phase 4 headless + hooks avances)

**Minor bump** : bridge headless + hooks `PreCompact` / `SessionEnd` enrichis.

**Nouveautes**
- feat(hook) : `bash-audit-log.sh` (PostToolUse Bash) — log commande + exit + duree dans MCP agent-memory via curl, importance 0.2, non-bloquant 3s timeout. Source pour patterns d'erreur cross-projets.
- feat(hook) : `pre-compact-snapshot.sh` (PreCompact) — nudge `store_memory` sur decisions critiques avant compaction. Lit `$CLAUDE_EFFORT` pour adapter le seuil (xhigh = nudge plus large).
- feat(hook) : `session-end-summary.sh` (SessionEnd) — push direct vers MCP (curl) en plus de `stop-auto-memory.sh` qui demande a Claude. Garantit au moins 1 trace audit meme si Claude coupe sans `store_memory`. Detecte commits recents pour distinguer `interaction` vs `learning`.

### v0.6.1 — 2026-04-17 (security : prompts routines templates)

**Patch bump** : securisation des 7 prompts routines avant publication du repo en public. Les tokens sensibles sont remplaces par des placeholders `${VAR}` substitues au push.

**Securite**
- chore(routines) : 7 prompts `prompts/*.md` reecrits en version **templates**. Zero token en clair. Placeholders utilises : `${TELEGRAM_PUSH_TOKEN}`, `${TELEGRAM_BOT_TOKEN}`, `${AGENT_MEMORY_TOKEN}`, `${TELEGRAM_CHAT_ID}`, `${CLICKUP_WORKSPACE_ID}`, `${CLICKUP_CHAT_CHANNEL}`.
- feat(scripts) : `sync-routines.mjs` charge un `.env` local (parser integre, zero dep) et substitue les `${VAR}` avant push vers l'API RemoteTrigger. Refuse de push si une variable referencee est manquante (liste explicite des missing). Flag `--keep-templates` pour sync les prompts bruts (debug).
- feat(env) : `.env.example` complete avec `TELEGRAM_PUSH_TOKEN`, `CLICKUP_CHAT_CHANNEL`, `CLAUDE_SESSION_TOKEN`.
- docs(readme) : section routines clarifie le modele template + `.env` + substitution.

**Compatibilite** : aucun breaking change. `node scripts/sync-routines.mjs` fonctionne comme avant, avec en plus le chargement auto du `.env` et la substitution.

### v0.6.0 — 2026-04-17 (routines scheduled trackees en git)

**Minor bump** : tracking des 7 routines Claude Code scheduled en git + CLI de sync idempotente. Phase 3 Agents Platform v2.

**Nouveautes**
- feat(routines) : 7 fichiers YAML dans `routines/` (metadata : id trigger, cron, env, model, tools, MCP connections) + 7 fichiers markdown dans `prompts/` (prompts separes du YAML pour lisibilite). Routines trackees : `bernard-daily-scan`, `bernard-feature-executor`, `bernard-weekly-security`, `nova-synthesis-3x-daily`, `mika-daily-ads-perf`, `iris-weekly-projects-kpi`, `laure-weekly-seo`.
- feat(scripts) : `scripts/sync-routines.mjs` — CLI Node ESM (Node 20+ natif, zero dep npm) qui lit les YAML + prompts, push vers `claude.ai/api/triggers` (CREATE si pas d'id, UPDATE sinon). Garde placeholder TODO. Options `--force`, `DRY_RUN=1`, filtre par nom.
- feat(npm) : `package.json` a la racine avec `npm run sync-routines` / `npm run sync-routines:dry`.
- docs(readme) : nouvelle section "7 routines scheduled" avec table recap + guide d'usage. Section architecture mise a jour. Changelog + roadmap.

**Note** : les prompts dans `prompts/*.md` sont actuellement des placeholders TODO. Le script refuse de push tant que le placeholder n'est pas remplace (sauf `--force`). Les prompts exacts des 7 routines existantes doivent etre copies depuis `claude.ai/code/scheduled` manuellement.

**Compteurs**
- Commandes : 7 (inchange)
- Skills : 12 (inchange)
- Hooks : 8 (inchange)
- Agents : 18 (inchange)
- Routines : 0 -> 7 (+7)

### v0.5.0 — 2026-04-16 (cost tracking)

**Minor bump** : skill cost-tracker pour estimer les couts LLM par agent et par projet (IRIS).

**Nouveautes**
- feat(skill) : `cost-tracker` — analyse cout LLM par agent (routing Opus/Sonnet/Haiku), par projet, par periode. Grille tarifaire avril 2026. Hypotheses tokens par type d'interaction. Workflow 8 etapes via MCP agent-memory. Comparaison budget Bernard-as-a-Service (Solo/Agence/Scale). Recommandations downgrade.

**Compteurs**
- Commandes : 7 (inchange)
- Skills : 11 → 12 (+1)
- Hooks : 8 (inchange)
- Agents : 18 (inchange)

### v0.4.0 — 2026-04-15 (content editorial + cron guard)

**Minor bump** : skill social media AM (REMI) + hook lint cron anti-backfill (LEO). Ferme la roadmap v0.4 P2.

**Nouveautes**
- feat(skill) : `social-caption-generate` — genere captions Instagram/Facebook/LinkedIn conformes aux regles AM (francais, pas de tiret cadratin, hashtags EN OK, ton Charvet/Hermes, Paris 7e, Cloudinary w_600,q_auto,f_auto). Templates par plateforme + exemples corrects + contre-exemple detaille. Implemente `feedback_social_content_rules` + `feedback_am_email_content`.
- feat(hook) : `cron-date-filter-check.sh` (PostToolUse Write|Edit) — scan ts/tsx/js/mjs/sql pour detecter crons sans filtre `created_at > CRON_CREATED_AT`. Warn non-bloquant. Implemente `feedback_cron_historical_backfill`.

**Compteurs**
- Commandes : 7 (inchange)
- Skills : 10 → 11 (+1)
- Hooks : 7 → 8 (+1)
- Agents : 18 (inchange)

### v0.3.1 — 2026-04-15 (fast-follow QA ELENA)

Patch rapide sur deux items identifies par ELENA apres v0.3.0.

- fix(hook) : `guard.sh` ligne 29 — pattern `git checkout \.` passait a `grep -qiF`
  (fixed strings), donc le `\.` etait litteral et rien ne matchait en pratique.
  Passe en regex `grep -qiE 'git checkout +\.( |$)'` pour matcher precisement
  `git checkout .` (avec espaces optionnels) sans faux positifs sur
  `git checkout file.txt` ou `git checkout main`. Non-regression verifiee sur
  les 8 smoke cases ELENA (4 cas git checkout + 4 cas autres patterns).
- docs(patterns) : nouvelle section "Worktrees paralleles" dans
  `docs/PATTERNS-2026.md` — documente le pattern hub-and-spoke + worktrees,
  quand utiliser `/bernard-worktree-split` (mutations chevauchantes), quand
  l'eviter (specs, paths disjoints, tache courte), exemple concret et hooks
  connexes (`worktree-gitignore-check`, `branch-sync-reminder`).

### v0.3.0 — 2026-04-15 (worktrees paralleles + skills AM P1)

**Minor bump majeur** : nouvelle architecture de travail parallele via worktrees git isoles + 3 skills P1 qui ferment les boucles de feedback critiques AM (branches iso, cron anti-backfill, social via PostProxy).

**Nouveautes**
- feat(command) : `/bernard-worktree-split <chantier>` pour orchestrer N agents en parallele sur worktrees git isoles. 5 phases (pre-flight, matrice collision, creation worktrees, delegation parallele, merge). Strategies : `sequential` | `octopus` | `manual`. Tracing MCP integre.
- feat(skill) : `am-promote-branch-sync` — sync preprod <- main apres git promote sur projet AM critique (ERP-AM, SITE-AM, APP-NELVO, CRM-ESC-PACK). Detection drift post-merge avec whitelist. Implemente `feedback_branches_iso`.
- feat(skill) : `email-cron-create` — template Drizzle/TS pour crons email nurturing avec pattern anti-backfill (`CRON_CREATED_AT` hardcode + fenetre 24h + LEFT JOIN idempotent). Checklist 6 items anti-spam. Implemente `feedback_cron_historical_backfill`.
- feat(skill) : `am-social-postproxy-publish` — publication sociale AM via PostProxy exclusivement, payload top-level (profiles/media/platforms). Contre-exemple du piege recurrent `{ post: {...} }`. Retry backoff expo sur 5xx. Implemente `feedback_postproxy` + `reference_postproxy_api`.
- feat(hook) : `worktree-gitignore-check.sh` (PreToolUse Bash) — bloque `git add .worktrees/` et `git add .` si `.worktrees/` absent du `.gitignore`. Compagnon obligatoire de `/bernard-worktree-split`.
- feat(hook) : `branch-sync-reminder.sh` (PostToolUse Bash) — apres `git push origin main` sur projet critique AM, rappelle de lancer le skill `am-promote-branch-sync`.

**Specs**
- MORGAN v2 a livre les specs detaillees via scratchpad MCP (`morgan_plugin_v03_specs_15avril`).
- Implementation SEBASTIEN (backend : command + 3 skills) + LEO (devops : 2 hooks).

**Compteurs**
- Commandes : 6 → 7 (+1)
- Skills : 7 → 10 (+3)
- Hooks : 5 → 7 (+2)
- Agents : 18 (inchange)

### v0.2.2 — 2026-04-14 (distribution marketplace)
- feat : `.claude-plugin/marketplace.json` wrapper ajoute pour distribution via `/plugin marketplace add`.
- feat : repo prive GitHub `schibinethot/bernard` cree pour installation facile (`/plugin marketplace add schibinethot/bernard`).
- fix : `plugin.json.repository` pointe desormais sur `schibinethot/bernard` (au lieu de `tpmge/bernard-cc-plugin`).
- docs : section Install reecrite avec marketplace GitHub en Option A primaire.

### v0.2.1 — 2026-04-14 (fixes QA ELENA)
- fix P0 : `hooks/hooks.json` encapsule dans `{"hooks": { ... }}` (validator `claude plugin validate .` passe).
- fix P0 : section Install du README reecrite avec 3 alternatives reelles (plugin-dir, settings.json, marketplace.json wrapper) + lien doc officielle.
- fix P1 : plugin renomme `bernard-cc-plugin` → `bernard` dans `plugin.json.name` pour un namespace subagent plus court (`bernard:sebastien` vs `bernard-cc-plugin:sebastien`). Prompts `agents/bernard.md` et `commands/bernard.md` mis a jour.
- fix P1 : scripts hooks `elena-casey-enforcer.sh` et `memory-hygiene.sh` verifies executables (chmod +x).
- fix P1 : compte d'agents harmonise a 18 (1 orchestrateur + 17 experts) dans plugin.json, LICENSE, README.
- fix P1 : collision potentielle `/bernard` slash command documentee dans le README.

### v0.2.0 — 2026-04-14
- Integration P0 MORGAN : enforcer ELENA/CASEY + 3 skills AM + memory-hygiene.

### v0.1.0 — 2026-04-14
- Scaffold initial du plugin : 18 agents, 6 commandes, 4 skills, 5 hooks, 1 MCP.

---

## Licence

Plugin commercial sous licence d'usage. Voir [LICENSE](./LICENSE).
30 jours d'evaluation gratuite. Au-dela, licence payante requise.

Contact : hello@bernard.as

---

*Made by BERNARD & l'equipe. Sonic delivered by Claude Code + Mistral.*
