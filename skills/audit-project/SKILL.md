---
name: audit-project
description: Audit fonctionnel generique d'un projet. Compare l'etat reel du code contre son cahier des charges (CDC-MASTER.md ou equivalent), met a jour les statuts et propose des taches a creer. A utiliser quand l'utilisateur demande un audit d'un projet, de verifier la couverture fonctionnelle, ou de comparer code vs specs.
version: 1.0.0
---

# Audit fonctionnel generique

Audite systematiquement le projet du repertoire courant en comparant l'etat reel du code contre son cahier des charges.

## Phase 0 : Detection du contexte

1. Identifier le projet : `CLAUDE.md`, `README.md`, `package.json`
2. Trouver le CDC dans cet ordre :
   - `documentations/CDC-MASTER.md` (reference unique)
   - `documentations/*.md`
   - `docs/*.md`
   - `attached_assets/*.docx` (convertir via `textutil -convert txt -stdout`)
   - Si aucun CDC : demander a l'utilisateur

3. Si CDC-MASTER.md absent, le creer depuis les specs trouvees avec ce format :

```markdown
| Feature | CDC | Statut | Route/Fichier | Notes |
|---------|-----|--------|---------------|-------|
| Description feature | Source | [x]/[~]/[ ]/[?] | Chemin | Details |
```

Statuts :
- `[x]` Implemente et fonctionnel
- `[~]` Partiellement (preciser ce qui manque)
- `[ ]` Non implemente
- `[?]` A verifier

## Phase 1 : Verification systematique

Pour chaque item `[?]` ou `[~]`, adapter au stack :
- Node/Express : routes, storage, middleware
- Next.js : pages, API routes, components
- Python/Django : views, models, serializers

Verifier :
- Le code existe (pas juste un fichier vide ou stub)
- La logique est complete (pas de TODO, pas de mock)
- Les dependances sont presentes (tables DB, endpoints, composants)

## Phase 2 : Tests rapides

1. `npm run check` ou equivalent — noter les erreurs de build
2. `npm test` si tests presents

## Phase 3 : Mise a jour CDC-MASTER.md

Pour chaque item verifie : MAJ statut + notes precises.

## Phase 4 : Creation taches ClickUp (si MCP ClickUp disponible)

Pour chaque gap significatif :
- Tag : `bernard-proposal`
- Titre : `[AUDIT-{NOM_PROJET}] {description courte}`
- Description : impact, fichiers concernes, effort estime, plan
- Grouper par module (1 tache par module manquant, pas 1 par sous-feature)

## Phase 5 : Rapport

```
AUDIT {NOM_PROJET} | {date}
{nb total} features | {ok} OK | {partial} partiels | {missing} manquants

COUVERTURE : {pourcentage}%

TOP GAPS :
1. {module} — {description} — effort: {estimation}

PROCHAINES ACTIONS RECOMMANDEES :
1. ...
```

## Regles

- NE MODIFIE PAS le code — audit seulement + CDC-MASTER.md
- Factuel : base sur le code, pas sur des suppositions
- Priorise par impact business, pas par difficulte technique
- 1 tache ClickUp par module manquant
- Commence par les modules critiques du CDC
- Repondre en francais
