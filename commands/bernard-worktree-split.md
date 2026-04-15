---
description: Orchestre N agents en parallele sur worktrees git isoles pour eliminer les collisions filesystem. Decompose un chantier en sous-taches, cree un worktree par agent, delegue en parallele, puis merge selon la strategie choisie.
argument-hint: <chantier> --agents <csv> [--branch-prefix bernard/wt] [--merge-strategy sequential|octopus|manual] [--base main]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, mcp__agent-memory__log_interaction, mcp__agent-memory__store_knowledge, mcp__agent-memory__store_memory
---

Tu es BERNARD en mode worktree-split. Objectif : eclater un chantier en N sous-taches isolees sur worktrees git paralleles, deleguer a N agents, puis merger selon la strategie choisie. Architecture validee par MORGAN (specs v0.3).

**Repondre en francais.**

## Arguments attendus

- `<chantier>` (positional, required) : description libre du chantier (ex "refactor API orders + tests + doc").
- `--agents <liste>` (required) : CSV agents namespace `bernard:` (ex `sebastien,remi,elena`). Max 5.
- `--branch-prefix <str>` (optionnel, default `bernard/wt`) : prefixe des branches creees.
- `--merge-strategy <mode>` (optionnel, default `sequential`) : `sequential` | `octopus` | `manual`.
- `--base <branch>` (optionnel, default `main`) : branche source a partir de laquelle worktree.

Parser `$ARGUMENTS` pour extraire ces valeurs. Si `--agents` absent ou si plus de 5 agents : abort avec message d'erreur clair.

## Workflow 5 phases

### Phase 0 — Pre-flight

Verifications bloquantes avant de creer quoi que ce soit :

1. Working tree clean :
   ```bash
   git status --porcelain
   ```
   Si non vide : abort avec "Working tree dirty. Commit ou stash avant worktree-split."

2. `.worktrees/` dans `.gitignore` :
   ```bash
   grep -qE "^\.worktrees(/|$)" .gitignore 2>/dev/null || {
     echo ".worktrees/" >> .gitignore
     git add .gitignore
     git commit -m "chore: ignore worktrees"
   }
   ```

3. Verifier que les branches cibles n'existent pas deja (local + remote) :
   ```bash
   SLUG=$(echo "<chantier>" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9-')
   for AGENT in $AGENTS; do
     BRANCH="<prefix>/$SLUG/$AGENT"
     git show-ref --quiet "refs/heads/$BRANCH" && {
       # Suffixer -2, -3...
       i=2
       while git show-ref --quiet "refs/heads/$BRANCH-$i"; do i=$((i+1)); done
       BRANCH="$BRANCH-$i"
       echo "[warn] Branche existante, suffixe -$i"
     }
   done
   ```

4. Mettre a jour la base :
   ```bash
   git fetch --all
   git checkout <base>
   git pull origin <base>
   ```

Tracer le debut via MCP :
```
mcp__agent-memory__log_interaction from_agent="BERNARD" to_agent="BERNARD" task_type="delegation" input_summary="worktree-split <chantier>" output_summary="phase 0 OK, agents=<liste>"
```

### Phase 1 — Analyse conflits potentiels

Decomposer le chantier en N sous-taches (1 par agent). Pour chaque sous-tache, lister les fichiers susceptibles d'etre modifies (heuristique : keywords + glob patterns).

```bash
# Pour chaque agent, identifier fichiers touches
# Heuristique : grep sur keywords de la sous-tache + glob par type
# Ex: "refactor orders API" → server/routes/orders*.ts, server/db/schema.ts
```

Construire matrice collision NxN :
```
         sebastien   remi      elena
sebastien    -      orders.ts  tests/orders
remi         -        -        tests/ui
elena        -        -          -
```

Si overlap sur fichier critique (`schema.ts`, `package.json`, `package-lock.json`, `pnpm-lock.yaml`) : warn bloquant, demander confirmation explicite.

Si overlap non-critique : warn non-bloquant, noter dans `.bernard-worktree-context.md` de chaque agent concerne.

### Phase 2 — Creation worktrees

Pour chaque agent :

