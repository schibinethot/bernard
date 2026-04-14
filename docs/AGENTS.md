# Les 18 agents de BERNARD

Reference detaillee de chaque agent : quand l'invoquer, ce qu'il produit, qui il consomme et
alimente.

## BERNARD — orchestrateur

**Modele** : opus
**Role** : sparring partner intellectuel + routeur vers les experts.
**Invoquer quand** : question transverse, reflexion strategique, arbitrage entre disciplines,
demande vague qui doit etre dispatchee.
**Produit** : conversation, avis, liens transverses, delegation 4 lignes.

## JULIA — CTO

**Modele** : opus
**Role** : decisions techniques strategiques, priorisation, build vs buy.
**Invoquer quand** : choix entre 2+ options tech, arbitrage cout / vitesse / qualite,
validation d'un gros changement d'architecture.
**Produit** : decision unique argumentee + risques + prochaines etapes.
**Consomme** : bernard (contexte), jordan (budget), casey (risques secu).
**Alimente** : morgan, sebastien, remi, leo.

## AURELIEN — Product Manager

**Modele** : sonnet
**Role** : user stories, specs fonctionnelles, scope / hors-scope.
**Invoquer quand** : nouvelle feature a specifier, backlog a prioriser, besoin de criteres
d'acceptation testables.
**Produit** : feature complete (objectif, US, parcours, regles, edge cases, hors-scope,
metriques de succes).
**Consomme** : utilisateur, thomas, jordan.
**Alimente** : morgan, onyx, elena.

## ONYX — designer UI/UX

**Modele** : opus
**Role** : maquettes + code TSX complet, design system, responsive, WCAG 2.2 AA.
**Invoquer quand** : nouvelle page, composant complexe, refonte visuelle, design d'un flow
onboarding / checkout.
**Produit** : code TSX complet pret a implementer avec Tailwind + shadcn-ui.
**Consomme** : aurelien (specs).
**Alimente** : remi.

## MORGAN — architecte systeme

**Modele** : opus
**Role** : schema BDD, endpoints API, structure fichiers, choix d'archi.
**Invoquer quand** : nouveau module a concevoir, refonte structurelle, choix pattern
(monolithe / microservices / workers).
**Produit** : plan d'architecture + schema + endpoints + ordre d'implementation.
**Consomme** : aurelien (specs).
**Alimente** : sebastien, remi, onyx (contraintes).

## REMI — frontend

**Modele** : sonnet
**Role** : composants React, hooks, integration API, Tailwind.
**Invoquer quand** : implementer une page, un composant, une integration API cote front.
**Produit** : code React / TSX complet avec tous les etats geres.
**Consomme** : onyx (design), morgan (endpoints).
**Alimente** : elena, leo.

## SEBASTIEN — backend

**Modele** : opus
**Role** : routes, services, BDD, pipelines LLM.
**Invoquer quand** : implementer un endpoint, un service, un schema Drizzle, une integration
LLM, un job BullMQ.
**Produit** : code TS complet : schema → validation Zod → service → route → test.
**Consomme** : morgan (archi), aurelien (specs).
**Alimente** : elena, leo.

## LEO — DevOps

**Modele** : sonnet
**Role** : deploiements, Docker, CI/CD, migrations, incidents.
**Invoquer quand** : deployer, ecrire un Dockerfile, configurer Railway / Fly.io, migrer une
BDD, gerer un incident prod.
**Produit** : checklist pre-flight + etapes numerotees + verification post-deploy.
**Consomme** : sebastien (code), elena (tests).
**Alimente** : bernard (statut).

## ELENA — QA

**Modele** : sonnet
**Role** : tests unitaires, integration, E2E, detection de bugs.
**Invoquer quand** : ecrire des tests, auditer la couverture, reproduire un bug.
**Produit** : tableau de resultats + tests ecrits + bugs trouves + recommandations.
**Consomme** : sebastien (backend), remi (frontend).
**Alimente** : leo (feu vert deploy), casey (si faille).

## CASEY — cybersecurite

**Modele** : opus
**Role** : audit secu, threat model, CVE, OWASP.
**Invoquer quand** : audit secu d'un module, nouvelle feature sensible (auth, paiement,
upload), revue avant mise en prod.
**Produit** : audit avec score global + vulnerabilites + deps + config + actions prioritaires.
**Consomme** : leo (infra), claire (CVE).
**Alimente** : sebastien (fixes), rebecca (conformite).

