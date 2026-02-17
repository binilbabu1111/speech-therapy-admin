-- Clean start: Drop existing policies to avoid conflicts
drop policy if exists "Users can view own data" on public.users;
drop policy if exists "Users can update own data" on public.users;
drop policy if exists "Users can insert own data" on public.users;
drop policy if exists "Admins can view all data" on public.users;
drop policy if exists "Admins can delete users" on public.users;
drop policy if exists "Admins can update users" on public.users;

-- Create table only if it doesn't exist
create table if not exists public.users (
  id uuid references auth.users not null primary key,
  email text,
  display_name text,
  avatar_url text,
  role text default 'user',
  status text default 'active', -- New column for session management
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Loophole: If the table exists but lacks the status column, add it clearly
do $$
begin
  if not exists (select 1 from information_schema.columns where table_name = 'users' and column_name = 'status') then
    alter table public.users add column status text default 'active';
  end if;
end $$;

-- Enable Row Level Security (RLS)
alter table public.users enable row level security;

-- Re-create Policies

-- Users can view own data ONLY if they are active
create policy "Users can view own data" on public.users
  for select using (auth.uid() = id and status = 'active');

-- Users can update own data ONLY if they are active
create policy "Users can update own data" on public.users
  for update using (auth.uid() = id and status = 'active');

-- Users can insert own data (usually sign up)
create policy "Users can insert own data" on public.users
  for insert with check (auth.uid() = id);
  
-- Create a secure function to check admin status (bypassing RLS recursion)
create or replace function public.is_admin()
returns boolean as $$
begin
  return exists (
    select 1 from public.users
    where id = auth.uid() and role = 'admin' and status = 'active'
  );
end;
$$ language plpgsql security definer;

-- Admin Policy: Admins can view all data
create policy "Admins can view all data" on public.users
  for select using (public.is_admin());

-- Admin Policy: Admins can update users (to block them)
create policy "Admins can update users" on public.users
  for update using (public.is_admin());

-- Admin Policy: Admins can delete users
create policy "Admins can delete users" on public.users
  for delete using (public.is_admin());
