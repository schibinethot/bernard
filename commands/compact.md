---
description: Compaction des memories - Fusionne les anciennes memories en resumes consolides pour garder le contexte dense et pertinent
argument-hint: [agent | dry | vide=tous]
---

Tu es BERNARD en mode compaction. Nettoyer et consolider les memories pour eviter l'accumulation de bruit et garder un contexte toujours dense.

## Processus

### 1. Inventorier

Pour chaque agent actif (ou celui specifie dans $ARGUMENTS) :
- `mcp__agent-memory__get_memories` avec query="*" limit=20
- `mcp__agent-memory__list_agents_activity` avec since_hours=720 (30j)

Criteres de compaction :
- Age : memories > 14j
- Redondance : plusieurs memories qui disent la meme chose
- Obsolescence : info contredite par une memory plus recente
- Faible importance : importance < 0.3

### 2. Grouper par theme

Par agent, regrouper anciennes memories :
- Architecture / decisions techniques
- Bugs / fixes
- Performance / metriques
- Retros / learnings
- Routing / coordination

### 3. Consolider

Pour chaque groupe de 3+ memories du meme theme :

Generer un resume consolide :
- Fusionner les informations en un seul texte dense
- Conserver les dates cles et les decisions
- Supprimer les details ephemeres (logs de debug, accuses de reception)
- Garder learnings et patterns

Stocker le resume :
- `mcp__agent-memory__store_memory` agent="{NOM}", event_type="learning", summary="[COMPACT] {resume}", importance=0.7
- `mcp__agent-memory__store_knowledge` category="agent_compacted" si contenu reutilisable

Marquer les anciennes superseded :
- Pour chaque knowledge consolidee, `mcp__agent-memory__supersede_knowledge`

### 4. Compacter les knowledge aussi

Pour shared_knowledge : chercher entries du meme category+projet qui se chevauchent, fusionner en 1, supersede les anciennes.

### 5. Rapport

```
## Compaction [date]
### Avant — nb memories, nb knowledge, age moyen
### Actions — tableau Agent/Memories compactees/Resumes/Knowledge superseded
### Apres — nouveaux totaux, ratio compression
```

### 6. Sauvegarder

`mcp__agent-memory__store_memory` agent="BERNARD", event_type="learning", summary="Compaction [date] : [X] memories → [Y] resumes, [Z] knowledge superseded".

## Modes

- `/compact` : compaction complete tous agents
- `/compact SEBASTIEN` : un seul agent
- `/compact dry` : simulation sans modification

## Regles

- JAMAIS supprimer une memory sans la consolider d'abord
- Memories < 7j : JAMAIS compactees
- Memories importance >= 0.8 : JAMAIS compactees (decisions critiques)
- Learnings issus de retros : JAMAIS compactes
- En cas de doute, garder
- Mode "dry" recommande pour le premier usage
- Repondre en francais

Arguments : $ARGUMENTS
