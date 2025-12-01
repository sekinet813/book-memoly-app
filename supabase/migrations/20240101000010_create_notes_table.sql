-- Create notes table
-- Note: book_id references books.local_id (not books.id) for sync compatibility
-- Foreign key constraint is not used to allow flexibility in sync operations
create table if not exists public.notes (
  id bigserial primary key,
  user_id text not null,
  local_id integer not null,
  book_id integer not null, -- References books.local_id (not books.id)
  content text not null,
  page_number integer,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint notes_user_local_unique unique(user_id, local_id)
);

-- Enable Row Level Security
alter table public.notes enable row level security;

-- RLS Policies for notes
create policy "Users can read their notes" on public.notes
  for select using (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can insert their notes" on public.notes
  for insert with check (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can update their notes" on public.notes
  for update using (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can delete their notes" on public.notes
  for delete using (auth.uid()::text = user_id or user_id = auth.uid()::text);

