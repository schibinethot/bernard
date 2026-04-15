---
name: email-cron-create
description: Creer un cron email nurturing (scheduler, job email recurrent) respectant le filtre anti-backfill obligatoire (feedback_cron_historical_backfill). Pattern CRON_CREATED_AT hardcode + fenetre 24h + LEFT JOIN idempotent. A declencher des que l'utilisateur demande "creer un cron email", "scheduler d'emails", "cron nurturing M3/M6/M12", "job email recurrent" ou toute tache recurrente d'envoi de mails client.
version: 1.0.0
tags: cron, email, nurturing, backfill, drizzle, scheduler
---

# Creation cron email avec filtre anti-backfill

Pattern obligatoire pour creer un cron email recurrent sans risque de rattrapage historique massif au premier run. Base sur le feedback critique `feedback_cron_historical_backfill` : sans filtre date, un cron M3 sur une base avec 1000 clients historiques envoie 1000 emails au premier run = disaster.

**Core principle :** `WHERE created_at > CRON_CREATED_AT` est OBLIGATOIRE sur tout cron email avec population historique. Le CRON_CREATED_AT est hardcode dans le code TS comme constante, jamais calcule dynamiquement.

**Announce at start :** "Je declenche la skill email-cron-create avec le pattern anti-backfill (CRON_CREATED_AT + fenetre 24h)."

## Prerequis

- Projet avec Drizzle ORM (`drizzle.config.ts`, `shared/schema.ts`)
- Table `email_nurturing_sent` (ou equivalent) pour idempotence
- Service email configure (Resend, Brevo, etc.) via env var
- Scheduler en place (cron-job.org, Railway crons, node-cron, etc.)
- Table `cron_runs` pour logger executions (optionnel mais recommande)

## Inputs (via prompt)

- **Nom du cron** : ex `email-m3-nurturing`
- **Audience** : segment (RFM, table cible, filtre metier)
- **Frequence** : daily, weekly, horaire d'execution
- **Template** : path / nom du template email
- **Stage** : identifiant unique pour la colonne `stage` de `email_nurturing_sent` (ex `m3`, `m6`, `m12`)

## Checklist

### Step 1 — Definir CRON_CREATED_AT

**Regle absolue** : la date de creation du cron est hardcodee dans le code TS, au format ISO UTC. C'est la date du jour ou le cron entre en production.

```typescript
// server/crons/email-m3-nurturing.ts
// CRON_CREATED_AT : date du 1er run en prod.
// Tout client created_at AVANT cette date est exclu (anti-backfill).
const CRON_CREATED_AT = new Date('2026-04-14T00:00:00Z');
```

Pourquoi hardcode : calcul dynamique (`new Date()` au runtime) = le cron rattrape tout l'historique au 1er run. Catastrophe RGPD + spam reputation.

### Step 2 — SQL pattern avec filtre date

```sql
-- Pattern OBLIGATOIRE : 3 filtres date
-- 1. WHERE created_at > CRON_CREATED_AT  → anti-backfill
-- 2. WHERE created_at < NOW() - INTERVAL '3 months'  → declencheur (client a 3 mois)
-- 3. WHERE created_at >= NOW() - INTERVAL '3 months 1 day'  → fenetre 24h

SELECT c.id, c.email, c.first_name, c.created_at
FROM customers c
LEFT JOIN email_nurturing_sent ens
  ON ens.customer_id = c.id
  AND ens.stage = 'm3'
WHERE c.created_at > '2026-04-14 00:00:00'       -- CRON_CREATED_AT hardcode
  AND c.created_at < NOW() - INTERVAL '3 months'
  AND c.created_at >= NOW() - INTERVAL '3 months 1 day'
  AND ens.id IS NULL                              -- pas deja envoye
  AND c.nurturing_opt_in = true;                  -- RGPD
```

### Step 3 — Template Drizzle/TypeScript scheduler

