---
name: am-email-content-rules
description: Regles strictes de redaction des emails clients Atelier Mesure (AM). Controle le ton haut de gamme, les formulations interdites (a la main, nos couturiers), le format des photos Cloudinary, et l'interdiction du tiret cadratin. A utiliser avant tout envoi ou generation de template email AM par SEBASTIEN, ONYX ou tout autre agent qui redige du contenu client pour Atelier Mesure.
version: 1.0.0
---

# Regles contenu emails Atelier Mesure

Checklist obligatoire pour tout template ou email client AM. Ton Charvet/Hermes, zero appropriation du travail fournisseur, photos contextualisees.

**Core principle :** AM = haut de gamme. Tout ecart sur le vocabulaire (technique, fournisseurs, photos) casse la perception premium.

**Announce at start :** "Je declenche la skill am-email-content-rules pour valider le contenu avant envoi."

## Prerequis

- Le template email (fichier `.html`, `.mjml`, `.tsx` React Email, etc.)
- URL Cloudinary pour les photos (pattern attendu : `res.cloudinary.com/<cloud>/image/upload/...`)
- Signature d'une personne reelle (jamais "L'equipe")

## Checklist

### Step 1 — Vocabulaire fabrication

**Interdit :** "realise a la main" / "decoupe a la main" / "coupe a la main"

**Pourquoi :** certaines pieces sont decoupees au Gerber (machine de coupe automatisee), pas a la main. Ecrire "a la main" est factuellement faux.

**Remplacer par :** "tracee et realisee avec precision" / "coupee et assemblee avec precision"

**Verification grep :**
```bash
grep -iE "(a la main|realise a la main|decoupe a la main)" <template>
```
Si match → corriger.

### Step 2 — Appropriation du travail fournisseur

**Interdit :** "nos couturiers" / "notre atelier de fabrication" / "nos artisans" (sauf si c'est vraiment AM qui execute)

**Pourquoi :** GoCreate et les autres partenaires sont des fournisseurs externes, pas des employes AM. S'approprier leur travail est une erreur de communication.

**Remplacer par :** "les couturiers" / "l'atelier de fabrication" / "les artisans partenaires"

**Verification grep :**
```bash
grep -iE "nos (couturiers|artisans|tailleurs|brodeurs)" <template>
```

### Step 3 — Photos contextualisees

Les photos d'atelier montrent le process general, **pas la piece specifique** du client. Risque : confusion "c'est ma piece ?".

**Obligatoire :** titre contextuel au-dessus ou legende sous la photo, exemples :
- "Voici a quoi ressemble la confection d'une piece comme la votre"
- "L'atelier ou sera confectionnee votre piece"
- "Exemple de finition — photo non contractuelle"

**Verification :** chaque `<img>` du template doit avoir un `alt=""` descriptif ET un titre/legende visible si c'est une photo de fabrication generique.

### Step 4 — Optimisation Cloudinary

**Obligatoire :** toutes les URLs Cloudinary doivent contenir les transformations `w_600,q_auto,f_auto`.

**Pattern correct :**
```
https://res.cloudinary.com/am-cloud/image/upload/w_600,q_auto,f_auto/v123456/atelier-coupe.jpg
```

**Pattern incorrect :**
```
https://res.cloudinary.com/am-cloud/image/upload/v123456/atelier-coupe.jpg   # pas d'optimisation
https://res.cloudinary.com/am-cloud/image/upload/w_1200/...                   # 1200px trop lourd email
```

**Verification grep :**
```bash
grep -oE "res\.cloudinary\.com[^\"'\)]+" <template> | grep -vE "w_600,q_auto,f_auto"
```
Si une URL ressort, elle n'est pas optimisee.

**Pourquoi :** email doit rester leger (< 100KB idealement). `w_600` resize a 600px (largeur max utile), `q_auto` qualite auto, `f_auto` format auto (webp/avif selon le client mail).

### Step 5 — Ton haut de gamme

**Interdit :**
- Emojis (aucun, meme subtil)
- "OFFRE" / "PROMO" / "-20%" en capitales criardes
- Comptes a rebours ("Plus que 24h !")
- Tutoiement
- "Notre equipe" / "L'equipe AM" en signature → toujours un prenom reel (ex : "Cordialement, Thomas")

**Obligatoire :**
- Vouvoiement
- Phrases complètes, ponctuation soignée
- Signature : prénom + rôle (ex : "Thomas, votre conseiller Atelier Mesure")

### Step 6 — Tiret cadratin interdit

**Interdit :** `—` (tiret cadratin / em dash) dans le contenu email.

**Raison :** rendu inconsistant selon les clients mail (certains Outlook affichent `?`), et marque typographique trop "AI generated".

**Remplacer par :** deux points `:`, virgule, ou parenthese selon le sens.

**Verification grep :**
```bash
grep -c "—" <template>
```
Resultat attendu : 0.

## Templates example

### Email "votre piece est en fabrication"

```html
<h1>Votre piece entre en atelier</h1>
<p>Cher Monsieur Dupont,</p>
<p>Nous avons le plaisir de vous annoncer que votre costume a pris
place chez nos partenaires de fabrication. Les couturiers vont
desormais tracer et realiser avec precision chaque detail de votre
piece.</p>

<figure>
  <img
    src="https://res.cloudinary.com/am-cloud/image/upload/w_600,q_auto,f_auto/v1/atelier-coupe.jpg"
    alt="Table de coupe dans l'atelier partenaire"
  />
  <figcaption>Voici a quoi ressemble la confection d'une piece comme la votre. Photo non contractuelle.</figcaption>
</figure>

<p>Cordialement,</p>
<p>Thomas, votre conseiller Atelier Mesure</p>
```

### Ce qu'il ne faut PAS faire

```html
<!-- INTERDIT -->
<h1>OFFRE EXCLUSIVE — Plus que 24h !</h1>
<p>Salut Jean !</p>
<p>Nos couturiers fabriquent a la main ton costume dans notre atelier parisien.</p>
<img src="https://res.cloudinary.com/am-cloud/image/upload/v1/atelier.jpg" />
<p>L'equipe AM</p>
```

Problemes :
- OFFRE criarde, tiret cadratin, compte a rebours
- Tutoiement
- "Nos couturiers" (appropriation), "a la main" (faux), "notre atelier" (fournisseur externe)
- Image Cloudinary non optimisee, pas de contexte
- Signature anonyme "L'equipe AM"

## Red Flags

**Ne JAMAIS :**
- Ecrire "a la main" quand c'est Gerber
- Dire "nos couturiers" pour GoCreate / partenaires externes
- Inserer un tiret cadratin `—`
- Utiliser des emojis
- Signer "L'equipe" sans prenom reel
- Publier une URL Cloudinary sans `w_600,q_auto,f_auto`

**Toujours :**
- Vouvoiement
- Photos fabrication titrees "non contractuelles" ou "a quoi ressemble la confection"
- Prenom reel en signature
- Ton Charvet/Hermes

## Integration

**Agents concernes :**
- SEBASTIEN (implementation templates React Email / MJML)
- ONYX (design de templates visuels)
- MIKA (campaigns email marketing AM)

**Pairs avec :**
- `simplify` (review generale avant envoi)
- Hook PostToolUse Write/Edit pour detecter `—`, "nos couturiers", "a la main" en auto

## Reference

- Source : `feedback_am_email_content.md`
- Contexte business : `feedback_am_business_model.md` (AM = RDV boutique, pas e-commerce)
- Cloudinary docs : https://cloudinary.com/documentation/image_optimization
- Session correction utilisateur : 05/04/2026
