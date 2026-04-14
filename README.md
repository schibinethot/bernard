# bernard-cc-plugin

**BERNARD as a Service** — Plugin Claude Code qui transforme votre CLI en une equipe complete :
un orchestrateur, 17 agents specialises, 6 commandes workflow, 4 skills, 3 hooks de garde et
un MCP de memoire partagee.

> Licence commerciale. 30 jours d'evaluation gratuite. Voir [LICENSE](./LICENSE).

---

## Ce que le plugin ajoute a votre Claude Code

### 18 agents invocables
Orchestrateur + 17 experts metier, chacun avec son prompt, son format d'output et sa
coordination documentee :

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

### 4 skills auto-declenchees

| Skill | Quand |
|---|---|
| `audit-project` | Audit generique d'un projet contre son CDC |
| `audit-crm` | Audit dedie CRM / ERP multi-modules |
| `simplify` | Revue de simplification avant PR |
| `migrate-feedbacks` | Migration des regles perso vers agent-memory |

### 3 hooks de garde

| Event | Script | Role |
|---|---|---|
| `PreToolUse` (Bash) | `guard.sh` | Bloque git force-push, rm -rf /, SQL destructeur |
| `PostToolUse` (Write/Edit) | `post-write-lint.sh` | Lance `eslint --fix` sur les TS/JS |
| `SessionEnd` | `stop-auto-memory.sh` | Demande a Claude de memoriser les learnings |

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

### 2. Ajouter le marketplace prive

```bash
# Depuis votre Claude Code CLI
/plugin marketplace add https://github.com/tpmge/bernard-cc-plugin.git
# ou en local :
/plugin marketplace add /Users/you/Dev/bernard-cc-plugin
```

### 3. Installer le plugin

```bash
/plugin install bernard-cc-plugin
```

### 4. Configurer les secrets

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

### 5. Activer le plugin

```bash
/plugin enable bernard-cc-plugin
```

Verifier :

```bash
# Dans Claude Code
/bernard bonjour, qui es-tu ?
```

Si BERNARD repond en francais en se presentant comme orchestrateur : tout est OK.

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

```
# Invocation via slash command custom (si defini)
# Ou invocation implicite : BERNARD route automatiquement
```

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
bernard-cc-plugin/
  .claude-plugin/
    plugin.json            # manifeste
  agents/                  # 18 agents (.md avec frontmatter)
  commands/                # 6 commandes workflow
  skills/                  # 4 skills autonomes
    audit-project/SKILL.md
    audit-crm/SKILL.md
    simplify/SKILL.md
    migrate-feedbacks/SKILL.md
  hooks/
    hooks.json             # config events
    scripts/
      guard.sh
      post-write-lint.sh
      stop-auto-memory.sh
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

- [ ] v0.2 — Hook Stop-compact (compaction auto des memoires toutes les N sessions)
- [ ] v0.3 — Skill `cost-tracker` (suivi cout LLM par agent)
- [ ] v0.4 — Commandes `/focus`, `/digest`, `/speculate` (cockpit quotidien)
- [ ] v0.5 — Templates projets (web SaaS, mobile, e-commerce)
- [ ] v1.0 — Dashboard web de gouvernance des agents

---

## Licence

Plugin commercial sous licence d'usage. Voir [LICENSE](./LICENSE).
30 jours d'evaluation gratuite. Au-dela, licence payante requise.

Contact : hello@bernard.as

---

*Made by BERNARD & l'equipe. Sonic delivered by Claude Code + Mistral.*
