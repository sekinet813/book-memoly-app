-- Create reading_logs table
-- Note: book_id references books.local_id (not books.id) for sync compatibility
-- Foreign key constraint is not used to allow flexibility in sync operations
create table if not exists public.reading_logs (
  id bigserial primary key,
  user_id text not null,
  local_id integer not null,
  book_id integer not null, -- References books.local_id (not books.id)
  start_page integer,
  end_page integer,
  duration_minutes integer,
  logged_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint reading_logs_user_local_unique unique(user_id, local_id)
);

-- Enable Row Level Security
alter table public.reading_logs enable row level security;

-- RLS Policies for reading_logs
create policy "Users can read their reading_logs" on public.reading_logs
  for select using (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can insert their reading_logs" on public.reading_logs
  for insert with check (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can update their reading_logs" on public.reading_logs
  for update using (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can delete their reading_logs" on public.reading_logs
  for delete using (auth.uid()::text = user_id or user_id = auth.uid()::text);

