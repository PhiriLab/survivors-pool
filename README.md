# Survivors' Pool

A social companion for World Cup 2026. You are dealt nations, you watch them live or die, you crow or you mourn, and a small honest scoreboard keeps the argument going from the group stage to the final in New Jersey on 19 July 2026.

This build is already wired to Supabase. With one value pasted in, a pool stops living on a single phone and follows everyone who holds the invite link.

## Run it locally

Open `index.html` in any browser. That is the whole requirement. With no key set it runs in local mode, saving to the device, exactly as the original single-file version.

## Turn on cross-phone sync (one line)

Open `index.html`, find this near the top of the script:

```js
const SUPABASE_URL = 'https://dkvqcnuoaptvdjorreyb.supabase.co';
const SUPABASE_KEY = ''; // <-- paste your publishable key here to switch sync on
```

The URL is already your live project. To find the key, open your Supabase dashboard, go to Project Settings, then API, and copy the publishable key (it begins with `sb_publishable_`). Paste it between the quotes. Save. Sync is now on. Never paste the service role key here, only the publishable one.

## How sync works

A pool is saved as one JSON document, keyed by its random invite link, in the `pool_state` table. The reads and writes go through two security-definer functions, `get_pool` and `save_pool`, so the public key cannot read or dump any pool but the one whose link you already hold. The invite card shows a real link of the form `your-domain/?pool=sp-xxxxxx`. Open that link on another phone and the same pool loads. A light background sync pulls every few seconds and whenever the tab regains focus, so a friend entering a result shows up on your screen on its own. Last write wins, which suits a kitchen-table football pool.

The eleven normalised tables in `supabase/schema.sql` are the target for the fuller build with real accounts and per-row realtime. The document store in `supabase/state.sql` is the MVP path that ships working sync today without a login. Both already live in your project.

## What is deployed

Running this build's setup created, in your Supabase project:

- the eleven tables of `schema.sql` (`users`, `pools`, `pool_members`, `teams`, `team_assignments`, `matches`, `standings_snapshots`, `scoring_rules`, `score_events`, `leaderboard_rows`, `messages`), with Row Level Security and the 48 seeded nations
- the `pool_state` table and the `get_pool` / `save_pool` functions of `state.sql`, which back the live sync

## One honest limit

The database round trip was verified server-side. The first real browser-to-database handshake happens on your machine, the moment you paste the key and load the page, because the app runs in a browser and the setup did not. If anything misbehaves, open the browser console and confirm the key is the publishable one and the page is served over http or https rather than opened from a file path.

Results still come from the Admin tab or the simulator until you point the `matches` table at a live fixtures feed. The 48 nations and groups are the official draw of 5 December 2025, a starting position the real results overwrite, not a forecast.

## Deploy to Vercel

1. Push this repo to GitHub (commands below).
2. In Vercel, choose New Project and import the repo.
3. Framework preset: Other. Build command: none. Output directory: the repo root.
4. Deploy. Vercel serves `index.html` as a static PWA. Once it is live, the invite link automatically uses your real domain.

## Push to GitHub

From this folder:

```bash
git init
git add .
git commit -m "Survivors' Pool: World Cup 2026 folk game, Supabase wired"
git branch -M main
git remote add origin https://github.com/PhiriLab/survivors-pool.git
git push -u origin main
```

Create the empty `survivors-pool` repository on GitHub first (do not add a README or .gitignore there, this repo already has them), then run the lines above as they stand.
