# Patterns Claude Code 2026 integres dans le plugin

Ce plugin suit les meilleures pratiques Claude Code telles qu'observees dans les 101 plugins
officiels Anthropic et dans l'ecosysteme a avril 2026.

## 1. Structure `.claude-plugin/plugin.json`

Le manifeste n'est pas a la racine mais dans un sous-dossier `.claude-plugin/`, comme exige
par le schema officiel (voir code.claude.com/docs/en/plugins).

## 2. Auto-discovery des composants

Pas besoin de declarer chaque agent / commande / skill dans `plugin.json` : Claude Code
scanne automatiquement les dossiers conventionnels (`agents/`, `commands/`, `skills/`,
`hooks/`, `.mcp.json`).

## 3. `${CLAUDE_PLUGIN_ROOT}` dans les hooks

Jamais de chemin absolu hardcode dans `hooks.json`. Utiliser la variable d'environnement
`${CLAUDE_PLUGIN_ROOT}` qui est resolue au runtime par Claude Code quel que soit
l'emplacement d'installation du plugin.

Exemple :
```json
"command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/guard.sh"
```

## 4. Secrets en `${VAR}` dans `.mcp.json`

Les placeholders `${AGENT_MEMORY_URL}` et `${AGENT_MEMORY_TOKEN}` sont resolus par Claude
Code a partir de `~/.claude/settings.json` ou des variables d'environnement du shell. Aucun
secret n'est commite dans le repo.

## 5. Un agent = un role + un modele

Chaque agent specifie son modele (opus / sonnet / haiku) dans son frontmatter pour
permettre le routing par cout / qualite :
- Opus pour les roles "architecte" et "decision" (bernard, julia, morgan, sebastien,
  casey, rebecca, onyx, mika, nova)
- Sonnet pour les roles "production" (remi, aurelien, iris, jordan, thomas, laure, elena,
  leo)
- Haiku pour les roles "veille" a fort volume (claire)

## 6. Format frontmatter riche

Chaque agent / commande / skill inclut :
- `name` ou `description` : declencheur d'auto-invocation (agents) ou aide (commandes)
- `argument-hint` : format des arguments (commandes)
- `model` : cost control
- `color` : visuel UI Claude Code

## 7. Skills progressives disclosure

Les 4 skills du plugin suivent le pattern "progressive disclosure" :
- `SKILL.md` = 200-400 lignes max avec les instructions principales
- Sous-dossiers `scripts/`, `references/`, `examples/` pour le detail lourd
- Chargement a la demande — pas de pollution du contexte principal

## 8. Hooks en defense-en-profondeur

Les regles critiques (jamais de git push --force, rm -rf /, etc.) sont implementees
**a la fois** :
- En hook bash bloquant (exit code 2)
- En memoire MCP (feedback_*.md migre)

Cela permet de proteger meme si l'agent ignore la memoire, et de re-rappeler la regle en
contexte quand l'agent y reflechit.

## 9. MCP agent-memory pour l'etat inter-sessions

Plutot que des fichiers markdown locaux, l'etat des projets, les decisions et les learnings
sont dans un serveur MCP (Fly.io) partage entre toutes les sessions Claude Code de
l'utilisateur / de l'equipe.

Primitives principales :
- `get_heart` : etat des projets actifs
- `get_memories(agent, query, limit)` : rappel semantique
- `store_memory(agent, event_type, summary, importance)` : ecriture
- `store_knowledge(category, knowledge)` : connaissance partagee durable
- `compact_memories` : compaction automatique

## 10. Pas de chemin utilisateur hardcode

Aucun `/Users/xxx/` dans le code du plugin — tout est relatif a `${CLAUDE_PLUGIN_ROOT}` ou
au cwd du projet cible. Permet la distribution cross-systeme (macOS, Linux, WSL).

## 11. Fallback gracieux sur integrations optionnelles

Les commandes `/briefing` et `/focus` testent `command -v gws` avant d'appeler la CLI
Google Workspace. De meme pour ClickUp MCP. Aucune commande ne plante si une integration
n'est pas disponible — la section concernee est simplement omise du rapport.

## 12. Reponses en francais par defaut

Contrainte explicite dans chaque agent et commande : `Repondre en francais.` — adaptation
au profil utilisateur cible (dev full-stack francophone).
