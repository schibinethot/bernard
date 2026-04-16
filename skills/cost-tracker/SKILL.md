---
name: cost-tracker
description: Analyse et estime les couts LLM par agent, par modele et par projet via les donnees MCP agent-memory. Utilise la grille tarifaire Anthropic, le routing modele par agent et les hypotheses tokens par type d'interaction pour produire un cost report markdown avec totaux, marge budget et recommandations d'optimisation.
version: 0.5.0
tags: [cost, analytics, llm, observability]
---

# Cost Tracker : estimation couts LLM par agent

Estime les couts d'utilisation LLM de l'equipe BERNARD sur une periode donnee, en croisant les donnees d'activite MCP agent-memory avec la grille tarifaire Anthropic et le routing modele par agent.

**Core principle :** pas de compteur de tokens reel (pas d'acces API billing). On estime via le volume d'interactions et des hypotheses tokens par type. L'estimation est conservative (fourchette haute) pour eviter les surprises.

**Announce at start :** "Je declenche la skill cost-tracker pour estimer les couts LLM sur la periode."

## Sources de donnees

| Source MCP | Usage |
|---|---|
| `list_agents_activity(days)` | Volume interactions sent/received par agent |
| `list_interactions(since, limit)` | Detail interactions avec timestamps, types, agents source/dest |
| `get_memories(agent, "token usage cost model")` | Knowledge historiques sur les couts et consommations |

## Grille de prix Anthropic (avril 2026)

| Modele | Input $/1M tokens | Output $/1M tokens | Cache Read $/1M | Cache Write $/1M |
|---|---|---|---|---|
| Opus 4.6 | $15.00 | $75.00 | $1.50 | $18.75 |
| Sonnet 4.6 | $3.00 | $15.00 | $0.30 | $3.75 |
| Haiku 4.5 | $0.80 | $4.00 | $0.08 | $1.00 |

**Note :** ces prix sont ceux d'avril 2026. Les verifier periodiquement sur https://docs.anthropic.com/en/docs/about-claude/models pour mise a jour.

## Routing modeles par agent

Base sur `feedback_agent_models.md` :

| Tier | Modele | Agents | Count |
|---|---|---|---|
| **Opus** | claude-opus-4-6 | BERNARD, JULIA, MORGAN, SEBASTIEN, CASEY, REBECCA, ONYX, MIKA, NOVA | 9 |
| **Sonnet** | claude-sonnet-4-6 | AURELIEN, REMI, LEO, JORDAN, THOMAS, LAURE, IRIS, ELENA | 8 |
| **Haiku** | claude-haiku-4-5 | CLAIRE | 1 |

Total : 18 agents.

## Hypotheses tokens par type d'interaction

Estimation par defaut (ajustable selon retours) :

| Type interaction | Input tokens | Output tokens | Ratio I/O |
|---|---|---|---|
| Delegation | ~8,000 | ~4,000 | 2:1 |
| Review | ~6,000 | ~2,000 | 3:1 |
| Question | ~3,000 | ~1,000 | 3:1 |
| Validation | ~4,000 | ~1,000 | 4:1 |
| Default (non-type) | ~5,000 | ~2,000 | 2.5:1 |

Ces hypotheses supposent des interactions standard Claude Code. Pour les sessions longues (debugging, refactoring), multiplier par 2-3x.

## Formules de calcul

```
# Par interaction
cout_interaction = (input_tokens / 1M × prix_input) + (output_tokens / 1M × prix_output)

# Par agent
cout_agent = SUM(cout_interactions_agent)

# Par projet (si disponible via metadata)
cout_projet = SUM(cout_agents_projet)

# Total periode
cout_total = SUM(cout_agents)

# Avec cache (estimation : ~60% cache read en moyenne)
cout_cache_optimise = cout_total × 0.55  # reduction estimee avec caching
```

## Workflow

### Step 1 : Determiner la periode

Demander a l'utilisateur ou prendre par defaut **7 jours**.

```
Periode d'analyse : X jours (default: 7)
```

### Step 2 : Recuperer l'activite par agent

```
list_agents_activity(days=7)
```

Resultat attendu : liste d'agents avec `sent` et `received` counts.

### Step 3 : Recuperer le detail des interactions

```
list_interactions(since="2026-04-07T00:00:00Z", limit=500)
```

Classifier chaque interaction par type si le champ `type` est disponible. Sinon, utiliser "Default".

### Step 4 : Router chaque agent vers son modele

Appliquer le mapping de la section "Routing modeles par agent" ci-dessus. Si un agent inconnu apparait, appliquer Sonnet par defaut (tier moyen).

### Step 5 : Calculer les estimations

Pour chaque agent :
1. Compter les interactions (sent + received, sans double-comptage)
2. Appliquer les hypotheses tokens selon le type
3. Multiplier par le prix du modele assigne
4. Sommer

### Step 6 : Generer le tableau markdown

Format de sortie ci-dessous.

### Step 7 : Comparer au budget

Plans Bernard-as-a-Service :
| Plan | Prix/mois | Budget hebdo estime |
|---|---|---|
| Solo | 149 EUR (~$162) | ~$40/semaine |
| Agence | 599 EUR (~$651) | ~$163/semaine |
| Scale | 1,990 EUR (~$2,163) | ~$541/semaine |

Calculer la marge :
```
marge = ((budget_hebdo - cout_estime) / budget_hebdo) × 100
```

### Step 8 : Recommandations

Analyser les resultats et proposer :
- **Downgrade** : agents avec < 5 interactions/semaine sur Opus → candidats Sonnet
- **Gros consommateurs** : agents avec > 30% du cout total → investiguer
- **Cache** : si ratio cache faible, recommander prompt caching
- **Batching** : interactions nombreuses courtes → fusionner les delegations
- **Cron awareness** : les crons (email, sync) generent un cout continu → ref skill `am-sql-preprod-deploy` et `email-cron-create`

## Format sortie attendu

```markdown
## Cost Report : {periode}

### Par agent

| Agent | Modele | Interactions | Est. Input | Est. Output | Cout estime |
|---|---|---|---|---|---|
| BERNARD | opus-4-6 | 29 | ~232K | ~116K | ~$12.18 |
| SEBASTIEN | opus-4-6 | 12 | ~96K | ~48K | ~$5.04 |
| IRIS | sonnet-4-6 | 8 | ~40K | ~16K | ~$0.36 |
| CLAIRE | haiku-4-5 | 15 | ~75K | ~30K | ~$0.18 |
| ... | | | | | |

### Totaux

| Metrique | Valeur |
|---|---|
| **Total estime** | $XX.XX |
| **Budget {plan} ({prix}/mois)** | ~$XX/semaine |
| **Marge estimee** | XX% |
| **Cout moyen/interaction** | $X.XX |
| **Agent le plus couteux** | {agent} ($XX.XX, XX%) |

### Top 3 agents par cout

1. **{agent}** : $XX.XX (XX% du total) : {nb} interactions sur {modele}
2. ...
3. ...

### Recommandations

- [ ] {recommandation 1}
- [ ] {recommandation 2}
- [ ] ...
```

## Edge cases

| Cas | Action |
|---|---|
| Agent inconnu (pas dans le routing) | Appliquer Sonnet par defaut + warning |
| Zero interactions sur la periode | Reporter "Aucune activite" pour l'agent |
| Interaction sans type | Classer en "Default" (5K input / 2K output) |
| Periode > 30 jours | Avertir que l'estimation perd en precision |
| Donnees MCP indisponibles | Fallback sur les derniers chiffres connus ou demander a l'utilisateur |

## Red Flags

**Ne JAMAIS :**
- Presenter l'estimation comme un cout exact (toujours prefixer par "~" ou "estime")
- Ignorer le routing modele (un agent Opus facture 5x Sonnet et 19x Haiku)
- Oublier le double-comptage : une interaction = 1 envoi + 1 reception, compter UNE seule fois
- Utiliser des prix obsoletes sans les verifier

**Toujours :**
- Afficher la periode d'analyse et la date du rapport
- Preciser les hypotheses tokens utilisees
- Mentionner le ratio cache si applicable
- Proposer au moins une recommandation actionnable
- Comparer au budget si le plan est connu

## Integration

**Dashboard `/observability`** : le composant `CostTracker` dans bernard-app (commit 9d7d928) affiche les estimations cote frontend. Ce skill fournit la logique d'estimation et la grille de prix que le dashboard consomme.

**Agents concernes :**
- IRIS (data, analytics, execution du skill)
- BERNARD (orchestration, suivi couts equipe)
- JORDAN (finance, validation budget/marge)
- JULIA (CTO, decisions routing modeles)

**Pairs avec :**
- `am-sql-preprod-deploy` (estimation cout crons continus)
- `email-cron-create` (cout recurrent crons email)
- Dashboard `/observability` (visualisation frontend)

## Reference

- Source : roadmap plugin v0.5 (P0)
- Grille tarifaire : https://docs.anthropic.com/en/docs/about-claude/models
- Routing modeles : `feedback_agent_models.md`
- Dashboard : bernard-app `/observability` (CostTracker composant, commit 9d7d928)
- Plans pricing : Bernard-as-a-Service (Solo 149 EUR / Agence 599 EUR / Scale 1,990 EUR)
