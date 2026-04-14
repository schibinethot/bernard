# Workflow BERNARD — comment ca se passe concretement

Ce document decrit les workflows types avec le plugin, etape par etape. Remplace
"screenshots" tant que le plugin n'est pas installe chez des beta-testeurs.

---

## Workflow 1 — Matin d'un dev solo

**08:30 — Ouvrir Claude Code**
```
/briefing
```

Sortie :
```
BRIEFING | 2026-04-14 | 08:30

AGENDA
  10:00 — Call client AM (15 min)
  14:00 — Revue PR #234 CRM-ESC-PACK

EMAILS PRIORITAIRES (12 non lus)
  URGENT : 1 email Direction ("Facture urgente mai")
  A TRAITER : 3 emails clients (retards de livraison, question CGV)

CLICKUP
  Overdue : 2 taches — "[CRM-AUDIT] Emails primes" + "[AM] Photos couturiers"
  Due today : 1 tache — "Deployer feature X en preprod"

PROJETS
  ERP-AM : en prod, nurturing M3-M24 a construire
  APP-NELVO : Decision Engine SAV livre, tests E2E en cours

TOP 3 ACTIONS
  1. Repondre a l'email Direction (facture mai)
  2. Deployer feature X en preprod (avant call 10:00)
  3. Traiter les 2 taches ClickUp overdue
```

**08:45 — Discussion avec BERNARD pour prioriser**
```
/bernard j'ai 30 min avant le call, je fais quoi ?
```

BERNARD repond :
```
Tu as 3 options concretes :

1. Le deploy preprod — risque de bloquer le call si ca casse. Pas le moment.
2. L'email Direction — 5 min, evacue un blocker admin. Fais-le maintenant.
3. "[CRM-AUDIT] Emails primes" — 20 min si tu delegues a sebastien et tu checkes.

Ma reco : option 2 puis option 3. Le deploy preprod, tu le lances apres le call
pour pouvoir le suivre.

Tu veux que je lance sebastien sur les emails primes en parallele ?
```

**09:00 — Tu dis oui, BERNARD delegue**
BERNARD spawn SEBASTIEN avec le contexte du CDC-MASTER, de la tache ClickUp et du schema
BDD du module primes. SEBASTIEN code la route + le service + le test, committe, push.

**10:00 — Call. Pendant ce temps, SEBASTIEN a livre.**

---

## Workflow 2 — Debug de prod le vendredi soir

**18:42 — Alerte Railway : 5xx en hausse sur API Nelvo**

```
/bernard l'API Nelvo repond en 504 depuis 15 min, regarde
```

BERNARD (mode execution) delegue directement :
- LEO pour checker les logs Railway et l'etat du service
- CASEY en standby au cas ou ce serait une attaque

LEO lit les logs, identifie un memory leak dans un worker BullMQ, propose un rollback
vers la version stable precedente.

```
PRE-FLIGHT :
  [OK] Version precedente identifiee : sha abc1234
  [OK] Backup BDD verifie
  [OK] Aucune migration entre les deux versions

ETAPES :
  1. railway rollback --service nelvo-api --to abc1234
  2. Verifier /health → status ok
  3. Suivre error rate 10 min

RISQUE : perte des 23 derniers emails traites depuis le deploy buggue
ACTION CORRECTIVE : les reprendre manuellement via /api/reprocess (SEBASTIEN a la route)
```

**18:50 — Rollback fait, monitoring OK**

**19:00 — Tu lances :**
```
/retro
```

Et la retro identifie le pattern "memory leak BullMQ avec payload > 1MB". Learning stocke
en MCP. La prochaine fois, SEBASTIEN le detecte pendant le PR review.

---

## Workflow 3 — Nouvelle feature cross-equipe

**Lundi 09:00**
```
/bernard on veut ajouter "paniers abandonnes" au SITE-AM
```

BERNARD :
```
Je lance la chaine feature complete :
  - AURELIEN : specs (qui, quoi, pourquoi, hors-scope, criteres succes)
  - ONYX : design (modal de recuperation, email de relance)
  - MORGAN : archi (schema tables, endpoints, worker relance)
  - SEBASTIEN : backend (routes + cron relance)
  - REMI : front (integration modal + tracking)
  - ELENA : tests
  - LEO : deploy

Chaque agent travaille en autonomie. Je te ping quand c'est pret pour review.

Tu veux que je lance les 7 en parallele ou en cascade ?
```

Tu dis "cascade pour les deps logiques, parallele quand possible". BERNARD dispatch.

**Vendredi 17:00** — feature en preprod. Tu valides. Lundi suivant, en prod.

---

## Workflow 4 — Hebdomadaire — auto-amelioration

**Chaque vendredi 17:30**
```
/auto-improve
```

Le plugin :
1. Lance `/retro` sur les 7 derniers jours
2. Identifie 4 learnings HIGH (ex : "SEBASTIEN oublie les index sur les FK dans 20% des
   cas")
3. Applique les learnings dans les prompts des agents concernes (section "Learnings
   automatiques")
4. Compacte les memoires de plus de 14 jours
5. Lance `/cross-scan` leger
6. Te propose 2 taches ClickUp "bernard-proposal" a valider

Ratio de compression memoire : typiquement 60-70% apres la premiere execution mensuelle.

---

## Workflow 5 — Onboarding d'un nouveau client B-aaS

**Jour 1** — Le client installe le plugin depuis le marketplace prive.
**Jour 2** — Le client migre ses regles perso via `migrate-feedbacks` skill.
**Jour 3** — Le client utilise `/audit-project` sur son projet principal pour avoir le
premier CDC-MASTER auto-genere.
**Jour 7** — Premier `/auto-improve` — BERNARD commence a apprendre les patterns du client.
**Jour 30** — Le client a un systeme auto-ameliorant sur son projet, avec une memoire
persistante et 18 agents specialises.
