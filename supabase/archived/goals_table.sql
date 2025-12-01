-- Supabase goals table definition for syncing reading goals
create table if not exists public.goals (
  id bigserial primary key,
  user_id text not null,
  local_id integer not null,
  period text not null check (period in ('monthly', 'yearly')),
  year integer not null,
  month integer,
  target_type text not null check (target_type in ('pages', 'books')),
  target_value integer not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint goals_user_local_unique unique(user_id, local_id)
);

alter table public.goals enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where polname = 'Users can read their goals'
  ) then
    create policy "Users can read their goals" on public.goals
      for select using (auth.uid() = user_id::uuid or user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where polname = 'Users can insert their goals'
  ) then
    create policy "Users can insert their goals" on public.goals
      for insert with check (auth.uid() = user_id::uuid or user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where polname = 'Users can update their goals'
  ) then
    create policy "Users can update their goals" on public.goals
      for update using (auth.uid() = user_id::uuid or user_id = auth.uid());
  end if;
end$$;
