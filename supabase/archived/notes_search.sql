-- Full-text search support for notes
-- Adds a tsvector column and a trigger to keep it updated, and exposes
-- an RPC for filtered memo search across books and notes.

-- 1) Add search column and trigger helpers
alter table if exists public.notes
  add column if not exists search tsvector;

create or replace function public.update_note_search()
returns trigger as $$
begin
  new.search :=
    setweight(to_tsvector('japanese', coalesce(new.content, '')), 'A') ||
    setweight(
      to_tsvector(
        'japanese',
        coalesce(
          (select title from public.books b
            where b.local_id = new.book_id
              and b.user_id = new.user_id
            limit 1),
          ''
        )
      ),
      'B'
    ) ||
    setweight(
      to_tsvector('simple', coalesce(to_char(new.created_at, 'YYYY-MM-DD'), '')),
      'C'
    );
  return new;
end;
$$ language plpgsql;

create trigger notes_search_tsv_before
before insert or update on public.notes
for each row execute function public.update_note_search();

create index if not exists notes_search_idx on public.notes using gin(search);

-- 2) RPC for memo search with filters
create or replace function public.search_notes(
  p_user_id uuid,
  p_query text default null,
  p_book_ids int[] default null,
  p_tag_ids int[] default null,
  p_start_date date default null,
  p_end_date date default null,
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  note_id int,
  book_id int,
  content text,
  page_number int,
  created_at timestamptz,
  updated_at timestamptz,
  book_title text,
  google_books_id text,
  book_authors text,
  book_description text,
  book_thumbnail_url text,
  book_published_date text,
  book_page_count int,
  book_status int,
  book_started_at timestamptz,
  book_finished_at timestamptz,
  book_created_at timestamptz,
  book_updated_at timestamptz
) as $$
begin
  return query
  select
    n.local_id as note_id,
    n.book_id,
    n.content,
    n.page_number,
    n.created_at,
    n.updated_at,
    b.title as book_title,
    b.google_books_id,
    b.authors as book_authors,
    b.description as book_description,
    b.thumbnail_url as book_thumbnail_url,
    b.published_date as book_published_date,
    b.page_count as book_page_count,
    b.status as book_status,
    b.started_at as book_started_at,
    b.finished_at as book_finished_at,
    b.created_at as book_created_at,
    b.updated_at as book_updated_at
  from public.notes n
  join public.books b
    on b.local_id = n.book_id
   and b.user_id = n.user_id
  where (n.user_id::uuid = p_user_id or n.user_id = p_user_id::text)
    and (p_query is null or p_query = '' or n.search @@ plainto_tsquery('japanese', p_query))
    and (p_book_ids is null or n.book_id = any(p_book_ids))
    and (p_start_date is null or n.created_at::date >= p_start_date)
    and (p_end_date is null or n.created_at::date <= p_end_date)
    and (
      p_tag_ids is null
      or exists (
        select 1 from public.note_tags nt
        where nt.note_id = n.local_id
          and nt.tag_id = any(p_tag_ids)
      )
    )
  order by n.created_at desc
  limit p_limit offset p_offset;
end;
$$ language plpgsql stable;
