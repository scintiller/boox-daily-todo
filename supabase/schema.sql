-- ============================================================
-- Daily Todo + Routines — Supabase (Postgres) schema
-- Paste this whole file into Supabase: SQL Editor > New query > Run
-- Safe to re-run (idempotent).
-- ============================================================

-- TASKS: one-off / dated to-do items ---------------------------------
create table if not exists public.tasks (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  notes        text,
  category     text,                                -- 工作 | 运动 | 生活
  done         boolean not null default false,
  due_date     date,
  created_at   timestamptz not null default now(),
  completed_at timestamptz,
  sort_order   int not null default 0,
  source       text not null default 'claude'      -- 'claude' | 'app'
);

-- ROUTINES: recurring weekly habits (e.g. tennis every Wed) ----------
create table if not exists public.routines (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  icon       text,
  category   text,                                  -- 工作 | 运动 | 生活
  weekdays   int[] not null default '{}',          -- ISO weekday: 1=Mon ... 7=Sun
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

-- ROUTINE_LOGS: per-day completion marks for routines ---------------
create table if not exists public.routine_logs (
  id         uuid primary key default gen_random_uuid(),
  routine_id uuid not null references public.routines(id) on delete cascade,
  date       date not null,
  done       boolean not null default true,
  created_at timestamptz not null default now(),
  unique (routine_id, date)
);

create index if not exists idx_tasks_done        on public.tasks(done);
create index if not exists idx_tasks_due         on public.tasks(due_date);
create index if not exists idx_logs_routine_date on public.routine_logs(routine_id, date);

-- Migrations (safe to re-run on existing databases) ------------------
alter table public.tasks    add column if not exists category text;   -- 工作 | 运动 | 生活
alter table public.routines add column if not exists category text;

-- Row Level Security ------------------------------------------------
-- Personal single-user app: enable RLS and let the anon/authenticated
-- keys (used by the Android app) do everything. The service_role key
-- (used by the Claude-side scripts) bypasses RLS automatically.
alter table public.tasks        enable row level security;
alter table public.routines     enable row level security;
alter table public.routine_logs enable row level security;

drop policy if exists anon_all_tasks    on public.tasks;
drop policy if exists anon_all_routines on public.routines;
drop policy if exists anon_all_logs     on public.routine_logs;

create policy anon_all_tasks    on public.tasks        for all to anon, authenticated using (true) with check (true);
create policy anon_all_routines on public.routines     for all to anon, authenticated using (true) with check (true);
create policy anon_all_logs     on public.routine_logs for all to anon, authenticated using (true) with check (true);
