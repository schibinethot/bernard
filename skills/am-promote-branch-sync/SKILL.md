---
name: am-promote-branch-sync
description: Apres un git promote ou un merge preprod -> main sur un projet AM critique (ERP-AM, SITE-AM, APP-NELVO, CRM-ESC-PACK), resynchronise preprod avec main pour garantir l'iso des branches. Detecte le drift post-merge, applique le merge main -> preprod, push, et revient sur main. A declencher des que l'utilisateur mentionne "promote", "sync branches", "iso preprod/main" ou apres une release sur un projet critique.
version: 1.0.0
tags: git, branches, preprod, am, iso-sync
---

# Sync preprod <- main apres promote AM

Apres un merge preprod -> main (git promote) sur les projets critiques AM, rejouer le merge main -> preprod pour maintenir l'iso stricte des deux branches. Implementation du feedback critique `feedback_branches_iso`.

**Core principle :** feedback_branches_iso est critique. preprod et main DOIVENT etre iso apres chaque promote ou hotfix. Sans ce sync, la prochaine PR preprod embarque des commits deja en main et casse l'historique.

**Announce at start :** "Je declenche la skill am-promote-branch-sync pour resync preprod <- main (feedback_branches_iso)."

## Prerequis

- Git CLI
- Branches `main` et `preprod` existent sur le remote
- Working tree clean (stash auto sinon)
- Remote `origin` configure sur un projet critique AM :
  - `erp-am`
  - `site-am`
  - `app-nelvo`
  - `crm-esc-pack`

## Detection projet

```bash
REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
CRITICAL_PROJECTS="erp-am|site-am|app-nelvo|crm-esc-pack"

if ! echo "$REMOTE" | grep -qiE "$CRITICAL_PROJECTS"; then
  echo "[skill] Projet hors whitelist critique. NOOP."
  exit 0
fi

PROJECT=$(echo "$REMOTE" | grep -oiE "$CRITICAL_PROJECTS" | head -1 | tr '[:upper:]' '[:lower:]')
echo "[skill] Projet critique detecte : $PROJECT"
```

## Checklist

### Step 0 — Working tree clean

```bash
if [ -n "$(git status --porcelain)" ]; then
  echo "[skill] Working tree dirty, stash auto avant sync"
  git stash push -u -m "am-promote-branch-sync auto-stash $(date -Iseconds)"
  STASHED=1
else
  STASHED=0
fi
```

### Step 1 — Verifier qu'on est bien sur main et a jour

```bash
git checkout main
git pull origin main
```

Attendu : `Already up to date.` ou fast-forward. Si conflit local : abort + rapport (ne jamais force).

### Step 2 — Checkout preprod

```bash
# Verifier que preprod existe cote remote
if ! git ls-remote --heads origin preprod | grep -q preprod; then
  echo "[skill] Branche preprod absente sur origin. Skip."
  exit 0
fi

git checkout preprod
git pull origin preprod
```

### Step 3 — Merge main dans preprod

```bash
git merge main --no-edit
```

Cas possibles :
- **Fast-forward** : main etait en avance, preprod rattrape proprement. Log ok.
- **Already up to date** : preprod etait deja iso. NOOP.
- **Conflit** : arreter, rapport (voir section Red Flags), ne jamais force.

### Step 4 — Detection drift post-merge

Apres le merge, `git diff main..preprod --stat` DOIT etre vide pour une iso parfaite.

```bash
DRIFT=$(git diff main..preprod --stat 2>/dev/null)

if [ -n "$DRIFT" ]; then
  echo "[warn] Drift detecte apres merge :"
  echo "$DRIFT"

  # Whitelist : fichiers autorises a differer entre preprod et main
  WHITELIST_PATTERN='\.env\.preprod|scripts/preprod/|\.env\.preprod\.example'

  UNAUTHORIZED=$(echo "$DRIFT" | awk '{print $1}' | grep -vE "$WHITELIST_PATTERN" || true)

  if [ -n "$UNAUTHORIZED" ]; then
    echo "[warn] Fichiers hors whitelist dans le drift :"
    echo "$UNAUTHORIZED"
    # Log via MCP pour learning futur
    # mcp__agent-memory__store_memory agent="LEO" event_type="learning"
    #   summary="drift detecte sur <projet> : <fichiers>" importance=0.6
  else
    echo "[info] Drift entierement dans la whitelist (env/scripts preprod). OK."
  fi
fi
```

**Whitelist drift autorise** :
- `.env.preprod`, `.env.preprod.example`
- `scripts/preprod/*`
- Tout fichier dont le path contient `/preprod/`

