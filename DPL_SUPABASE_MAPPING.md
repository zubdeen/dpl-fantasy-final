# DPL Supabase integration map

The fantasy storefront now reads the live `public.players` table from the DPL Supabase project when the app has valid Supabase environment variables and the table's RLS policy permits reads. It consumes the confirmed columns `id`, `name`, `team`, `category`, and `is_captain`. It also reads `public.fantasy_player_scores` and merges the latest row per player so the UI can show game points, wins, losses, and overall points alongside each name. The UI falls back to preview data if the environment variables are missing or the query is denied, so the app remains reviewable before deployment.

The inspected project currently contains these tables: `players` (44 records), `team_rankings` (6 records), `matches` (empty), `season5_lineup_nights` (empty), `season5_lineup_players` (empty), `season5_sit_out_ledger` (empty), `eliminator_matches` (empty), `teams` (present), `site_content` (present), and `user_roles` (present). The existing `players` table does not contain overall points, game points, wins, or losses. The tables that appear intended to hold night/match data are currently empty, so those metrics cannot be sourced without additional rows or a scoring view/table.

## To make the data fully live

Configure `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` in both Vercel projects. The supplied project URL is already included in the example files; the anon key must be supplied through Vercel environment settings and must not be committed as a secret.

If the point-tracking app starts storing results in a different table, add a read-only view or table with at least `player_id`, `gameweek_id`, `game_points`, `wins`, `losses`, `overall_points`, and `updated_at`. The fantasy app can then consume that view without duplicating score-entry workflows. Do not use the Supabase service-role key in browser code.
