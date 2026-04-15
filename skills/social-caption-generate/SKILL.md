---
name: social-caption-generate
description: Genere une caption social media AM (Instagram / Facebook / LinkedIn) conforme aux regles editoriales Atelier Mesure. A utiliser par MIKA, ONYX ou tout agent qui redige un post reseau social AM avant publication via PostProxy. Controle : francais sur tout le texte narratif, interdiction du tiret cadratin, hashtags EN autorises, ton Charvet / Hermes, arrondissement Paris 7e, formulations interdites (a la main, nos couturiers), CTA subtil (RDV boutique, jamais e-commerce).
version: 0.4.0
tags: [social, content, am, marketing]
---

# Generation caption social media Atelier Mesure

Checklist obligatoire avant toute publication Instagram / Facebook / LinkedIn pour AM. Ton Charvet / Hermes, francais narratif, hashtags EN autorises, CTA subtil oriente RDV en boutique 7e arrondissement.

**Core principle :** AM = maison de sur-mesure haut de gamme, pas e-commerce. La caption reflete le temps long, l'artisanat partenaire, la discretion. Pas de performance marketing criarde.

**Announce at start :** "Je declenche la skill social-caption-generate pour rediger une caption conforme aux regles AM."

## Prerequis

- Brief utilisateur : type de produit (costume, chemise, accessoire), plateforme cible, angle narratif (savoir-faire, rendez-vous, coulisses, tissu).
- URL photo Cloudinary si fournie (pattern attendu : `res.cloudinary.com/<cloud>/image/upload/...`).
- Connaissance de la reference `feedback_social_content_rules` (stockee en memoire agent).

## Checklist de conformite

### Step 1 — Francais narratif

**Obligatoire :** tout le texte de la caption est en francais, sans anglicisme gratuit.

**Exception :** les hashtags peuvent etre en anglais (cf step 3).

**Interdit :** "drop", "must-have", "outfit", "new collection" en plein corps de texte.

**Remplacer par :** "nouvelle piece", "indispensable", "silhouette", "nouvelle saison".

### Step 2 — Tiret cadratin interdit

**Interdit :** `—` (em dash) et `–` (en dash) dans toute la caption.

**Raison :** marque typographique "AI generated", rendu inconsistant selon les clients, casse le ton haut de gamme.

**Remplacer par :** parenthese `( )`, deux points `:`, virgule, ou point.

**Verification grep :**
```bash
grep -cE "[—–]" <caption>
```
Resultat attendu : 0.

### Step 3 — Hashtags en anglais autorises

**Autorise :** hashtags EN sectoriels et universels.
- `#menswear` `#bespoke` `#tailoring` `#craftsmanship` `#savoirfaire`
- `#parismensstyle` `#madeinfrance` `#suitlovers` `#wool` `#fabric`

**A eviter :** hashtags FR fades (`#mode`, `#homme`, `#style`) qui diluent l'audience et sonnent cheap.

