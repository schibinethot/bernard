---
name: am-social-postproxy-publish
description: Publier un post social (Instagram, Facebook, LinkedIn) via l'API PostProxy pour Atelier Mesure (AM). JAMAIS d'OAuth direct (feedback_postproxy). Payload avec profiles, media, platforms au TOP LEVEL (reference_postproxy_api). Piege recurrent : NE PAS imbriquer dans { post: ... }. A declencher pour "publier sur Instagram/Facebook/LinkedIn AM", "poster sur reseaux sociaux AM", "diffuser contenu social AM".
version: 1.0.0
tags: social, postproxy, am, instagram, facebook, linkedin
---

# Publication sociale AM via PostProxy

Workflow unique pour publier sur les reseaux sociaux Atelier Mesure : TOUT passe par l'API PostProxy, jamais d'OAuth direct aux plateformes. Respect des conventions du payload (structure top-level critique).

**Core principle :** la publication sociale AM = PostProxy exclusivement (feedback_postproxy). Le payload a une structure precise : `profiles`, `media`, `platforms` au TOP LEVEL. Piege recurrent : copier un ancien format imbrique dans `{ post: { ... } }` → 400 silencieux + post non publie.

**Announce at start :** "Je declenche la skill am-social-postproxy-publish (PostProxy exclusivement, payload top-level)."

## Prerequis

- `$POSTPROXY_TOKEN` defini dans le `.env`
- `$POSTPROXY_URL` (default `https://postproxy.fly.dev`)
- Profils PostProxy AM configures cote service :
  - `am_instagram`
  - `am_facebook`
  - `am_linkedin`
- Media Cloudinary heberge avec transformations `w_1080,q_auto,f_auto`
- Caption validee (voir skill `social-caption-generate` pour les regles FR)

## Inputs

- `caption` (str, requise) : texte du post, francais, zero cadratin (voir `feedback_social_content_rules`)
- `media_urls` (array, requise) : URLs Cloudinary optimisees
- `platforms` (array, requise) : sous-ensemble de `["instagram", "facebook", "linkedin"]`
- `scheduled_at` (ISO 8601, optionnel) : publication differee

## Payload API PostProxy — format correct

```json
{
  "profiles": ["am_instagram", "am_facebook", "am_linkedin"],
  "media": [
    {
      "url": "https://res.cloudinary.com/am/image/upload/w_1080,q_auto,f_auto/v1/post1.jpg",
      "type": "image"
    }
  ],
  "platforms": {
    "instagram": {
      "caption": "Cette saison, les couturiers ont travaille une laine Super 150s ecossaise. Drape souple, tombee precise. Rdv en boutique, 7e arrondissement.",
      "hashtags": ["tailoring", "madeinparis", "bespoke"]
    },
    "facebook": {
      "caption": "Cette saison, les couturiers ont travaille une laine Super 150s ecossaise..."
    },
    "linkedin": {
      "caption": "Savoir-faire francais : nos pieces en laine Super 150s ecossaise revelent la precision artisanale..."
    }
  },
  "scheduled_at": "2026-04-15T10:00:00Z"
}
```

**CRITIQUE (reference_postproxy_api)** :
- `profiles`, `media`, `platforms` au **TOP LEVEL** du body JSON.
- JAMAIS imbrique dans un objet `post: {...}`.
- Piege frequent : copier l'ancien format → 400 silencieux + post jamais publie.

## Endpoint

```
POST https://postproxy.fly.dev/api/v1/publish
Authorization: Bearer $POSTPROXY_TOKEN
Content-Type: application/json
```

## Checklist

### Step 1 — Preparer le payload

```typescript
// server/services/social-publish.ts
import { env } from '../config';

type PublishInput = {
  caption: string;
  mediaUrls: string[];
  platforms: Array<'instagram' | 'facebook' | 'linkedin'>;
  scheduledAt?: string; // ISO 8601
  hashtags?: string[];
};

export async function publishToSocial(input: PublishInput) {
  // Mapping platforms -> profiles PostProxy
  const profileMap = {
    instagram: 'am_instagram',
    facebook: 'am_facebook',
    linkedin: 'am_linkedin',
  };

  const profiles = input.platforms.map(p => profileMap[p]);

  // Auto-fix : si media sans w_1080, ajouter transformation
  const media = input.mediaUrls.map(url => ({
    url: ensureCloudinaryTransform(url),
    type: 'image' as const,
  }));

  // Platforms : par defaut meme caption partout
  const platforms: Record<string, { caption: string; hashtags?: string[] }> = {};
  for (const p of input.platforms) {
    platforms[p] = {
      caption: input.caption,
      ...(input.hashtags && { hashtags: input.hashtags }),
    };
  }

  // Payload TOP LEVEL — NE PAS imbriquer dans { post: ... }
  const payload = {
    profiles,
    media,
    platforms,
    ...(input.scheduledAt && { scheduled_at: input.scheduledAt }),
  };

  return callPostProxy(payload);
}

function ensureCloudinaryTransform(url: string): string {
  if (!url.includes('res.cloudinary.com')) return url;
  if (url.includes('w_1080') || url.includes('w_600')) return url;
  // Injecter w_1080,q_auto,f_auto apres /upload/
  return url.replace('/upload/', '/upload/w_1080,q_auto,f_auto/');
}
```

