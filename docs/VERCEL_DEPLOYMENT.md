# Vercel deployment

This repository contains two independently deployable Next.js applications. Deploy them as **two Vercel projects** connected to the same repository.

## Storefront project

Create a Vercel project with the repository root directory set to `apps/storefront`. Leave the framework preset as **Next.js**. The package manager is detected from the root `packageManager` field. Configure these Production, Preview, and Development variables:

| Variable | Value |
| --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | The Supabase project URL used by the app |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | The Supabase publishable/anon key |

The storefront build command is `pnpm build` from the app root, or `pnpm --filter @dpl/storefront build` when building from the repository root. The included `next.config.mjs` transpiles the workspace packages and sets the monorepo tracing root.

## Admin project

Create a second Vercel project using the same repository and set its root directory to `apps/admin`. Configure:

| Variable | Value |
| --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | The same Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | The same Supabase publishable/anon key |
| `NEXT_PUBLIC_ADMIN_EMAIL` | The single email address permitted to use the admin console |

The admin build command is `pnpm build` from the app root, or `pnpm --filter @dpl/admin build` from the repository root.

## Supabase Auth settings

After Vercel assigns domains, add both domains to Supabase Authentication URL Configuration. Set the Site URL to the storefront domain and add the storefront and admin callback paths used by the application to the allowed redirect URLs. Keep the Supabase anon key in Vercel as a public environment variable; never expose a service-role key in either app.

## Database prerequisite

Run the checked-in `supabase/schema.sql` against the intended Supabase project before testing a deployment. It includes the profile trigger, fantasy tables, slot persistence, scoring tables, RLS policies, and the server-side fantasy rules RPCs. The RPCs enforce lock windows and the two-transfer limit even when a client attempts a direct REST write.

## Production checks

Before switching traffic to the Vercel domains, verify the following:

1. The storefront loads the DPL logo loading state and then redirects unauthenticated visitors to the sign-in experience.
2. A signed-in user can open the sidebar account menu, confirm sign-out, and return to the landing page.
3. The storefront can load players and the leaderboard from Supabase.
4. The admin project rejects an account whose email does not match `NEXT_PUBLIC_ADMIN_EMAIL`.
5. A new game-week deadline keeps locked-team transfers unavailable until `unlock_at`, then exposes exactly two transfers for that period.
6. Vercel Preview and Production both have the same Supabase environment variables and the corresponding URLs are present in Supabase Auth settings.
