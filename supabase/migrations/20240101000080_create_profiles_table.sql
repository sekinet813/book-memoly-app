-- Create profiles table for storing user profile information
create table if not exists public.profiles (
  user_id text primary key,
  name text not null default '',
  bio text,
  avatar_url text,
  reading_themes text[] not null default array[]::text[],
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

-- Enable Row Level Security
alter table public.profiles enable row level security;

-- Allow users to view their own profiles
create policy "Users can read their profiles" on public.profiles
  for select using (auth.uid()::text = user_id or user_id = auth.uid()::text);

-- Allow users to create their own profiles
create policy "Users can insert their profiles" on public.profiles
  for insert with check (auth.uid()::text = user_id or user_id = auth.uid()::text);

-- Allow users to update their own profiles
create policy "Users can update their profiles" on public.profiles
  for update using (auth.uid()::text = user_id or user_id = auth.uid()::text);
