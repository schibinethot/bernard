---
name: am-sql-preprod-deploy
description: Deploy SQL en preprod ERP-AM / SITE-AM avant promote prod. Cree le script scripts/preprod/NNN-feature.sql avec IF NOT EXISTS, push sur git, execute en preprod via psql, puis seulement apres promote en prod. A utiliser des qu'une nouvelle table ou modification de schema est introduite sur ERP-AM, SITE-AM ou tout projet AM qui utilise Drizzle ORM.
version: 1.0.0
---

# SQL preprod avant deploy prod

Workflow strict pour toute modification de schema sur les projets AM (Atelier Mesure) : un script SQL preprod est cree, execute en preprod, verifie, puis seulement apres on peut promote en prod.

**Core principle :** drizzle-kit push peut proposer des DROP TABLE destructifs si les tables n'existent pas en preprod. On cree les tables en preprod d'abord.

**Announce at start :** "Je declenche la skill am-sql-preprod-deploy pour securiser le deploy."

## Prerequis

- psql CLI installe
- `$PREPROD_DB_URL` (ou `$DATABASE_URL_PREPROD`) dans le `.env` du projet
- Acces git push vers la branche preprod/main
- Drizzle ORM en place (`drizzle.config.ts`, `shared/schema.ts`)

## Checklist

### Step 1 — Identifier le dernier numero existant

```bash
ls scripts/preprod/ | grep -E '^[0-9]{3}' | sort -n | tail -5
```

Numerotation sequentielle obligatoire : 001, 002, 003... On incremente le dernier.

### Step 2 — Creer le fichier SQL avec IF NOT EXISTS

Convention de nommage : `scripts/preprod/NNN-<feature-slug>.sql`.

```sql
-- scripts/preprod/007-add-email-nurturing.sql
-- Feature : email nurturing M3-M24
-- Date : 2026-04-14
-- Auteur : SEBASTIEN (via BERNARD)

CREATE TABLE IF NOT EXISTS email_nurturing_schedule (
  id SERIAL PRIMARY KEY,
  customer_id INTEGER NOT NULL REFERENCES customers(id),
  stage TEXT NOT NULL,
  scheduled_at TIMESTAMPTZ NOT NULL,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_email_nurturing_customer
  ON email_nurturing_schedule(customer_id);

ALTER TABLE customers
  ADD COLUMN IF NOT EXISTS nurturing_opt_in BOOLEAN DEFAULT true;
```

Toujours utiliser `IF NOT EXISTS` pour :
- `CREATE TABLE`
- `CREATE INDEX`
- `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`

### Step 3 — Commit + push

```bash
git add scripts/preprod/NNN-<feature-slug>.sql
git commit -m "sql(preprod): NNN <feature-slug>"
git push origin <branche-courante>
```

### Step 4 — Executer en preprod

```bash
# Charger le .env si besoin
set -a && source .env && set +a

psql "$PREPROD_DB_URL" -f scripts/preprod/NNN-<feature-slug>.sql
```

Verifier la sortie : aucun `ERROR`, juste des `CREATE TABLE` / `ALTER TABLE` / `NOTICE`. Les `NOTICE: relation already exists, skipping` sont normaux (idempotence).

### Step 5 — Validation drizzle-kit

```bash
npx drizzle-kit push --dialect=postgresql --url="$PREPROD_DB_URL"
```

Attendu : soit `No changes detected`, soit un diff propre sans aucun `DROP TABLE` ni `DROP COLUMN`. Si drizzle propose un DROP : stopper, investiguer (schema.ts pas a jour, ou fichier SQL incomplet).

### Step 6 — Seed/test sur preprod (optionnel selon feature)

```bash
# Requete de controle
psql "$PREPROD_DB_URL" -c "\d email_nurturing_schedule"
psql "$PREPROD_DB_URL" -c "SELECT COUNT(*) FROM email_nurturing_schedule;"
```

### Step 7 — Promote prod (SEULEMENT apres steps 1-6 OK)

```bash
# Assuming merge preprod -> main est deja fait ou va etre fait
psql "$PROD_DB_URL" -f scripts/preprod/NNN-<feature-slug>.sql
```

Puis declencher le deploy applicatif (Railway auto ou manuel).

## Red Flags

**Ne JAMAIS :**
- Executer un SQL directement en prod sans passer par preprod
- Utiliser `DROP TABLE` sans `IF EXISTS` et sans sauvegarde prealable
- Omettre `IF NOT EXISTS` (casse l'idempotence, rejoue impossible)
- Commit un fichier `scripts/preprod/*.sql` qui modifie des donnees sensibles sans review

**Toujours :**
- Numeroter sequentiellement (004, 005, 006...)
- Tester sur preprod avant prod
- Verifier `drizzle-kit push` avant de deployer
- Garder le fichier SQL dans git (histoire, rollback, audit)

## Integration

**Agents concernes :**
- SEBASTIEN (backend Express + Drizzle)
- MORGAN (architecture, choix de schema)
- LEO (deploy, coordination preprod/prod)

**Pairs avec :**
- `am-supabase-ddl-deploy` (pour le DDL Supabase specifique)
- Hook `guard.sh` (bloque DROP TABLE sans IF EXISTS)

## Reference

- Source : `feedback_sql_preprod.md` (feedback utilisateur)
- Drizzle ORM docs : https://orm.drizzle.team
- Convention : ERP-AM et SITE-AM utilisent Neon PostgreSQL avec branches preprod/main