```typescript
// server/crons/email-m3-nurturing.ts
import { db } from '../db';
import { customers, emailNurturingSent, cronRuns } from '../../shared/schema';
import { and, eq, gt, lt, gte, isNull, sql } from 'drizzle-orm';
import { sendEmail } from '../services/email';

// HARDCODE : date de creation du cron en production.
// Tout client created_at avant cette date = hors periode, exclu.
const CRON_CREATED_AT = new Date('2026-04-14T00:00:00Z');

// Config cron
const CRON_NAME = 'email-m3-nurturing';
const CRON_STAGE = 'm3';
const CRON_INTERVAL_MONTHS = 3;
const DRY_RUN = process.env.DRY_RUN === 'true';
const BATCH_SIZE = 50;
const RATE_LIMIT_MS = 200; // 5 emails/s max

export async function runM3NurturingCron() {
  const runStart = new Date();
  console.log(`[cron:${CRON_NAME}] Start at ${runStart.toISOString()} (DRY_RUN=${DRY_RUN})`);

  // Fenetre : clients dont created_at est entre 3mois-24h et 3mois exactement
  const threeMonthsAgo = sql`NOW() - INTERVAL '3 months'`;
  const windowStart = sql`NOW() - INTERVAL '3 months 1 day'`;

  const candidates = await db
    .select({
      id: customers.id,
      email: customers.email,
      firstName: customers.firstName,
      createdAt: customers.createdAt,
    })
    .from(customers)
    .leftJoin(
      emailNurturingSent,
      and(
        eq(emailNurturingSent.customerId, customers.id),
        eq(emailNurturingSent.stage, CRON_STAGE),
      ),
    )
    .where(
      and(
        gt(customers.createdAt, CRON_CREATED_AT),     // ANTI-BACKFILL
        lt(customers.createdAt, threeMonthsAgo),       // client a 3 mois
        gte(customers.createdAt, windowStart),         // fenetre 24h
        isNull(emailNurturingSent.id),                 // idempotent
        eq(customers.nurturingOptIn, true),            // RGPD
      ),
    );

  console.log(`[cron:${CRON_NAME}] ${candidates.length} candidats`);

  if (DRY_RUN) {
    console.log(`[cron:${CRON_NAME}] DRY_RUN, aucun envoi effectue`);
    console.log(candidates.slice(0, 5));
    return { candidates: candidates.length, sent: 0, dryRun: true };
  }

  // Batching avec rate-limit
  let sent = 0;
  let errors = 0;

  for (const customer of candidates) {
    try {
      await sendEmail({
        to: customer.email,
        template: CRON_STAGE,
        vars: { firstName: customer.firstName },
      });

      await db.insert(emailNurturingSent).values({
        customerId: customer.id,
        stage: CRON_STAGE,
        sentAt: new Date(),
      });

      sent++;

      // Rate-limit entre chaque envoi
      await new Promise(r => setTimeout(r, RATE_LIMIT_MS));
    } catch (err) {
      console.error(`[cron:${CRON_NAME}] Erreur sur customer ${customer.id}:`, err);
      errors++;
    }
  }

  const runEnd = new Date();
  const durationMs = runEnd.getTime() - runStart.getTime();

  // Log run pour historique + detection ratages (> 24h entre runs)
  await db.insert(cronRuns).values({
    cronName: CRON_NAME,
    startedAt: runStart,
    endedAt: runEnd,
    candidates: candidates.length,
    sent,
    errors,
    durationMs,
  });

  console.log(`[cron:${CRON_NAME}] Done. sent=${sent} errors=${errors} duration=${durationMs}ms`);
  return { candidates: candidates.length, sent, errors, durationMs };
}

// Export CLI
if (require.main === module) {
  runM3NurturingCron()
    .then(r => { console.log(JSON.stringify(r, null, 2)); process.exit(0); })
    .catch(e => { console.error(e); process.exit(1); });
}
```

### Step 4 — Scheduler integration

**Option A — cron-job.org / Railway cron** :
```bash
# Route Express
POST /api/crons/email-m3
Authorization: Bearer $CRON_SECRET
```

```typescript
// server/routes/crons.ts
app.post('/api/crons/email-m3', requireCronAuth, async (req, res) => {
  const result = await runM3NurturingCron();
  res.json(result);
});
```

**Option B — node-cron inline** :
```typescript
// server/scheduler.ts
import cron from 'node-cron';

// Tous les jours a 10h UTC
cron.schedule('0 10 * * *', () => runM3NurturingCron());
```

### Step 5 — Checklist 6 items anti-spam

Valider chaque point AVANT deploy :

1. **`WHERE created_at > CRON_CREATED_AT`** est present dans le WHERE SQL.
   ```bash
   grep -E "CRON_CREATED_AT|cron_started" server/crons/email-*.ts
   ```

2. **Fenetre temporelle etroite** (24h) via `INTERVAL '3 months'` AND `INTERVAL '3 months 1 day'`.
   ```bash
   grep -E "INTERVAL '.+ 1 day'" server/crons/email-*.ts
   ```

3. **LEFT JOIN `email_nurturing_sent` + `IS NULL`** (idempotent, un client = un email par stage).
   ```bash
   grep -E "leftJoin.*emailNurturingSent.*isNull" server/crons/email-*.ts
   ```

4. **`nurturing_opt_in = true`** (RGPD, consentement).

5. **Dry-run mode first** : `DRY_RUN=true npm run cron:email-m3` log les candidats sans envoyer.

6. **Rate-limit** : batching + `setTimeout` pour respecter limites Resend/Brevo (5-10 emails/s).

