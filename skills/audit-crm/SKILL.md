---
name: audit-crm
description: Audit fonctionnel dedie aux projets CRM / ERP multi-modules (Express + React + PostgreSQL). Verifie routes backend, storage, composants frontend, schema BDD pour chaque feature du CDC. A utiliser quand l'utilisateur demande d'auditer un CRM, un ERP ou un projet multi-modules contre son cahier des charges.
version: 1.0.0
---

# Audit fonctionnel CRM / ERP

Audite systematiquement un projet CRM / ERP (stack Express + React + PostgreSQL typique) en comparant l'etat reel du code contre le cahier des charges.

## Phase 1 : Chargement contexte

1. Lire `documentations/CDC-MASTER.md` (checklist complete)
2. Identifier items `[?]` (a verifier) et `[~]` (partiel)
3. Priorite : `[?]` d'abord, puis `[ ]` (non implemente)

## Phase 2 : Verification systematique

Pour chaque item `[?]` ou `[~]`, verifier :

**Backend** :
- Route dans `server/routes/*.ts` ou sous-dossier module (ex. `server/crm/crm-routes.ts`) ?
- Storage layer avec la methode dans `server/*/storage.ts` ?
- Logique metier complete (pas juste stub/TODO) ?

**Frontend** :
- Composant/page dans `client/src/pages/` ou `src/pages/` ?
- Rend du contenu reel (pas un placeholder) ?
- Appels API via TanStack Query ?

**Data** :
- Table dans `shared/schema.ts` (Drizzle) ou equivalent ?
- Champs requis presents ?
- Enums complets par rapport au CDC ?

## Phase 3 : Tests fonctionnels

1. `npm run check` — verifier les types
2. Si erreurs bloquantes : les noter comme findings

## Phase 4 : Mise a jour CDC-MASTER.md

Pour chaque item verifie :
- `[?]` → `[x]` si confirme fonctionnel
- `[?]` → `[~]` si partiellement implemente (preciser ce qui manque)
- `[?]` → `[ ]` si finalement non implemente
- Ajouter notes dans la colonne Notes

## Phase 5 : Creation taches ClickUp (si MCP disponible)

Pour chaque gap :
- Tag : `bernard-proposal`
- Titre : `[CRM-AUDIT] {description courte}`
- Description : impact, fichiers concernes, effort, plan
- Priorite selon impact (critical, high, normal, low)

Grouper par module.

## Phase 6 : Rapport

```
AUDIT {PROJET} | [date] | [total] features | [ok] OK | [partial] partiels | [missing] manquants

TOP 5 GAPS CRITIQUES :
1. ...

MODULES LES PLUS AVANCES : ...
MODULES LES PLUS EN RETARD : ...

TACHES CLICKUP CREEES : [nb]
```

## Regles

- Ne modifie PAS le code du projet — audit + MAJ CDC-MASTER.md uniquement
- Factuel, pas de suppositions
- Items design : lire CSS/Tailwind et comparer aux tokens de la charte
- 1 tache par module complet si non implemente
- Commence par modules a plus fort impact business (Emails, Primes, Ops commerciales, etc.)
- Repondre en francais
