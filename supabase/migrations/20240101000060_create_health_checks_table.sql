-- Create health_checks table for API health monitoring
create table if not exists public.health_checks (
  id bigserial primary key,
  status text not null default 'ok',
  checked_at timestamptz not null default timezone('utc', now())
);

-- Insert a default health check record
insert into public.health_checks (status, checked_at)
values ('ok', timezone('utc', now()))
on conflict do nothing;

-- Enable Row Level Security (allow public read access for health checks)
alter table public.health_checks enable row level security;

-- Allow public read access to health_checks
create policy "Public can read health_checks" on public.health_checks
  for select using (true);

