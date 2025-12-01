-- Create book_tags junction table
-- Note: book_id and tag_id reference local_id values (not id) for sync compatibility
-- Foreign key constraints are not used to allow flexibility in sync operations
create table if not exists public.book_tags (
  id bigserial primary key,
  book_id integer not null, -- References books.local_id (not books.id)
  tag_id integer not null, -- References tags.local_id (not tags.id)
  constraint book_tags_unique unique(book_id, tag_id)
);

-- Create note_tags junction table
-- Note: note_id and tag_id reference local_id values (not id) for sync compatibility
-- Foreign key constraints are not used to allow flexibility in sync operations
create table if not exists public.note_tags (
  id bigserial primary key,
  note_id integer not null, -- References notes.local_id (not notes.id)
  tag_id integer not null, -- References tags.local_id (not tags.id)
  constraint note_tags_unique unique(note_id, tag_id)
);

-- Enable Row Level Security
alter table public.book_tags enable row level security;
alter table public.note_tags enable row level security;

-- RLS Policies for book_tags
-- Users can only access book_tags for their own books
create policy "Users can read their book_tags" on public.book_tags
  for select using (
    exists (
      select 1 from public.books b
      where b.id = book_tags.book_id
        and (auth.uid()::text = b.user_id or b.user_id = auth.uid()::text)
    )
  );

create policy "Users can insert their book_tags" on public.book_tags
  for insert with check (
    exists (
      select 1 from public.books b
      where b.id = book_tags.book_id
        and (auth.uid()::text = b.user_id or b.user_id = auth.uid()::text)
    )
  );

create policy "Users can delete their book_tags" on public.book_tags
  for delete using (
    exists (
      select 1 from public.books b
      where b.id = book_tags.book_id
        and (auth.uid()::text = b.user_id or b.user_id = auth.uid()::text)
    )
  );

-- RLS Policies for note_tags
-- Users can only access note_tags for their own notes
create policy "Users can read their note_tags" on public.note_tags
  for select using (
    exists (
      select 1 from public.notes n
      where n.id = note_tags.note_id
        and (auth.uid()::text = n.user_id or n.user_id = auth.uid()::text)
    )
  );

create policy "Users can insert their note_tags" on public.note_tags
  for insert with check (
    exists (
      select 1 from public.notes n
      where n.id = note_tags.note_id
        and (auth.uid()::text = n.user_id or n.user_id = auth.uid()::text)
    )
  );

create policy "Users can delete their note_tags" on public.note_tags
  for delete using (
    exists (
      select 1 from public.notes n
      where n.id = note_tags.note_id
        and (auth.uid()::text = n.user_id or n.user_id = auth.uid()::text)
    )
  );

