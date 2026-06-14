-- ============================================================================
-- SURVIVORS' POOL — World Cup 2026 folk game
-- Supabase / PostgreSQL schema
-- ----------------------------------------------------------------------------
-- This is the production backend the single-file app (survivors-pool.html) is
-- written to grow into. The browser build persists through a small Store
-- adapter (window.storage, then localStorage, then memory). Each key in that
-- adapter has a home in a table below, under the exact names you asked for:
--
--   users, pools, pool_members, teams, team_assignments, matches,
--   standings_snapshots, scoring_rules, score_events, leaderboard_rows,
--   messages
--
-- To go live: create a Supabase project, run this file in the SQL editor,
-- then replace the Store adapter's get/set/remove calls with supabase-js
-- queries against these tables. Row Level Security is on from the first line,
-- so a pool stays private to its members until you decide otherwise.
-- ============================================================================

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- ENUMS
-- ----------------------------------------------------------------------------
do $$ begin
  create type draft_method   as enum ('random','snake','auction','manual');
  create type scoring_preset as enum ('classic','underdog','brutal','custom');
  create type member_role    as enum ('host','player');
  create type knockout_stage as enum ('GROUP','R32','R16','QF','SF','FINAL','CHAMPION','OUT');
  create type match_status   as enum ('scheduled','live','final');
  create type message_kind   as enum ('chat','taunt','system','funeral','glory');
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- users
--   Thin profile over Supabase auth.users. The browser build has no real
--   accounts, so a "player" there is just a name string inside a pool. Here a
--   user is a durable identity that can belong to many pools across many cups.
-- ----------------------------------------------------------------------------
create table if not exists users (
  id          uuid primary key default uuid_generate_v4(),
  auth_uid    uuid unique references auth.users (id) on delete cascade,
  handle      text not null check (char_length(handle) between 1 and 40),
  avatar_url  text,
  created_at  timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- pools
--   One private (or public) league. Mirrors the pool object the host creates
--   on the first screen: name, scoring preset, draft method, lock state,
--   visibility, teams-per-player.
-- ----------------------------------------------------------------------------
create table if not exists pools (
  id              uuid primary key default uuid_generate_v4(),
  name            text not null check (char_length(name) between 1 and 80),
  host_id         uuid not null references users (id) on delete restrict,
  scoring_preset  scoring_preset not null default 'classic',
  draft_method    draft_method   not null default 'random',
  teams_per_user  int  not null default 2 check (teams_per_user between 1 and 6),
  is_public       boolean not null default false,
  is_locked       boolean not null default false,
  lock_deadline   timestamptz,
  invite_code     text unique not null default encode(gen_random_bytes(6),'hex'),
  created_at      timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- pool_members
--   Join of users to pools, with role and the seat order used by snake and
--   auction drafts. In the browser build this is the players array.
-- ----------------------------------------------------------------------------
create table if not exists pool_members (
  id          uuid primary key default uuid_generate_v4(),
  pool_id     uuid not null references pools (id) on delete cascade,
  user_id     uuid not null references users (id) on delete cascade,
  role        member_role not null default 'player',
  seat_order  int not null default 0,
  joined_at   timestamptz not null default now(),
  unique (pool_id, user_id)
);

-- ----------------------------------------------------------------------------
-- teams
--   The 48 nations of the 2026 finals. This is reference data shared by every
--   pool, seeded at the bottom of this file from the official 5 Dec 2025 draw.
--   strength is a rough seed weight the simulator uses; the live feed would
--   leave it untouched and update results through matches instead.
-- ----------------------------------------------------------------------------
create table if not exists teams (
  id           uuid primary key default uuid_generate_v4(),
  code         text unique not null,            -- short slug, e.g. 'BRA'
  name         text not null,
  flag_emoji   text,
  group_letter char(1) not null check (group_letter between 'A' and 'L'),
  is_favourite boolean not null default false,  -- Pot 1; everyone else earns the underdog bonus
  strength     int not null default 50          -- simulator seed only, 1..99
);

-- ----------------------------------------------------------------------------
-- team_assignments
--   Who owns which nation in which pool. The heart of the folk game. A team
--   belongs to at most one member per pool; a member may hold up to six.
-- ----------------------------------------------------------------------------
create table if not exists team_assignments (
  id            uuid primary key default uuid_generate_v4(),
  pool_id       uuid not null references pools (id) on delete cascade,
  team_id       uuid not null references teams (id) on delete restrict,
  member_id     uuid not null references pool_members (id) on delete cascade,
  acquired_via  draft_method not null default 'random',
  auction_price int,                            -- null unless auction
  created_at    timestamptz not null default now(),
  unique (pool_id, team_id)
);

-- ----------------------------------------------------------------------------
-- matches
--   The fixture list. In the browser build results are entered by the admin or
--   produced by the simulator. A live fixtures API would write here instead,
--   and everything downstream (scoring, standings, bracket) would follow.
-- ----------------------------------------------------------------------------
create table if not exists matches (
  id             uuid primary key default uuid_generate_v4(),
  external_id    text unique,                   -- id from the live feed, when wired
  stage          knockout_stage not null default 'GROUP',
  group_letter   char(1),
  home_team_id   uuid references teams (id),
  away_team_id   uuid references teams (id),
  home_goals     int,
  away_goals     int,
  went_to_pens   boolean not null default false,
  status         match_status not null default 'scheduled',
  kickoff_at     timestamptz,
  updated_at     timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- standings_snapshots
--   A frozen view of a team's tournament state at a moment in time: its group
--   record, the furthest stage it has reached, whether it is out. The browser
--   build keeps the latest of these inline on each team; storing them as
--   snapshots here lets you replay a pool and animate a team's arc.
-- ----------------------------------------------------------------------------
create table if not exists standings_snapshots (
  id            uuid primary key default uuid_generate_v4(),
  pool_id       uuid not null references pools (id) on delete cascade,
  team_id       uuid not null references teams (id) on delete cascade,
  wins          int not null default 0,
  draws         int not null default 0,
  losses        int not null default 0,
  reached_stage knockout_stage not null default 'GROUP',
  is_out        boolean not null default false,
  clean_sheets  int not null default 0,
  pens_survived int not null default 0,
  taken_at      timestamptz not null default now()
);
create index if not exists idx_snap_pool_team on standings_snapshots (pool_id, team_id, taken_at desc);

-- ----------------------------------------------------------------------------
-- scoring_rules
--   The point values, per pool. Seeded from whichever preset the host chose,
--   then editable. These mirror DEFAULT_RULES in the browser build exactly.
-- ----------------------------------------------------------------------------
create table if not exists scoring_rules (
  id                uuid primary key default uuid_generate_v4(),
  pool_id           uuid not null unique references pools (id) on delete cascade,
  group_win         int not null default 3,
  group_draw        int not null default 1,
  reach_r32         int not null default 4,
  reach_r16         int not null default 6,
  reach_qf          int not null default 10,
  reach_sf          int not null default 16,
  reach_final       int not null default 24,
  reach_champion    int not null default 40,
  underdog_bonus    int not null default 3,   -- per knockout round, non-favourites only
  exact_call_bonus  int not null default 10,  -- predicted a team's exact finishing stage
  clean_sheet_bonus int not null default 4,
  penalty_bonus     int not null default 4
);

-- ----------------------------------------------------------------------------
-- score_events
--   The append-only ledger. Every point a team earns is a row here, tagged
--   with the rule that minted it. Sum them and you have the leaderboard; this
--   is what makes scoring auditable and reversible when the admin corrects a
--   mistaken result.
-- ----------------------------------------------------------------------------
create table if not exists score_events (
  id          uuid primary key default uuid_generate_v4(),
  pool_id     uuid not null references pools (id) on delete cascade,
  team_id     uuid not null references teams (id) on delete cascade,
  member_id   uuid references pool_members (id) on delete set null,
  match_id    uuid references matches (id) on delete set null,
  rule_key    text not null,                  -- e.g. 'reach_qf', 'underdog_bonus'
  points      int not null,
  note        text,
  created_at  timestamptz not null default now()
);
create index if not exists idx_events_pool on score_events (pool_id, created_at desc);

-- ----------------------------------------------------------------------------
-- leaderboard_rows
--   A materialised standing per member per pool. You can derive it live from
--   score_events, but keeping a row here makes the dashboard cheap and gives
--   realtime a single object to broadcast on each change.
-- ----------------------------------------------------------------------------
create table if not exists leaderboard_rows (
  id           uuid primary key default uuid_generate_v4(),
  pool_id      uuid not null references pools (id) on delete cascade,
  member_id    uuid not null references pool_members (id) on delete cascade,
  points       int not null default 0,
  teams_alive  int not null default 0,
  teams_total  int not null default 0,
  rank         int,
  updated_at   timestamptz not null default now(),
  unique (pool_id, member_id)
);

-- ----------------------------------------------------------------------------
-- messages
--   The banter wall: chat, taunts, and the system lines the app posts when a
--   champion is crowned or a nation falls. funeral and glory cards are stored
--   as their own kinds so the feed can render them as printed chalk cards.
-- ----------------------------------------------------------------------------
create table if not exists messages (
  id          uuid primary key default uuid_generate_v4(),
  pool_id     uuid not null references pools (id) on delete cascade,
  member_id   uuid references pool_members (id) on delete set null,
  kind        message_kind not null default 'chat',
  body        text not null,
  team_id     uuid references teams (id) on delete set null,  -- for funeral / glory cards
  created_at  timestamptz not null default now()
);
create index if not exists idx_messages_pool on messages (pool_id, created_at desc);

-- ============================================================================
-- ROW LEVEL SECURITY
--   A pool is private by default. A member sees only the pools they belong to
--   (or public ones); only the host mutates pool settings, assignments, and
--   results. Adjust to taste, but start closed.
-- ============================================================================
alter table users               enable row level security;
alter table pools               enable row level security;
alter table pool_members        enable row level security;
alter table team_assignments    enable row level security;
alter table standings_snapshots enable row level security;
alter table scoring_rules       enable row level security;
alter table score_events        enable row level security;
alter table leaderboard_rows    enable row level security;
alter table messages            enable row level security;
-- teams and matches are shared reference data: readable by all, written by service role.
alter table teams   enable row level security;
alter table matches enable row level security;

-- helper: the users.id for the current auth session
create or replace function current_user_id() returns uuid
language sql stable as $$
  select id from users where auth_uid = auth.uid()
$$;

-- helper: is the caller a member of this pool
create or replace function is_pool_member(p uuid) returns boolean
language sql stable as $$
  select exists (
    select 1 from pool_members m
    where m.pool_id = p and m.user_id = current_user_id()
  )
$$;

-- helper: is the caller the host of this pool
create or replace function is_pool_host(p uuid) returns boolean
language sql stable as $$
  select exists (
    select 1 from pools po
    where po.id = p and po.host_id = current_user_id()
  )
$$;

-- users: you see and edit yourself
create policy users_self_read  on users for select using (auth_uid = auth.uid());
create policy users_self_write on users for update using (auth_uid = auth.uid());
create policy users_self_ins   on users for insert with check (auth_uid = auth.uid());

-- pools: members read, public readable by anyone, only host writes
create policy pools_read  on pools for select using (is_public or is_pool_member(id));
create policy pools_host_upd on pools for update using (host_id = current_user_id());
create policy pools_ins   on pools for insert with check (host_id = current_user_id());

-- pool_members: members of the pool can read the roster; host manages it
create policy pm_read on pool_members for select using (is_pool_member(pool_id));
create policy pm_host on pool_members for all    using (is_pool_host(pool_id)) with check (is_pool_host(pool_id));

-- reference tables: read for everyone
create policy teams_read   on teams   for select using (true);
create policy matches_read on matches for select using (true);

-- everything scoped to a pool: members read, host writes
create policy ta_read   on team_assignments    for select using (is_pool_member(pool_id));
create policy ta_host   on team_assignments    for all    using (is_pool_host(pool_id)) with check (is_pool_host(pool_id));
create policy snap_read on standings_snapshots for select using (is_pool_member(pool_id));
create policy snap_host on standings_snapshots for all    using (is_pool_host(pool_id)) with check (is_pool_host(pool_id));
create policy sr_read   on scoring_rules       for select using (is_pool_member(pool_id));
create policy sr_host   on scoring_rules       for all    using (is_pool_host(pool_id)) with check (is_pool_host(pool_id));
create policy se_read   on score_events        for select using (is_pool_member(pool_id));
create policy se_host   on score_events        for all    using (is_pool_host(pool_id)) with check (is_pool_host(pool_id));
create policy lb_read   on leaderboard_rows    for select using (is_pool_member(pool_id));
create policy lb_host   on leaderboard_rows    for all    using (is_pool_host(pool_id)) with check (is_pool_host(pool_id));

-- messages: members read the wall and post their own; host can moderate
create policy msg_read on messages for select using (is_pool_member(pool_id));
create policy msg_ins  on messages for insert with check (
  is_pool_member(pool_id)
  and member_id in (select id from pool_members where pool_id = messages.pool_id and user_id = current_user_id())
);
create policy msg_host on messages for delete using (is_pool_host(pool_id));

-- ============================================================================
-- SEED: the 48 nations of the 2026 finals
--   Official draw of 5 December 2025. Favourites flag marks Pot 1; every other
--   nation earns the underdog bonus on each knockout round it survives. The
--   strength weights feed the simulator only and are deliberately rough; a live
--   feed never reads them. Treat this block as a starting position the real
--   results will overwrite, not as a prediction.
-- ============================================================================
insert into teams (code, name, flag_emoji, group_letter, is_favourite, strength) values
  ('MEX','Mexico','🇲🇽','A',true ,72),('RSA','South Africa','🇿🇦','A',false,58),('KOR','South Korea','🇰🇷','A',false,68),('CZE','Czechia','🇨🇿','A',false,66),
  ('CAN','Canada','🇨🇦','B',true ,70),('BIH','Bosnia & Herzegovina','🇧🇦','B',false,62),('QAT','Qatar','🇶🇦','B',false,55),('SUI','Switzerland','🇨🇭','B',false,74),
  ('BRA','Brazil','🇧🇷','C',true ,90),('MAR','Morocco','🇲🇦','C',false,78),('HAI','Haiti','🇭🇹','C',false,48),('SCO','Scotland','🏴','C',false,64),
  ('USA','USA','🇺🇸','D',true ,72),('PAR','Paraguay','🇵🇾','D',false,60),('AUS','Australia','🇦🇺','D',false,64),('TUR','Türkiye','🇹🇷','D',false,72),
  ('GER','Germany','🇩🇪','E',true ,86),('CUW','Curaçao','🇨🇼','E',false,46),('CIV','Côte d''Ivoire','🇨🇮','E',false,68),('ECU','Ecuador','🇪🇨','E',false,66),
  ('NED','Netherlands','🇳🇱','F',true ,85),('JPN','Japan','🇯🇵','F',false,74),('SWE','Sweden','🇸🇪','F',false,66),('TUN','Tunisia','🇹🇳','F',false,60),
  ('BEL','Belgium','🇧🇪','G',true ,82),('EGY','Egypt','🇪🇬','G',false,66),('IRN','Iran','🇮🇷','G',false,66),('NZL','New Zealand','🇳🇿','G',false,50),
  ('ESP','Spain','🇪🇸','H',true ,92),('CPV','Cabo Verde','🇨🇻','H',false,48),('KSA','Saudi Arabia','🇸🇦','H',false,58),('URU','Uruguay','🇺🇾','H',false,78),
  ('FRA','France','🇫🇷','I',true ,90),('SEN','Senegal','🇸🇳','I',false,76),('IRQ','Iraq','🇮🇶','I',false,54),('NOR','Norway','🇳🇴','I',false,72),
  ('ARG','Argentina','🇦🇷','J',true ,91),('ALG','Algeria','🇩🇿','J',false,66),('AUT','Austria','🇦🇹','J',false,70),('JOR','Jordan','🇯🇴','J',false,52),
  ('POR','Portugal','🇵🇹','K',true ,87),('COD','Congo DR','🇨🇩','K',false,58),('UZB','Uzbekistan','🇺🇿','K',false,56),('COL','Colombia','🇨🇴','K',false,78),
  ('ENG','England','🏴','L',true ,88),('CRO','Croatia','🇭🇷','L',false,76),('GHA','Ghana','🇬🇭','L',false,64),('PAN','Panama','🇵🇦','L',false,52)
on conflict (code) do nothing;

-- ============================================================================
-- OPTIONAL: realtime
--   In Supabase, add the per-pool tables to the realtime publication so every
--   client refreshes the dashboard, bracket, and banter wall the instant the
--   host enters a result.
-- ============================================================================
-- alter publication supabase_realtime add table
--   team_assignments, score_events, leaderboard_rows, messages, standings_snapshots;

-- ============================================================================
-- end of schema
-- ============================================================================