### Step 2 — Envoyer la requete avec retry

```typescript
import { env } from '../config';
import { db } from '../db';
import { socialPostsLog } from '../../shared/schema';

async function callPostProxy(payload: unknown, attempt = 1): Promise<PublishResponse> {
  const MAX_ATTEMPTS = 3;
  const BACKOFF_MS = [1000, 3000, 9000];

  try {
    const response = await fetch(`${env.POSTPROXY_URL}/api/v1/publish`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.POSTPROXY_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    if (response.status === 401) {
      // Token expire
      if (env.POSTPROXY_REFRESH_URL) {
        await refreshPostProxyToken();
        if (attempt < MAX_ATTEMPTS) return callPostProxy(payload, attempt + 1);
      }
      throw new Error('PostProxy 401 : token expire, refresh impossible');
    }

    if (response.status >= 500 && attempt < MAX_ATTEMPTS) {
      await new Promise(r => setTimeout(r, BACKOFF_MS[attempt - 1]));
      return callPostProxy(payload, attempt + 1);
    }

    if (!response.ok) {
      const body = await response.text();
      throw new Error(`PostProxy ${response.status} : ${body}`);
    }

    const data = await response.json();
    return data as PublishResponse;
  } catch (err) {
    if (attempt < MAX_ATTEMPTS) {
      await new Promise(r => setTimeout(r, BACKOFF_MS[attempt - 1]));
      return callPostProxy(payload, attempt + 1);
    }
    throw err;
  }
}

type PublishResponse = {
  post_ids: Record<string, string>; // { instagram: "id_ig_123", ... }
  status: 'published' | 'scheduled';
  scheduled_at?: string;
};
```

### Step 3 — Logger le resultat

```typescript
export async function publishAndLog(input: PublishInput) {
  const result = await publishToSocial(input);

  // Log par plateforme dans la table d'audit
  for (const [platform, postId] of Object.entries(result.post_ids)) {
    await db.insert(socialPostsLog).values({
      platform,
      postId,
      status: result.status,
      caption: input.caption,
      mediaUrls: input.mediaUrls,
      publishedAt: result.status === 'published' ? new Date() : null,
      scheduledAt: input.scheduledAt ? new Date(input.scheduledAt) : null,
    });
  }

  return result;
}
```

## Checklist post-publication (8 items)

1. **HTTP 200/201** recu (sinon voir troubleshooting ci-dessous).
2. **`post_ids`** presents dans la response, un par plateforme.
3. **Log en base** (`social_posts_log`) avec `post_id`, `platform`, `status`, `published_at`.
4. **Scheduling** : si `scheduled_at` fourni, status retourne = `scheduled`, pas `published`.
5. **400** → verifier payload (profiles/media/platforms au top level ? pas dans `post: {...}` ?).
6. **401** → token expire, refresh via `$POSTPROXY_REFRESH_URL` + retry.
7. **5xx** → retry x3 avec backoff 1s / 3s / 9s (deja implemente).
8. **Trace MCP** via `log_interaction` vers MIKA pour traceability marketing :
   ```
   mcp__agent-memory__log_interaction
     from_agent="SEBASTIEN"
     to_agent="MIKA"
     task_type="delivery"
     input_summary="social-publish <plateformes>"
     output_summary="post_ids=<ids>, status=<status>"
   ```

## Exemple correct (a suivre)

```typescript
await publishAndLog({
  caption: "Cette saison, les couturiers ont travaille une laine Super 150s ecossaise. Drape souple, tombee precise. Rdv en boutique, 7e arrondissement.",
  mediaUrls: [
    "https://res.cloudinary.com/am/image/upload/w_1080,q_auto,f_auto/v1/atelier-coupe.jpg"
  ],
  platforms: ["instagram", "facebook", "linkedin"],
  hashtags: ["tailoring", "madeinparis", "bespoke"],
});
```

Payload serialise (verification) :
```json
{
  "profiles": ["am_instagram", "am_facebook", "am_linkedin"],
  "media": [{ "url": "...w_1080,q_auto,f_auto/v1/atelier-coupe.jpg", "type": "image" }],
  "platforms": {
    "instagram": { "caption": "...", "hashtags": ["tailoring", "madeinparis", "bespoke"] },
    "facebook": { "caption": "...", "hashtags": ["tailoring", "madeinparis", "bespoke"] },
    "linkedin": { "caption": "...", "hashtags": ["tailoring", "madeinparis", "bespoke"] }
  }
}
```

