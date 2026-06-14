-- Survivors' Pool — MVP sync store (no-login).
-- This is what backs cross-phone sync in the current build. The pool is saved
-- as one JSON document, keyed by its random invite link. The link is the only
-- credential: anyone who has it can read and write that one pool, and nobody
-- can dump the whole table, because direct anon access is denied and the two
-- functions below are the sole doorway.
--
-- This sits alongside schema.sql, it does not replace it. When you add Supabase
-- Auth and move to real accounts, migrate the document fields out into the
-- eleven normalised tables in schema.sql and retire this store.

create table if not exists pool_state (
  link       text primary key,
  state      jsonb not null,
  updated_at timestamptz not null default now()
);
alter table pool_state enable row level security;
-- no anon policies on purpose: the table is reachable only through the functions

create or replace function get_pool(p_link text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select state from pool_state where link = p_link;
$$;

create or replace function save_pool(p_link text, p_state jsonb)
returns void
language sql
security definer
set search_path = public
as $$
  insert into pool_state (link, state, updated_at)
  values (p_link, p_state, now())
  on conflict (link) do update set state = excluded.state, updated_at = now();
$$;

revoke all on function get_pool(text)        from public;
revoke all on function save_pool(text,jsonb) from public;
grant execute on function get_pool(text)        to anon, authenticated;
grant execute on function save_pool(text,jsonb) to anon, authenticated;