## IRIS — data analyst

**Modele** : sonnet
**Role** : SQL, metriques, dashboards, analyses.
**Invoquer quand** : question chiffree, dashboard a specifier, analyse de cohorte, verif
d'une hypothese avec les donnees.
**Produit** : requete SQL + resultats + interpretation + recommandation.
**Consomme** : jordan, thomas, aurelien.
**Alimente** : remi (specs dashboard), jordan (chiffres).

## JORDAN — CFO

**Modele** : sonnet
**Role** : budget, tresorerie, unit economics, projections.
**Invoquer quand** : analyse financiere, pricing, projection 12 mois, runway, cout d'une
feature.
**Produit** : hypotheses + unit economics + projections + risques + recommandations.
**Consomme** : thomas (pipeline), iris (usage).
**Alimente** : bernard (sante), julia (viabilite), rebecca (fiscal).

## THOMAS — commercial

**Modele** : sonnet
**Role** : strategie commerciale, ICP, pricing, plan 30/60/90.
**Invoquer quand** : nouveau produit a commercialiser, ICP a affiner, pipeline a qualifier,
pricing a definir.
**Produit** : ICP + pricing + canaux + plan + KPIs.
**Consomme** : aurelien, jordan.
**Alimente** : laure, onyx, mika.

## LAURE — SEO

**Modele** : sonnet
**Role** : audit technique, contenu, Core Web Vitals, structured data.
**Invoquer quand** : audit SEO d'un site, nouvelle page landing, optimisation ranking, ajout
de JSON-LD.
**Produit** : audit score /10 + actions prioritaires avec code exact.
**Consomme** : claire, thomas.
**Alimente** : remi, sebastien.

## MIKA — paid ads

**Modele** : opus
**Role** : Meta Ads, Google Ads, strategie paid, tracking.
**Invoquer quand** : nouvelle campagne, audit de compte existant, definition budget, choix
de plateforme.
**Produit** : strategie + architecture campagnes + creatives + KPIs + plan de test 30j.
**Consomme** : thomas, jordan, aurelien.
**Alimente** : onyx (creatives), iris (dashboards).

## REBECCA — juridique

**Modele** : opus
**Role** : RGPD, AI Act, NIS2, contrats, conformite e-commerce.
**Invoquer quand** : nouveau traitement de donnees, signature d'un contrat, mise en
conformite, gestion d'un incident donnees.
**Produit** : analyse + textes applicables + etat conformite + recommandations + besoin
d'avocat oui/non.
**Consomme** : casey (technique).
**Alimente** : sebastien (implementation droits).

## CLAIRE — veille tech generaliste

**Modele** : haiku
**Role** : actualites stack, CVE, tendances, deprecations.
**Invoquer quand** : briefing hebdo veille, alerte CVE, nouvelle version majeure d'un outil
du stack.
**Produit** : breaking / tendance / risk / a surveiller, avec sources verifiables.
**Alimente** : bernard, casey, laure, sebastien, nova.

## NOVA — veille AI tooling

**Modele** : sonnet
**Role** : AI tooling, LLMs, frameworks agents, MCP, RAG, coding tools.
**Invoquer quand** : evaluer un nouvel outil AI, comparer LLMs, detecter une migration AI
pertinente.
**Produit** : releases + combos recommandes + migrations + setup optimal + reco priorisees.
**Consomme** : claire (tendances).
**Alimente** : sebastien, remi, morgan, casey, julia.

---

## Patterns de collaboration 2026

### Pattern "feature complete"
```
aurelien (specs) → morgan (archi) → (onyx design + sebastien backend en parallele)
  → remi (front) → elena (tests) → leo (deploy)
```

### Pattern "audit secu"
```
casey (audit) → sebastien (fix backend) → remi (fix front) → elena (regression)
  → leo (deploy)
```

### Pattern "decision strategique"
```
bernard (framing) → claire ou nova (data marche) → julia (decision)
  → jordan (impact cout) → equipe execution
```

### Pattern "veille automatique"
```
claire (detection breaking) → casey (si CVE) ou nova (si AI tool) → bernard (synthese)
  → julia (decision go/no-go migration)
```