## Contre-exemple (piege recurrent, a BANNIR)

```typescript
// INCORRECT — structure imbriquee dans "post"
const payload = {
  post: {
    profiles: ["am_instagram"],
    media: [...],
    platforms: {...},
  },
};

// Resultat : PostProxy retourne 400 silencieusement ou 200 avec post vide.
// Le post N'EST PAS publie. Pas d'erreur visible cote caller.
```

**Symptomes du piege** :
- Response `200 OK` mais `post_ids` vide ou absent.
- Ou response `400 Bad Request` avec message vague.
- Aucun post visible sur Instagram/Facebook/LinkedIn.
- Table `social_posts_log` vide pour le run.

**Cause** : wrap `{ post: { ... } }` au lieu de top-level. PostProxy ignore le body mal forme.

## Edge cases

| Cas | Action |
|---|---|
| Media Cloudinary sans `w_1080` | Auto-fix via `ensureCloudinaryTransform` (ajout transform) |
| Plateforme hors `instagram/facebook/linkedin` | Erreur claire, pas de call silencieux |
| `scheduled_at` dans le passe | Reject cote client avant call + message |
| Caption > limite plateforme (IG 2200, LI 3000) | Ideal : skill `social-caption-generate` tronque avant |
| Token `POSTPROXY_TOKEN` absent | Erreur claire au demarrage |
| Reseau instable | Retry x3 avec backoff expo 1s/3s/9s |
| Response 200 mais `post_ids` vide | Symptome piege payload → verifier top-level |

## Red Flags

**Ne JAMAIS :**
- Imbriquer dans `{ post: { ... } }` (piege structurel).
- Utiliser OAuth direct aux plateformes (bypass PostProxy) — viole `feedback_postproxy`.
- Publier sans logger dans `social_posts_log` (aucune traceability).
- Retry infini sur 5xx (max 3 tentatives).
- Hardcoder `$POSTPROXY_TOKEN` dans le code.

**Toujours :**
- Payload top-level (`profiles`, `media`, `platforms`).
- Transforms Cloudinary (`w_1080,q_auto,f_auto`).
- Log post-publication en base.
- Trace MCP vers MIKA (marketing).
- Verifier `post_ids` non vide dans response.

## Tests

### Test 1 — Payload correct 3 plateformes

```typescript
const result = await publishAndLog({
  caption: "Test post",
  mediaUrls: ["https://res.cloudinary.com/am/image/upload/w_1080,q_auto,f_auto/v1/test.jpg"],
  platforms: ["instagram", "facebook", "linkedin"],
});
```

Attendu : `200`, `result.post_ids` avec 3 entrees, 3 rows dans `social_posts_log`.

### Test 2 — Payload imbrique (simulation piege)

```typescript
const badPayload = { post: { profiles: [...], media: [...], platforms: {...} } };
await fetch(url, { body: JSON.stringify(badPayload) });
```

Attendu : `400` ou `200` avec `post_ids` vide. Verifier symptomes du piege.

### Test 3 — Token expire

```typescript
process.env.POSTPROXY_TOKEN = 'expired';
await publishAndLog({...});
```

Attendu : `401`, auto-refresh si URL configure, retry, puis succes. Sinon erreur claire.

### Test 4 — Cloudinary sans transform

```typescript
await publishAndLog({
  mediaUrls: ["https://res.cloudinary.com/am/image/upload/v1/raw.jpg"],
  ...
});
```

Attendu : URL transformee automatiquement en `.../upload/w_1080,q_auto,f_auto/v1/raw.jpg`.

### Test 5 — Scheduled dans le passe

```typescript
await publishAndLog({ ..., scheduledAt: "2020-01-01T00:00:00Z" });
```

Attendu : erreur avant call PostProxy, message clair.

## Integration

**Agents concernes :**
- SEBASTIEN (backend, implementation service publish)
- MIKA (paid ads + social content AM)
- ONYX (design assets Cloudinary en amont)

**Pairs avec :**
- `social-caption-generate` (generer caption FR conforme avant publish)
- `am-email-content-rules` (meme regles ton/vocabulaire)
- Table `social_posts_log` (audit trail)

## Reference

- Source primaire : `reference_postproxy_api`
- Feedback critique : `feedback_postproxy` (jamais OAuth direct)
- Regles contenu : `feedback_social_content_rules` (FR, zero cadratin, hashtags EN)
- Projet : Atelier Mesure (AM)
- Service : PostProxy deploye sur Fly.io (`postproxy.fly.dev`)
