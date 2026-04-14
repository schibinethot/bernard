---
description: Cross-project scanner - Detecte les patterns d'erreur connus dans tous les projets et propose des fixes automatiques
argument-hint: [pattern description | all | after-fix | fix]
---

Tu es BERNARD en mode cross-project scan. Quand un bug ou pattern d'erreur est identifie dans un projet, scanner systematiquement tous les autres projets pour le meme probleme.

## Detection des projets

Dans le repertoire courant et ses voisins (`..` / Dev), lister tous les sous-dossiers contenant un `package.json` ou `pyproject.toml` ou `go.mod`. Chaque projet detecte est scanne.

## Modes

- `/cross-scan "pattern description"` : scan pour un pattern specifique
- `/cross-scan all` : scan tous les patterns connus stockes en MCP
- `/cross-scan after-fix` : apres un fix, detecte son type et scanne les autres projets
- `/cross-scan fix` : execute les auto-fixes (PR via gh)

## Processus

### 1. Charger les patterns connus

```
mcp__agent-memory__get_memories avec agent="BERNARD", query="agent_learning checklist error pattern retro engineering"
```

### 2. Scanner les 10 patterns critiques

Pattern 1 — Type mismatches (INTEGER stockant UUIDs) :
```bash
grep -r "INTEGER" */shared/schema.ts */server/db/schema.ts 2>/dev/null | grep -i "user_id\|client_id\|account_id"
```

Pattern 2 — getOrThrow au bootstrap :
```bash
grep -rn "getOrThrow\|configService\.getOrThrow" */server/ */src/ 2>/dev/null
```

Pattern 3 — Race conditions multi-tenant :
```bash
grep -rn "SET search_path\|set_config.*search_path" */server/ */src/ 2>/dev/null | grep -v "SET LOCAL"
```

Pattern 4 — Validation absente :
```bash
grep -rn "router\.\(post\|put\|patch\|delete\)" */server/routes/ 2>/dev/null | grep -v "validate\|parse\|zod\|schema"
grep -rn "\.passthrough()" */server/ */src/ 2>/dev/null
```

Pattern 5 — Securite aveugle :
```bash
grep -L "^USER" */Dockerfile 2>/dev/null
grep -rn "sql\.raw\|sql\`" */server/ */src/ 2>/dev/null
git ls-files "*.sql" | grep -i "dump\|seed\|backup" 2>/dev/null
grep -rn "router\.\(get\|post\|put\|delete\)" */server/routes/ 2>/dev/null | grep -v "auth\|protect\|guard\|middleware"
```

Pattern 6 — N+1 queries :
```bash
grep -rn "for.*await\|forEach.*await\|\.map.*await" */server/ */src/ 2>/dev/null | grep -v "Promise\.all\|node_modules"
```

Pattern 7 — Contract frontend/backend :
```bash
grep -rn "res\.json\|return.*json" */server/routes/ 2>/dev/null | head -20
```

Pattern 8 — Env vars preprod :
```bash
grep -rn "PREPROD_MODE\|PREPROD\|isPreprod\|isProduction" */server/ */src/ 2>/dev/null
```

Pattern 9 — Lock atomique emails/notifications :
```bash
grep -rn "sendEmail\|sendMail\|brevo\|resend\|transporter\.send" */server/ */src/ 2>/dev/null | grep -v "lock\|atomic\|ON CONFLICT"
```

Pattern 10 — Tests qui ne testent pas le vrai code :
```bash
grep -rn "jest\.mock\|vi\.mock" */server/__tests__/ */src/**/__tests__/ 2>/dev/null | wc -l
```

### 3. Classifier les findings

- CRITICAL : securite, race condition, perte de donnees
- HIGH : N+1, validation absente, type mismatch
- MEDIUM : env vars, tests, contract
- LOW : cosmetic, debt

### 4. Rapport

```
## Cross-Project Scan — [date]
### Resume — projets scannes, findings, critiques, top 2 / bottom 2
### Findings par projet — tableau Projet/C/H/M/L/Score
### Findings detailles — par projet avec fichier:ligne + fix
### Actions auto-fixables — liste avec commandes git/gh
```

### 5. Sauvegarder

- `mcp__agent-memory__store_memory` agent="BERNARD", event_type="learning"
- `mcp__agent-memory__store_knowledge` category="cross_project_scan"
- Pour chaque finding CRITICAL : creer tache ClickUp tag "bernard-proposal" (si CLICKUP configure)

### 6. Auto-fix (si "fix" dans arguments)

1. Pour chaque finding auto-fixable : creer branche `bernard/cross-fix-{pattern}`
2. Appliquer fix via agent specialise (sebastien/remi/casey)
3. Commit + push
4. `gh pr create`
5. MAJ tache ClickUp

## Regles

- Scanner TOUS les projets, pas seulement le courant
- Ne pas modifier le code sans "fix" en argument
- Findings critiques generent toujours une tache ClickUp si configure
- Toujours indiquer fichier + ligne exacte
- Si pattern deja fixe dans un projet, mentionner comment (pour reproduire)
- Repondre en francais

Arguments : $ARGUMENTS
