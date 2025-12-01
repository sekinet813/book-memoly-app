-- Create goals table (from existing goals_table.sql)
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

-- Enable Row Level Security
alter table public.goals enable row level security;

-- RLS Policies for goals
create policy "Users can read their goals" on public.goals
  for select using (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can insert their goals" on public.goals
  for insert with check (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can update their goals" on public.goals
  for update using (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can delete their goals" on public.goals
  for delete using (auth.uid()::text = user_id or user_id = auth.uid()::text);