Tout drift hors whitelist doit etre logge via MCP `store_memory agent="LEO"` pour learning futur.

### Step 5 — Push preprod

```bash
git push origin preprod
```

Attendu : push propre, pas de force. Si le push est rejete (non-fast-forward), arreter et investiguer.

### Step 6 — Retour sur main (etat initial)

```bash
git checkout main

# Si stash initial, pop
if [ "$STASHED" = "1" ]; then
  git stash pop || echo "[warn] stash pop a echoue, stash preserve : git stash list"
fi
```

### Step 7 — Validation iso

```bash
git fetch origin
DIFF_FINAL=$(git diff origin/main..origin/preprod --stat)

if [ -z "$DIFF_FINAL" ]; then
  echo "[skill] preprod <- main iso confirmee. Done."
else
  echo "[skill] preprod n'est pas iso avec main apres sync :"
  echo "$DIFF_FINAL"
  echo "Verifier la whitelist drift ou investiguer."
fi
```

## Detection drift post-merge (formalisee)

**Objectif** : apres merge main -> preprod, `git diff main..preprod` doit etre vide.

| Cas | Decision |
|---|---|
| Drift vide | OK, iso parfaite |
| Drift dans whitelist (`.env.preprod`, `scripts/preprod/*`) | OK, log info |
| Drift hors whitelist | Warn + log MCP `store_memory` |
| Drift > 10 fichiers | Warn bloquant, proposer investigation manuelle |

## Red Flags

**Ne JAMAIS :**
- Force push sur preprod (`git push -f origin preprod`) — casse l'historique partage.
- Ignorer un conflit en resolvant avec `--ours` ou `--theirs` sans review.
- Skipper la whitelist drift (un drift non documente indique une divergence a investiguer).
- Lancer ce skill sur un projet hors whitelist critique (NOOP clair).

**Toujours :**
- Stash auto si dirty, pop a la fin.
- Pull avant merge (main ET preprod).
- Push apres merge reussi (sinon le drift reste local).
- Revenir sur main a la fin (etat initial de l'utilisateur preserve).
- Log les drifts hors whitelist pour learning (via MCP `store_memory`).

## Edge cases

| Cas | Action |
|---|---|
| Projet hors whitelist critique | NOOP, message clair |
| Branche preprod absente sur remote | Skip propre, warn |
| Working tree dirty | Stash auto, pop a la fin |
| Conflit merge main -> preprod | Abort, rapport, jamais force |
| Push rejete (non-fast-forward) | Stop, investigation manuelle |
| User deja sur preprod au demarrage | Normal, le flow revient a main a la fin |

## Tests

### Test 1 — Projet critique, preprod deja iso

```bash
# Setup : erp-am avec preprod iso main
./skill am-promote-branch-sync
# Attendu : merge "Already up to date", drift vide, push NOOP
```

### Test 2 — Projet critique, main avance

```bash
# Setup : merge sur main non repercute sur preprod
./skill am-promote-branch-sync
# Attendu : merge fast-forward, drift vide, push OK
```

### Test 3 — Projet hors whitelist

```bash
# Setup : projet random (ex bernard-cc-plugin)
./skill am-promote-branch-sync
# Attendu : NOOP clair, skill ne modifie rien
```

### Test 4 — Drift dans whitelist (.env.preprod)

```bash
# Setup : .env.preprod different entre branches
./skill am-promote-branch-sync
# Attendu : merge OK, drift detecte, log info "dans whitelist"
```

### Test 5 — Drift hors whitelist

```bash
# Setup : fichier custom qui differe
./skill am-promote-branch-sync
# Attendu : merge OK, warn drift hors whitelist, log MCP
```

## Integration

**Agents concernes :**
- LEO (devops, coordination preprod/prod)
- SEBASTIEN (backend, peut declencher apres deploy schema)
- BERNARD (orchestrateur, declenche apres un promote global)

**Pairs avec :**
- `am-sql-preprod-deploy` (deploy SQL preprod AVANT le promote)
- Hook `branch-sync-reminder.sh` (rappel apres `git push origin main` sur projet critique)

## Reference

- Source : `feedback_branches_iso` (feedback utilisateur, critique)
- Complementaire : `feedback_sql_preprod` (deploy SQL)
- Projets concernes : ERP-AM, SITE-AM, APP-NELVO, CRM-ESC-PACK
- Hook deja en place : `hooks/scripts/branch-sync-reminder.sh` rappelle apres push main
