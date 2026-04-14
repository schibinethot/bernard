---
name: migrate-feedbacks
description: Template pour migrer les feedbacks utilisateur (regles personnelles, preferences, patterns recurrents) d'un systeme local en memoires MCP agent-memory structurees, taguees et recherchables. A utiliser quand l'utilisateur veut injecter ses regles ou decisions passees dans la memoire partagee des agents.
version: 1.0.0
---

# Migration feedbacks vers agent-memory

Ce template gere la migration des feedbacks utilisateur (fichiers `feedback_*.md` ou notes perso) vers le MCP agent-memory pour qu'ils soient accessibles a tous les agents.

## Contexte

Un feedback utilisateur est une regle, une preference ou un pattern recurrent que l'utilisateur a exprime au moins une fois et veut voir applique systematiquement. Exemples : "jamais de git push --force", "toujours valider les inputs avec Zod", "captions sociales en francais sans tiret cadratin".

Ces feedbacks doivent etre :
1. Stockes en memoire MCP (pas en markdown local)
2. Tagues par agent concerne (BERNARD, SEBASTIEN, etc.)
3. Recherchables par query (semantic ou keyword)
4. Appliques en debut de conversation via `get_memories`

## Processus

### 1. Inventorier les feedbacks existants

Chercher dans le repertoire courant et `~/.claude/projects/-*/memory/` :
- Fichiers `feedback_*.md`
- Sections "Feedbacks" dans les CLAUDE.md
- Regles recurrentes dans les memoires perso

Pour chaque feedback, extraire :
- Titre court
- Regle (1-3 phrases)
- Agent(s) concernes (ou "tous")
- Contexte d'application (quand / comment)

### 2. Categoriser

Classer chaque feedback :
- `rule_critical` : regle qui si violee casse qqch (prod, client, legal)
- `rule_workflow` : preference de methode (4 lignes delegation, francais, etc.)
- `rule_business` : regle metier (AM = boutique pas e-commerce)
- `learning` : pattern appris d'une erreur passee

### 3. Structurer pour MCP

Format cible :

```json
{
  "agent": "BERNARD|SEBASTIEN|...|SHARED",
  "event_type": "learning",
  "summary": "<1-2 phrases : la regle>",
  "importance": 0.7-1.0,
  "metadata": {
    "feedback_id": "<slug>",
    "category": "rule_critical|rule_workflow|rule_business|learning",
    "keywords": ["..."],
    "source_date": "YYYY-MM-DD"
  }
}
```

Regles d'importance :
- `rule_critical` : 1.0
- `rule_business` : 0.9
- `rule_workflow` : 0.8
- `learning` : 0.7

### 4. Injecter dans agent-memory

Pour chaque feedback structure :

```
mcp__agent-memory__store_memory avec :
  agent = <agent concerne>
  event_type = "learning"
  summary = <la regle>
  importance = <0.7-1.0>
```

Si le feedback concerne plusieurs agents : repliquer pour chacun, OU utiliser `mcp__agent-memory__store_knowledge` avec `category = "user_feedback"` pour un stockage partage.

### 5. Verifier le rappel

Pour chaque feedback injecte :
- Lancer une question test qui devrait le declencher
- Appeler `mcp__agent-memory__get_memories` avec query proche
- Confirmer que le feedback remonte dans les 5 premiers resultats

Si le feedback ne remonte pas, enrichir ses `keywords` ou reformuler le `summary`.

### 6. Archiver le feedback local

Une fois confirme en memoire :
- Renommer `feedback_xxx.md` en `feedback_xxx.md.migrated` (horodate)
- Ajouter une ligne en tete : `# MIGRATED to agent-memory on YYYY-MM-DD as <memory_id>`
- Optionnel : supprimer apres 30 jours

## Regles

- NE JAMAIS supprimer un feedback local avant confirmation du rappel MCP
- Chaque feedback migre doit avoir un `feedback_id` unique pour traabilite
- Les feedbacks "critical" (jamais de git push --force, etc.) restent AUSSI en hook bash (defense en profondeur)
- Maximum 3-5 nouveaux feedbacks/jour par agent (regle memory_hygiene)
- Si un feedback est redondant avec une regle deja en memoire : supersede plutot qu'ajouter
- Repondre en francais
