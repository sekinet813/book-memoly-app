-- Create actions table
-- Note: book_id and note_id reference local_id values (not id) for sync compatibility
-- Foreign key constraints are not used to allow flexibility in sync operations
create table if not exists public.actions (
  id bigserial primary key,
  user_id text not null,
  local_id integer not null,
  book_id integer, -- References books.local_id (not books.id)
  note_id integer, -- References notes.local_id (not notes.id)
  title text not null,
  description text,
  due_date timestamptz,
  remind_at timestamptz,
  status text not null default 'pending', -- pending, done, skipped
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint actions_user_local_unique unique(user_id, local_id)
);

-- Enable Row Level Security
alter table public.actions enable row level security;

-- RLS Policies for actions
create policy "Users can read their actions" on public.actions
  for select using (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can insert their actions" on public.actions
  for insert with check (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can update their actions" on public.actions
  for update using (auth.uid()::text = user_id or user_id = auth.uid()::text);

create policy "Users can delete their actions" on public.actions
  for delete using (auth.uid()::text = user_id or user_id = auth.uid()::text);

