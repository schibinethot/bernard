---
name: simplify
description: Review du code modifie pour detecter de la duplication, des patterns sur-complexes, des abstractions premature, et proposer une version plus simple sans perte de fonctionnalite. A utiliser apres une vague de modifications, avant une PR, ou quand le code commence a sentir mauvais.
version: 1.0.0
---

# Simplify — revue de simplification

Passe en revue le code recemment modifie pour detecter les opportunites de simplification, puis corrige les problemes identifies.

## Quand declencher

- Apres une vague de modifications sur un module
- Avant une pull request
- Quand l'utilisateur dit "ca devient complique", "c'est deja fait ailleurs", "simplifie"
- Quand plusieurs fichiers similaires apparaissent

## Methodologie

### 1. Cartographier les changements

- `git diff --name-only` et `git diff` pour voir ce qui a ete modifie
- Lire les fichiers touches ET leurs tests

### 2. Chercher les signaux de complexite

**Duplication**
- Meme bloc de code copie plusieurs fois (> 3 lignes)
- Fonctions avec 80% du meme corps et 20% de difference
- Patterns repetes (validation, mapping, error handling)

**Abstractions premature**
- Interfaces/types avec une seule implementation
- Factories, adapters, facades sans justification concrete
- Generiques `T extends Y` utilises pour un seul cas

**Accumulation**
- Fonctions > 60 lignes
- Fichiers > 400 lignes
- Chaines `.then().then().then()` sur 5+ niveaux
- Conditions imbriquees > 3 niveaux

**Anti-patterns specifiques**
- `any` en TypeScript
- `console.log` restes dans le code
- Magic numbers sans constantes nommees
- Commentaires `// TODO` sans ticket associe

### 3. Verifier la reutilisation

Avant d'ajouter du code :
- Le projet a-t-il deja une fonction qui fait ca ? (`grep` sur la description)
- Une librairie deja installee le fait-elle ? (`package.json`)
- Un composant shadcn/ui equivalent existe-t-il ?

### 4. Proposer et corriger

Pour chaque probleme trouve, produire :

```
### [Fichier:lignes]
**Probleme** : [description]
**Impact** : [pourquoi c'est un probleme]
**Fix** : [code de remplacement]
```

Puis appliquer les fixes en ordre d'impact decroissant.

### 5. Validation

- Lancer les tests (`npm test` ou equivalent)
- Verifier les types (`npm run check`)
- Lire le diff final et verifier qu'aucune fonctionnalite n'est perdue

## Regles

- Ne PAS reecrire ce qui marche juste pour "faire plus beau"
- Preferer supprimer du code plutot que d'en ajouter
- Garder les commentaires qui expliquent le "pourquoi", supprimer ceux qui expliquent le "quoi"
- Ne jamais introduire d'abstraction pour < 3 cas d'usage concrets
- Ne pas fusionner des fonctions qui ont des raisons de changer differentes
- Repondre en francais
