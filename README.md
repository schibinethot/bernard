# bernard (plugin Claude Code)

**BERNARD as a Service** — Plugin Claude Code qui transforme votre CLI en une equipe complete :
un orchestrateur BERNARD + 17 experts specialises (18 agents au total), 6 commandes workflow,
7 skills, 5 hooks de garde et un MCP de memoire partagee.

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

### 6 commandes workflow

| Commande | Role |
|---|---|
| `/bernard` | Discussion libre ou routing vers un agent expert |
| `/retro` | Retrospective automatique des executions passees |
| `/auto-improve` | Cycle complet retro + apply + compact + cross-scan |
| `/cross-scan` | Scan cross-projets des patterns d'erreur connus |
| `/briefing` | Digest matin : emails + agenda + ClickUp + projets |
| `/compact` | Compaction des memories agents (fusion + supersede) |

### 7 skills auto-declenchees

| Skill | Quand |
|---|---|
| `audit-project` | Audit generique d'un projet contre son CDC |
| `audit-crm` | Audit dedie CRM / ERP multi-modules |
| `simplify` | Revue de simplification avant PR |
| `migrate-feedbacks` | Migration des regles perso vers agent-memory |
| `am-sql-preprod-deploy` | Script SQL preprod avant promote prod (Drizzle + Neon) |
| `am-supabase-ddl-deploy` | Deploy DDL Supabase autonome via psql (jamais demander a l'user) |
| `am-email-content-rules` | Checklist contenu email AM (ton, photos, Cloudinary, vocabulaire) |

### 5 hooks de garde

| Event | Script | Role |
|---|---|---|
| `PreToolUse` (Bash) | `guard.sh` | Bloque git force-push, rm -rf /, SQL destructeur |
| `PostToolUse` (Write/Edit) | `post-write-lint.sh` | Lance `eslint --fix` sur les TS/JS |
| `SubagentStop` | `elena-casey-enforcer.sh` | Rappelle ELENA + CASEY apres SEBASTIEN/REMI/MORGAN sur projet critique |
| `SessionEnd` | `stop-auto-memory.sh` | Demande a Claude de memoriser les learnings |
| `SessionEnd` | `memory-hygiene.sh` | Warn si BERNARD depasse 5 memories/session |

### 1 serveur MCP

`agent-memory` — memoire partagee Heart / Soul / Memory / Knowledge / Scratchpad, deploye
sur Fly.io par defaut. Permet aux agents de partager des decisions, des learnings et des
etats de projet entre sessions.

---

## Installation

### 1. Pre-requis

- Claude Code >= 2.1 (support plugins)
- Un endpoint MCP agent-memory (URL + bearer token) — voir `.env.example`
- Optionnel : `gws` CLI (Google Workspace), MCP ClickUp

Doc officielle plugins Claude Code : https://docs.claude.com/en/docs/claude-code/plugins

### 2. Installer le plugin

Le plugin expose un manifeste `plugin.json` (pas un marketplace). Trois options :

#### Option A — Dev local rapide (pas de marketplace requis)

Demarrer Claude Code en pointant directement sur le dossier cloné :

```bash
git clone https://github.com/tpmge/bernard-cc-plugin.git
claude --plugin-dir /absolute/path/to/bernard-cc-plugin
```

Cette approche est ideale pour essayer, iterer ou contribuer. Pas de registry ni de
marketplace, le plugin est actif uniquement dans cette session.

#### Option B — Reference dans votre `~/.claude/settings.json` user

Clone le repo, puis ajoute le plugin dans votre config user Claude Code :

```json
{
  "plugins": {
    "bernard": {
      "path": "/absolute/path/to/bernard-cc-plugin"
    }
  }
}
```

Le plugin sera charge automatiquement a chaque session Claude Code.

#### Option C — Publication via marketplace.json (partage interne ou public)

Pour distribuer le plugin a une equipe ou au public, il faut un wrapper marketplace.
Cree un fichier `.claude-plugin/marketplace.json` a la racine d'un repo separé (ex
`tpmge/bernard-marketplace`) :

```json
{
  "name": "bernard-marketplace",
  "owner": { "name": "tpmge" },
  "plugins": [
    {
      "name": "bernard",
      "source": {
        "type": "github",
        "repository": "tpmge/bernard-cc-plugin"
      },
      "description": "BERNARD as a Service — orchestrateur + 17 experts"
    }
  ]
}
```

Ensuite depuis Claude Code :

```bash
/plugin marketplace add tpmge/bernard-marketplace
/plugin install bernard
```

Le marketplace est un repo GitHub (ou local) qui liste un ou plusieurs plugins. Chaque
entree `plugins[]` pointe vers le vrai repo du plugin via `source.repository`.

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
bernard/                   # name dans plugin.json ; repo = bernard-cc-plugin
  .claude-plugin/
    plugin.json            # manifeste
  agents/                  # 18 agents (.md avec frontmatter)
  commands/                # 6 commandes workflow
  skills/                  # 7 skills autonomes
    audit-project/SKILL.md
    audit-crm/SKILL.md
    simplify/SKILL.md
    migrate-feedbacks/SKILL.md
    am-sql-preprod-deploy/SKILL.md
    am-supabase-ddl-deploy/SKILL.md
    am-email-content-rules/SKILL.md
  hooks/
    hooks.json             # config events
    scripts/
      guard.sh
      post-write-lint.sh
      elena-casey-enforcer.sh
      stop-auto-memory.sh
      memory-hygiene.sh
  .mcp.json                # config MCP agent-memory
  .env.example
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
- [ ] v0.3 — Command `/bernard worktree-split` + skill `bernard-parallel-worktree` + hook `worktree-gitignore-check`
- [ ] v0.4 — Skills P1 : `am-promote-branch-sync`, `email-cron-create`, `social-caption-generate`, `am-social-postproxy-publish`
- [ ] v0.5 — Skill `cost-tracker` (suivi cout LLM par agent)
- [ ] v0.6 — Commandes `/focus`, `/digest`, `/speculate` (cockpit quotidien)
- [ ] v0.7 — Templates projets (web SaaS, mobile, e-commerce)
- [ ] v1.0 — Dashboard web de gouvernance des agents

---

## Changelog

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
