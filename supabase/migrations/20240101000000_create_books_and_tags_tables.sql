-- Create books table
create table if not exists public.books (
  id bigserial primary key,
  user_id text not null,
  local_id integer not null,
  google_books_id text,
  title text not null,
  authors text,
  description text,
  thumbnail_url text,
  published_date text,
  page_count integer,
  status integer not null default 0, -- 0: unread, 1: reading, 2: finished
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint books_user_local_unique unique(user_id, local_id)
);

-- Create tags table
create table if not exists public.tags (
  id bigserial primary key,
  user_id text not null,
  local_id integer not null,
  name text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint tags_user_local_unique unique(user_id, local_id)
);

-- Enable Row Level Security
alter table public.books enable row level security;
alter table public.tags enable row level security;

-- RLS Policies for books
create policy "Users can read their books" on public.books
  for select using (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can insert their books" on public.books
  for insert with check (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can update their books" on public.books
  for update using (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can delete their books" on public.books
  for delete using (auth.uid()::text = user_id or user_id = auth.uid()::text);

-- RLS Policies for tags
create policy "Users can read their tags" on public.tags
  for select using (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can insert their tags" on public.tags
  for insert with check (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can update their tags" on public.tags
  for update using (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can delete their tags" on public.tags
  for delete using (auth.uid()::text = user_id or user_id = auth.uid()::text);

