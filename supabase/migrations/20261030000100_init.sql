-- GPS-GYM initial schema (Week 2: web <-> iPhone sync + beta metrics).
-- Not wired into the clients yet. Gym coordinates are intentionally NOT stored server-side.

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  training_profile jsonb not null,      -- TrainingProfile (goal, experience, days, ...)
  plan jsonb not null,                  -- TrainingPlan snapshot
  enforcement jsonb not null default '{}'::jsonb, -- EnforcementState (no app identities: tokens never leave the device)
  updated_at timestamptz not null default now()
);

create table public.workouts (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  workout_day_id text not null,
  workout_name text not null,
  day_key date not null,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  mode text not null check (mode in ('gym', 'home')),
  planned_sets int not null,
  exercises jsonb not null,             -- ExerciseLog[] (weights/reps)
  is_verified boolean not null,
  location_status text not null check (location_status in ('atGym', 'awayFromGym', 'noSignal', 'notRequired')),
  trust text not null check (trust in ('high', 'medium', 'low')),
  client text not null check (client in ('ios', 'web')),
  created_at timestamptz not null default now()
);
create index workouts_user_started on public.workouts (user_id, started_at desc);

-- Product analytics for the beta (see docs/PRODUCT.md metrics).
create table public.events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,                   -- e.g. onboarding_completed, screen_time_authorized, emergency_unlock
  properties jsonb not null default '{}'::jsonb,
  client text not null check (client in ('ios', 'web')),
  occurred_at timestamptz not null default now()
);
create index events_name_time on public.events (name, occurred_at);

create table public.waitlist (
  id bigint generated always as identity primary key,
  email text not null unique check (position('@' in email) > 1),
  source text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.workouts enable row level security;
alter table public.events enable row level security;
alter table public.waitlist enable row level security;

create policy "own profile" on public.profiles
  for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "own workouts" on public.workouts
  for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Events are write-only from clients; analysis happens with the service role.
create policy "insert own events" on public.events
  for insert to authenticated with check ((select auth.uid()) = user_id);

-- Anyone can join the waitlist; nobody can read it from the client.
create policy "join waitlist" on public.waitlist
  for insert to anon, authenticated with check (true);
