---
name: am-supabase-ddl-deploy
description: Deploy DDL Supabase (CREATE/ALTER FUNCTION, migrations RPC, row-level security) sans jamais demander a l'utilisateur d'executer le SQL dans le Dashboard. Utilise psql avec la connection string Supabase pour un deploy end-to-end autonome. A declencher des qu'une migration Supabase ou un RPC doit etre deploye sur un projet AM, Nelvo ou tout projet utilisant Supabase.
version: 1.0.0
---

# Deploy DDL Supabase autonome

Workflow pour deployer du DDL Supabase (migrations, fonctions RPC, triggers, policies RLS) de facon autonome via psql, sans friction utilisateur.

**Core principle :** ne JAMAIS demander a l'utilisateur d'executer le SQL dans le Dashboard Supabase. Tout passe par psql avec la connection string.

**Announce at start :** "Je declenche la skill am-supabase-ddl-deploy pour appliquer le DDL en autonomie."

## Prerequis

- psql CLI installe (`brew install libpq` si absent)
- Connection string Supabase dans le `.env` :
  - `DATABASE_URL` ou `SUPABASE_DB_URL` ou `SUPABASE_DB_CONNECTION_STRING`
- Project ref Supabase (visible dans l'URL du dashboard)
- SERVICE_ROLE_KEY (pour tester les RPC apres deploy)

## Checklist

### Step 1 — Localiser la connection string

```bash
# Chercher dans le .env du projet
grep -E "DATABASE_URL|SUPABASE_DB_URL|SUPABASE_DB_CONNECTION" .env .env.local 2>/dev/null
```

Format attendu :
```
postgresql://postgres.<project-ref>:<password>@aws-0-<region>.pooler.supabase.com:6543/postgres
```

**Si absent :**
1. Aller sur le Dashboard Supabase > Project Settings > Database > Connection string (URI mode)
2. Recuperer la string, l'ajouter au `.env` local et au `.env.example` (avec valeur masquee)
3. Verifier qu'elle est bien dans les secrets Railway/Fly/Vercel selon le hosting
4. Si le password manque, le demander a l'utilisateur UNE SEULE FOIS et le stocker dans le scratchpad session

### Step 2 — Preparer le fichier de migration

Convention de nommage : `supabase/migrations/<timestamp>_<feature>.sql` ou `migrations/<NNN>-<feature>.sql`.

Pattern idempotent obligatoire :

```sql
-- migrations/008-rpc-customer-stats.sql
-- Date : 2026-04-14

-- Fonction RPC pour stats client (idempotent via CREATE OR REPLACE)
CREATE OR REPLACE FUNCTION public.get_customer_stats(p_customer_id bigint)
RETURNS TABLE (
  total_orders int,
  total_spent numeric,
  last_order_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    COUNT(*)::int,
    COALESCE(SUM(amount), 0),
    MAX(created_at)
  FROM orders
  WHERE customer_id = p_customer_id;
$$;

-- Grant execution au role anon/authenticated
GRANT EXECUTE ON FUNCTION public.get_customer_stats(bigint) TO anon, authenticated;

-- Policy RLS idempotente
DROP POLICY IF EXISTS "customers_own_stats" ON customers;
CREATE POLICY "customers_own_stats"
  ON customers FOR SELECT
  USING (auth.uid() = user_id);
```

Patterns idempotents a privilegier :
- `CREATE OR REPLACE FUNCTION`
- `CREATE TABLE IF NOT EXISTS`
- `DROP POLICY IF EXISTS` + `CREATE POLICY`
- `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`
- `CREATE INDEX IF NOT EXISTS`

### Step 3 — Executer via psql

```bash
# Charger le .env
set -a && source .env && set +a

# Deploy
psql "$SUPABASE_DB_URL" -f migrations/008-rpc-customer-stats.sql
```

Verifier la sortie :
- `CREATE FUNCTION`
- `GRANT`
- `DROP POLICY` / `CREATE POLICY`
- Pas d'erreur `permission denied` → si oui, verifier que l'URL pointe sur `postgres` (role admin) et pas `anon`.

### Step 4 — Valider via un appel RPC

Tester immediatement la fonction avec SERVICE_ROLE_KEY :

```bash
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/get_customer_stats" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"p_customer_id": 1}' | jq
```

Ou via le client JS du projet :

```ts
const { data, error } = await supabase.rpc('get_customer_stats', { p_customer_id: 1 });
```

Attendu : JSON avec `total_orders`, `total_spent`, `last_order_at`. Si erreur `function does not exist` → le DDL n'a pas ete applique, relire la sortie psql.

### Step 5 — Commit + push

```bash
git add migrations/008-*.sql
git commit -m "supabase(ddl): get_customer_stats RPC + rls policy"
git push origin <branche>
```

## Red Flags

**Ne JAMAIS :**
- Demander a l'utilisateur "Tu peux executer ce SQL dans Supabase ?" — casse le flow autonome
- Utiliser `supabase db push` si c'est pour du DDL custom (reserve aux migrations Drizzle/Prisma alignees)
- Laisser des `DROP FUNCTION` sans `IF EXISTS`
- Commit les passwords en clair dans le .env.example
- Utiliser `SECURITY DEFINER` sans definir `SET search_path = public` (CVE-2018-1058)

**Toujours :**
- Patterns idempotents (re-executable sans casser)
- Tester immediatement via RPC apres deploy
- Grant explicite a `anon` et/ou `authenticated` pour les fonctions publiques
- RLS policies pour tout table accessible via l'API REST Supabase

## Integration

**Agents concernes :**
- SEBASTIEN (backend, creation RPC)
- MORGAN (architecture, design des fonctions)
- CASEY (audit secu des policies RLS et SECURITY DEFINER)

**Pairs avec :**
- `am-sql-preprod-deploy` (pour les tables postgres classiques, pas Supabase-specific)
- Hook `guard.sh` (protection contre DROP destructifs)

## Reference

- Source : `feedback_supabase_ddl.md`
- Supabase docs : https://supabase.com/docs/guides/database/functions
- RLS best practices : https://supabase.com/docs/guides/database/postgres/row-level-security
- Security advisor CVE-2018-1058 : toujours `SET search_path = public` dans `SECURITY DEFINER`
