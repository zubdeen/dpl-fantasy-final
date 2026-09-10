# DPL Fantasy Monorepo

A pnpm/Turborepo monorepo containing two independently deployable Next.js applications for DPL Fantasy Botswana:

- `apps/storefront` — customer-facing fantasy league experience, Supabase Auth login, dashboard, player pool, squad builder, fixtures, results, leaderboard, power-ups, and rules.
- `apps/admin` — separate admin boundary for managing players, clubs, fixtures, and gameweek lock settings.

Shared code lives in `packages/shared`, `packages/ui`, and `packages/supabase`. Both apps can be deployed independently to Vercel by setting the Vercel Root Directory to the relevant app and keeping the repository linked to the workspace.

## Setup

Copy `.env.example` to `.env.local` in each app (or configure the same variables in Vercel), then run:

```bash
pnpm install
pnpm --filter @dpl/storefront dev
pnpm --filter @dpl/admin dev
```

Run `supabase/schema.sql` in the Supabase SQL editor before using the data workflows. Authentication uses Supabase Auth with email/password and Google OAuth. Add each app's Vercel URL to Supabase Auth redirect URLs.

## Deploy

Create two Vercel projects from the same repository. Set the Root Directory to `apps/storefront` for the customer app and `apps/admin` for the admin app. Vercel detects Next.js automatically. Set the Supabase environment variables in both projects.
