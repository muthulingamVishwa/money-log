-- Money Log: database setup for Supabase
-- Run this once in your project: Dashboard > SQL Editor > New query > paste > Run.
-- Safe to re-run.

-- 1. Profiles: one row per account (username + monthly budget)
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  username    text not null unique check (username ~ '^[a-z0-9_]{3,20}$'),
  budget      numeric(14,2) check (budget is null or budget >= 0),
  created_at  timestamptz not null default now()
);

-- 2. Transactions: every income or expense entry
create table if not exists public.transactions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  type        text not null check (type in ('income', 'expense')),
  amount      numeric(14,2) not null check (amount > 0 and amount < 1000000000),
  category    text not null check (char_length(category) between 1 and 40),
  method      text not null default 'UPI' check (char_length(method) <= 30),
  note        text not null default '' check (char_length(note) <= 200),
  date        date not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists transactions_user_date_idx on public.transactions (user_id, date);

-- 2b. Accounts: bank accounts (or cash/wallets) with a starting balance.
--     Current balance = opening_balance + income - expenses linked to it.
create table if not exists public.accounts (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name             text not null check (char_length(name) between 1 and 40),
  opening_balance  numeric(14,2) not null default 0 check (opening_balance > -100000000000 and opening_balance < 100000000000),
  created_at       timestamptz not null default now()
);
create index if not exists accounts_user_idx on public.accounts (user_id);

-- Only the last 4 digits of an account number are stored, to tell accounts apart.
alter table public.accounts
  add column if not exists account_last4 text check (account_last4 ~ '^[0-9]{4}$');

alter table public.transactions
  add column if not exists account_id uuid references public.accounts (id) on delete set null;
create index if not exists transactions_account_idx on public.transactions (account_id);

-- 3. Row Level Security: each person can only see and change their own rows
alter table public.profiles enable row level security;
alter table public.transactions enable row level security;
alter table public.accounts enable row level security;

drop policy if exists "Read own accounts" on public.accounts;
create policy "Read own accounts" on public.accounts
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "Add own accounts" on public.accounts;
create policy "Add own accounts" on public.accounts
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "Edit own accounts" on public.accounts;
create policy "Edit own accounts" on public.accounts
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "Delete own accounts" on public.accounts;
create policy "Delete own accounts" on public.accounts
  for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "Read own profile" on public.profiles;
create policy "Read own profile" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);

drop policy if exists "Update own profile" on public.profiles;
create policy "Update own profile" on public.profiles
  for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

drop policy if exists "Read own transactions" on public.transactions;
create policy "Read own transactions" on public.transactions
  for select to authenticated using ((select auth.uid()) = user_id);

-- An entry may only be linked to one of the user's own accounts.
drop policy if exists "Add own transactions" on public.transactions;
create policy "Add own transactions" on public.transactions
  for insert to authenticated with check (
    (select auth.uid()) = user_id
    and (account_id is null or exists (
      select 1 from public.accounts a where a.id = account_id and a.user_id = (select auth.uid())))
  );

drop policy if exists "Edit own transactions" on public.transactions;
create policy "Edit own transactions" on public.transactions
  for update to authenticated using ((select auth.uid()) = user_id) with check (
    (select auth.uid()) = user_id
    and (account_id is null or exists (
      select 1 from public.accounts a where a.id = account_id and a.user_id = (select auth.uid())))
  );

drop policy if exists "Delete own transactions" on public.transactions;
create policy "Delete own transactions" on public.transactions
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Table access for signed-in users (Row Level Security above still limits them to their own rows).
grant select, insert, update, delete on public.transactions, public.accounts to authenticated;
revoke all on public.transactions, public.accounts from anon;

-- Usernames can't be changed from the app; only the budget can.
revoke insert, update, delete on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (budget) on public.profiles to authenticated;

-- 4. Create the profile automatically when someone signs up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, username)
  values (new.id, lower(new.raw_user_meta_data ->> 'username'));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 5. Let the signup form check whether a username is free
create or replace function public.username_available(name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (select 1 from public.profiles where username = lower(name));
$$;
revoke all on function public.username_available(text) from public;
grant execute on function public.username_available(text) to anon, authenticated;

-- 6. Tiny query the keep-alive job calls so the free project doesn't pause
create or replace function public.ping()
returns text
language sql
stable
as $$
  select 'pong'::text;
$$;
grant execute on function public.ping() to anon, authenticated;