```bash
SLUG=$(echo "<chantier>" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9-')
WT_DIR=".worktrees/$SLUG/$AGENT"
BRANCH="<prefix>/$SLUG/$AGENT"

git worktree add -b "$BRANCH" "$WT_DIR" "<base>"
```

Injecter dans chaque worktree un fichier contextuel :

```bash
cat > "$WT_DIR/.bernard-worktree-context.md" <<EOF
# Contexte worktree — $AGENT

**Chantier** : <chantier>
**Agent assigne** : $AGENT
**Branche** : $BRANCH
**Base** : <base>
**Cree le** : $(date -Iseconds)

## Sous-tache

<description sous-tache specifique a cet agent>

## Fichiers a NE PAS toucher (anti-collision)

<liste fichiers reserves aux autres agents>

## Fichiers attendus en modification

<liste fichiers sur la sous-tache>
EOF
```

### Phase 3 — Delegation parallele

Spawn N `Task(subagent_type="bernard:<agent>")` simultanes via **un seul message multi-tool-calls** (critique pour parallelisme reel).

Chaque delegation contient :
- Path absolu du worktree (`cd .worktrees/$SLUG/$AGENT`)
- Sous-tache decrite en 2-3 phrases
- Rappel contrainte fichiers interdits
- Instruction de commit final avec message descriptif

Timeout : 20 min par agent par defaut, surchargeable via env `BERNARD_WT_TIMEOUT`.

Si un agent crashe (timeout, erreur Task) : continuer les autres, marquer l'agent FAILED dans le rapport final, preserver la branche pour investigation.

### Phase 4 — Verification diffs + merge

Pour chaque worktree :

```bash
cd "$WT_DIR"
git diff --stat "<base>"...HEAD
git log --oneline "<base>"...HEAD

# Tests si present
if [ -f "package.json" ] && grep -q '"test"' package.json; then
  npm test 2>&1 || echo "[warn] tests KO sur $AGENT"
fi

cd -
```

Si tests KO sur 1 agent : marquer la branche UNMERGED, rapport + branche preservee.

Merger selon `--merge-strategy` :

**sequential** (default) :
```bash
git checkout <base>
for AGENT in $AGENTS; do
  BRANCH="<prefix>/$SLUG/$AGENT"
  git merge --no-ff "$BRANCH" -m "merge $BRANCH" || {
    # Conflit detecte
    git merge --abort
    cat > ".worktrees/$SLUG/CONFLICT-REPORT.md" <<EOF
# Conflit merge sequential — $(date -Iseconds)

Branche : $BRANCH
Fichiers en conflit :
$(git diff --name-only --diff-filter=U)

## Suggestion
Invoquer bernard:morgan pour analyse + merge guide.
EOF
    echo "[abort] Conflit sur $BRANCH, voir CONFLICT-REPORT.md"
    break
  }
done
```

**octopus** :
```bash
git checkout <base>
BRANCHES=$(for AGENT in $AGENTS; do echo "<prefix>/$SLUG/$AGENT"; done | xargs)
git merge --no-ff $BRANCHES -m "octopus merge $SLUG" || {
  git merge --abort
  echo "[abort] Octopus merge impossible, basculer en --merge-strategy=sequential ou manual"
}
```

**manual** :
- Stoppe apres verification (diffs + tests).
- Laisse les branches `<prefix>/$SLUG/$AGENT` pretes pour PR manuelles.
- Affiche les URLs gh pour `gh pr create` sur chaque branche.

### Phase 5 — Rapport final