**Quantite par plateforme :**
- Instagram : 5 a 8 hashtags, en fin de caption, separes par des line breaks.
- Facebook : 3 a 5 hashtags max (l'algo FB ne les valorise pas).
- LinkedIn : 3 hashtags max, integres naturellement ou en fin.

### Step 4 — Formulations interdites (vocabulaire fabrication)

**Interdit :** "a la main" (Gerber est la marque de coupe automatisee partenaire, ecrire "a la main" est factuellement faux).

**Remplacer par :** "sur mesure", "artisanal", "cousu main" (uniquement pour les finitions reellement cousues main comme boutonnieres), "realise avec precision".

**Verification grep :**
```bash
grep -iE "(a la main|a-la-main)" <caption>
```
Si match : corriger.

### Step 5 — Pas d'appropriation des ateliers partenaires

**Interdit :** "nos couturiers", "nos tailleurs", "nos artisans", "notre atelier de fabrication".

**Raison :** AM ne possede pas l'atelier. Les couturiers travaillent chez les partenaires (GoCreate et autres). S'approprier leur travail est une erreur de communication.

**Remplacer par :** "les couturiers", "les artisans", "les ateliers partenaires", "l'atelier".

**Verification grep :**
```bash
grep -iE "nos (couturiers|tailleurs|artisans|brodeurs)" <caption>
grep -iE "notre atelier" <caption>
```
Si match : corriger.

### Step 6 — Arrondissement Paris 7e

**Obligatoire :** la boutique AM est **Paris 7e arrondissement** (rive gauche).

**Interdit :** toute mention du 10e, du Marais ou d'un autre quartier.

**Formulations correctes :**
- "RDV en boutique Paris 7e"
- "Nos salons du 7e arrondissement"
- "Essayage rive gauche"

**Verification grep :**
```bash
grep -iE "(10e|10eme|dixieme|marais)" <caption>
```
Resultat attendu : 0.

### Step 7 — Photos Cloudinary optimisees

**Si une URL Cloudinary est referencee :** transformations obligatoires `w_600,q_auto,f_auto` pour thumbnails.

**Pattern correct :**
```
https://res.cloudinary.com/am-cloud/image/upload/w_600,q_auto,f_auto/v123/atelier-coupe.jpg
```

**Pattern incorrect :**
```
https://res.cloudinary.com/am-cloud/image/upload/v123/atelier-coupe.jpg
```

**Verification grep :**
```bash
grep -oE "res\.cloudinary\.com[^\"'\)]+" <caption> | grep -vE "w_600,q_auto,f_auto"
```
Si une URL ressort : non optimisee.

### Step 8 — Ton et CTA

**Obligatoire :**
- Ton Charvet / Hermes : premium, intemporel, patience, matiere.
- Pas de premiere personne excessive ("je", "nous") ; privilegier l'objet ou le savoir-faire.
- Emoji parcimonieux (zero sur LinkedIn, un maximum de 1 discret sur IG / FB si vraiment utile).
- CTA subtil oriente RDV en boutique.

**Interdit :**
- "Achetez maintenant", "Shop now", "Commandez"
- "Promo", "Soldes", "-X%", comptes a rebours
- Emoji criards (`🔥🔥🔥`, `💯`, `🚨`)
- Ponctuation excessive (`!!!`, `???`)

**Remplacer par :**
- "Prise de mesures sur rendez-vous"
- "RDV en boutique Paris 7e"
- "Nous vous accueillons du mardi au samedi"

## Templates par plateforme

### Instagram (feed / carrousel)

**Format :** ~125-150 mots, hook visuel + story matiere, 5-8 hashtags en fin de caption separes par line breaks.

**Structure :**
1. Hook accrocheur (1 phrase, visuel ou sensoriel)
2. Corps 3-5 phrases : matiere, savoir-faire, process
3. CTA subtil (RDV boutique)
4. Line break
5. Hashtags EN (5-8), un par ligne ou regroupes

### Facebook

**Format :** 200-300 mots, ton plus narratif, contexte + detail technique + invitation.

**Structure :**
1. Hook narratif (2 phrases)
2. Corps 4-6 phrases : contexte, choix de matiere, temps de fabrication
3. Invitation en boutique
4. 3-5 hashtags EN max

### LinkedIn

**Format :** 100-200 mots, ton professionnel, angle metier / expertise.

**Structure :**
1. Hook metier (chiffre, savoir-faire, engagement)
2. Corps 4-5 phrases : approche artisanale, temps long, vision
3. Ouverture (echange, rencontre)
4. 3 hashtags EN pro max (#craftsmanship #bespoke #menswear)

## Exemples

### Correct — Instagram

```
Le costume trois-pieces sur mesure, pour celui qui comprend la valeur du temps long. Tissus selectionnes chez Loro Piana, assembles par les couturiers dans les ateliers parisiens partenaires. Trois essayages, six semaines, une piece unique.

Prise de mesures sur rendez-vous dans la boutique du 7e.

#menswear
#bespoke
#tailoring
#savoirfaire
#parismensstyle
```

**Pourquoi ca passe :**
- Francais narratif, zero tiret cadratin.
- "Les couturiers" (pas "nos").
- Pas de "a la main".
- Paris 7e mentionne.
- Hashtags EN sectoriels en fin.
- Ton Charvet / Hermes (temps long, piece unique).
- CTA subtil (RDV boutique).

### Correct — LinkedIn

```
Six semaines pour un costume. Trois essayages. Une piece unique taillee selon la morphologie de chaque client.

Dans un monde de production rapide, Atelier Mesure defend une approche patiente : selection du tissu chez des draperies europeennes historiques (Loro Piana, Holland and Sherry), realisation par les artisans partenaires francais, finitions cousues main sur les boutonnieres.

Le sur mesure n'est pas un luxe d'apparat, c'est une reponse concrete au probleme du pret-a-porter : une tombee precise, un tissu durable, une silhouette qui vieillit bien.

Nous recevons sur rendez-vous dans nos salons du 7e arrondissement.

#craftsmanship #bespoke #menswear
```

### Contre-exemple — a ne JAMAIS faire

```
Nos tailleurs cousent a la main — avec passion — nos nouveaux costumes 🔥🔥🔥
Achetez maintenant sur notre site !!!
Dispo au 10e arr. ce weekend seulement !!!
#achat #promo #soldes #suitlovers
```

**Problemes (au moins 10 erreurs) :**
- Tiret cadratin `—` (step 2).
- "Nos tailleurs" appropriation (step 5).
- "A la main" vocabulaire interdit (step 4).
- Emoji criards (step 8).
- "Achetez maintenant" CTA e-commerce (step 8).
- "Notre site" contredit modele RDV boutique (step 8).
- "10e arr." faux (step 6 : AM = 7e).
- Ponctuation excessive `!!!` (step 8).
- Hashtags FR fades (step 3).
- Ton urgence / promo casse le haut de gamme (step 8).

## Workflow skill

1. **Input user** : brief (type produit, plateforme, angle narratif, photo optionnelle).
2. **Generer draft** selon le template de la plateforme demandee.
3. **Auto-checklist** : parcourir les 8 steps sur le draft, corriger chaque ecart detecte.
4. **Output final** : caption propre + hashtags sur lignes separees + mention de la plateforme.
5. **Si URL Cloudinary fournie** : verifier `w_600,q_auto,f_auto` ou appliquer.

## Red Flags

**Ne JAMAIS :**
- Inserer un tiret cadratin `—` ou demi-cadratin `–`.
- Ecrire "a la main" (Gerber).
- Dire "nos couturiers" / "nos tailleurs" / "notre atelier".
- Citer le 10e arrondissement ou un autre quartier que le 7e.
- Utiliser un CTA e-commerce ("achetez maintenant", "shop now").
- Mettre plus de 1 emoji discret (IG / FB) ou 0 emoji (LinkedIn).
- Utiliser des hashtags FR fades (#mode, #homme).

**Toujours :**
- Francais sur le corps de la caption.
- Hashtags EN sectoriels en fin (sauf LinkedIn integres).
- Ton Charvet / Hermes.
- CTA subtil vers RDV boutique 7e.
- Verifier URLs Cloudinary optimisees.

## Integration

**Agents concernes :**
- MIKA (campaigns social media AM, publication PostProxy).
- ONYX (design de carousels et visuels associes).
- REMI (redaction inline si demande frontend).

**Pairs avec :**
- `am-social-postproxy-publish` (execute la publication via PostProxy apres validation caption).
- `am-email-content-rules` (meme philosophie editoriale cote email).
- Hook PostToolUse Write / Edit pour detecter `—`, "nos couturiers", "a la main" en auto (v0.4 P2).

## Reference

- Source : `feedback_social_content_rules` (memoire BERNARD, toujours active).
- Contexte business : `feedback_am_business_model` (AM = RDV boutique, pas e-commerce).
- Arrondissement : `feedback_am_arrondissement` (Paris 7e, pas 10e).
- Contenu email : `feedback_am_email_content` (meme regles vocabulaire).
- Publication : `feedback_postproxy` + `reference_postproxy_api` (jamais OAuth direct).