Log chaque point dans le PR description au moment du deploy.

### Step 6 — Gestion ratages (runs manques)

Si le cron rate 48h+ (incident scheduler), la fenetre 24h classique manque des clients. Solution : detecter le dernier run via `cron_runs`, etendre la fenetre si necessaire.

```typescript
// Au debut de runM3NurturingCron
const lastRun = await db
  .select({ endedAt: cronRuns.endedAt })
  .from(cronRuns)
  .where(eq(cronRuns.cronName, CRON_NAME))
  .orderBy(desc(cronRuns.endedAt))
  .limit(1);

const hoursSinceLastRun = lastRun.length
  ? (Date.now() - lastRun[0].endedAt.getTime()) / 3600000
  : 24;

// Si dernier run > 30h, etendre la fenetre
const windowDays = hoursSinceLastRun > 30 ? Math.ceil(hoursSinceLastRun / 24) + 1 : 1;
const windowStart = sql`NOW() - INTERVAL '${CRON_INTERVAL_MONTHS} months ${windowDays} day'`;
```

## Edge cases

| Cas | Action |
|---|---|
| Premier run avant CRON_CREATED_AT | Zero candidat (normal, anti-backfill) |
| Cron rate 48h | Fenetre auto-etendue via `cron_runs` lookup |
| Opt-out entre creation et envoi | Filtre `nurturing_opt_in = true` exclut automatiquement |
| Envoi email echoue | Pas d'insert dans `email_nurturing_sent`, retente prochain run |
| Rate-limit Resend depasse | Catch + backoff, log erreur, continuer batch suivant |
| Client supprime (GDPR erase) | Cascade delete sur `email_nurturing_sent`, cron ne re-envoie pas |

## Red Flags

**Ne JAMAIS :**
- Omettre `WHERE created_at > CRON_CREATED_AT` (backfill historique = spam).
- Calculer CRON_CREATED_AT dynamiquement (`new Date()` au runtime).
- Lancer en prod sans DRY_RUN prealable.
- Ignorer `nurturing_opt_in` (RGPD violation).
- Envoyer sans INSERT dans `email_nurturing_sent` (doublons garantis).
- Omettre le rate-limit (bannissement provider).

**Toujours :**
- Hardcoder CRON_CREATED_AT en constante TS.
- Tester en DRY_RUN avant 1er run prod.
- Logger chaque run dans `cron_runs`.
- Monitorer les volumes (candidats vs sent) pour detecter les anomalies.
- Documenter le cron dans un README `server/crons/README.md`.

## Tests

### Test 1 — Seed clients AVANT CRON_CREATED_AT

```sql
INSERT INTO customers (email, created_at, nurturing_opt_in)
VALUES ('old@test.com', '2026-01-01', true);
```

Attendu : cron retourne 0 candidat (anti-backfill fonctionne).

### Test 2 — Seed clients APRES CRON_CREATED_AT dans fenetre

```sql
INSERT INTO customers (email, created_at, nurturing_opt_in)
VALUES
  ('new1@test.com', NOW() - INTERVAL '3 months 6 hours', true),
  ('new2@test.com', NOW() - INTERVAL '3 months 12 hours', true),
  ('new3@test.com', NOW() - INTERVAL '3 months 23 hours', true);
```

Attendu : cron retourne 3 candidats.

### Test 3 — Client deja envoye

```sql
INSERT INTO email_nurturing_sent (customer_id, stage, sent_at)
VALUES (1, 'm3', NOW());
```

Attendu : client exclu via `IS NULL` sur LEFT JOIN.

### Test 4 — Opt-out

```sql
UPDATE customers SET nurturing_opt_in = false WHERE id = 2;
```

Attendu : client exclu.

### Test 5 — DRY_RUN

```bash
DRY_RUN=true npm run cron:email-m3
```

Attendu : log candidats, zero insert dans `email_nurturing_sent`, zero envoi.

## Integration

**Agents concernes :**
- SEBASTIEN (backend, implementation cron)
- MORGAN (architecture, design schema)
- ELENA (QA, validation tests)
- REBECCA (legal, verification RGPD)

**Pairs avec :**
- `am-sql-preprod-deploy` (creer la table `email_nurturing_sent` en preprod d'abord)
- Hook `cron-date-filter-check.sh` (lint automatique des crons sans CRON_CREATED_AT)

## Reference

- Source : `feedback_cron_historical_backfill`
- Projet : `project_email_nurturing_pipeline`
- Contexte metier : `feedback_am_business_model` (AM = RDV boutique, nurturing relance 3-24 mois)
- Doc Drizzle : https://orm.drizzle.team
- Services email : Resend (migration en cours), Brevo (legacy)