```markdown
## Worktree-Split Report — <chantier>

**Date** : <iso>
**Chantier** : <description>
**Agents** : <liste>
**Strategy** : <sequential|octopus|manual>

### Par agent

| Agent | Branche | Commits | Files changed | Tests | Merge |
|---|---|---|---|---|---|
| sebastien | bernard/wt/<slug>/sebastien | 3 | 7 | OK | merged |
| remi | bernard/wt/<slug>/remi | 2 | 4 | OK | merged |
| elena | bernard/wt/<slug>/elena | 1 | 2 | OK | merged |

### Conflits

- Aucun / <liste si detectes>

### Actions suivantes

- `git push origin <base>` pour publier la base mergee
- `git worktree prune` apres validation
- `git branch -D <prefix>/<slug>/*` pour nettoyer si merge OK
```

Tracer la fin via MCP :
```
mcp__agent-memory__store_knowledge category="worktree-run" project="<detecte>" summary="<chantier>" details={agents, slug, strategy, commits_shas, duree_ms}
```

Si conflit non-auto-resoluble :
```
mcp__agent-memory__store_memory agent="MORGAN" event_type="learning" summary="Conflit worktree-split sur <fichier> entre <agent1> et <agent2>" importance=0.7
```

## Gestion conflits merge detaillee

**Conflit sequential** :
1. `git merge --abort` pour revenir a l'etat pre-merge.
2. Generer `.worktrees/<slug>/CONFLICT-REPORT.md` avec fichiers + diff.
3. Proposer spawn `Task(subagent_type="bernard:morgan")` pour analyse conflit et merge guide.
4. **JAMAIS** `git checkout --ours` / `--theirs` automatique. Toujours demander.

**Conflit octopus** :
1. Octopus merge ne gere pas les conflits → abort immediat.
2. Proposer bascule automatique en `--merge-strategy=sequential`.
3. Ou suggerer `--merge-strategy=manual` pour resolution via PRs.

**Conflit manual** :
- N/A : aucun merge effectue, user resout via PRs.

## Cas d'erreur documentes

| Cas | Action |
|---|---|
| Working tree dirty | Abort phase 0, message clair |
| Branche `<prefix>/<slug>/<agent>` existe deja | Suffixer `-2`, `-3`, warn |
| Overlap critique (schema.ts, package.json) | Warn bloquant, confirmation explicite requise |
| Agent Task timeout (> BERNARD_WT_TIMEOUT) | Marquer FAILED, continuer autres, preserver branche |
| Agent crash / erreur | Idem : FAILED, autres continuent, rapport partiel |
| Tests KO sur 1 branche | Marquer UNMERGED, ne pas merger, preserver |
| Conflit non-auto-resoluble | CONFLICT-REPORT + bascule strategy ou abort |
| `.worktrees/` absent de `.gitignore` | Auto-append + commit `chore: ignore worktrees` |
| Remote branche existe deja | Suffixer comme local |
| > 5 agents passes en `--agents` | Abort phase 0 avec message |

## Integration agent-memory MCP

**Debut** :
```
mcp__agent-memory__log_interaction
  from_agent="BERNARD"
  to_agent="BERNARD"
  task_type="delegation"
  input_summary="worktree-split <chantier>"
  output_summary="agents=<liste>, strategy=<mode>"
```

**Par agent delegue** :
```
mcp__agent-memory__log_interaction
  from_agent="BERNARD"
  to_agent="<agent_upper>"
  task_type="delegation"
  input_summary="<sous-tache>"
  output_summary="worktree=<path>, branche=<branch>"
```

**Fin run** :
```
mcp__agent-memory__store_knowledge
  category="worktree-run"
  project="<detecte via remote>"
  summary="<chantier>"
  details={
    slug,
    agents: [...],
    branches: [...],
    commits_shas: {agent: sha},
    strategy,
    duree_ms,
    conflits: [...]
  }
```

**Sur conflit irresolu** :
```
mcp__agent-memory__store_memory
  agent="MORGAN"
  event_type="learning"
  summary="Conflit sur <fichier> entre <ag1> et <ag2> (chantier <slug>)"
  importance=0.7
```

## Regles

- Max 5 agents par split (au-dela, l'orchestration coute plus que le parallelisme).
- Toujours clean working tree avant demarrage.
- `.worktrees/` TOUJOURS dans `.gitignore`.
- Jamais de `git checkout --ours/--theirs` automatique sur conflit.
- Preserver les branches meme en cas d'echec (debug possible).
- Tracer systematiquement via MCP.
- Repondre en francais.
- Si 2 agents touchent `schema.ts` ou lockfiles : bloquer et demander confirmation explicite.

Arguments : $ARGUMENTS
