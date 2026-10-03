-- ONeness Retailer Splash / Promotional Poster backend
-- Run once in Supabase SQL Editor before enabling the admin Splash Screens setting.
-- Poster images are uploaded to ImgBB by the existing product-image-upload Edge Function.
-- This table stores only the resulting public image URL and display rules.

begin;

create table if not exists public.retailer_splash_posters (
  id bigint generated always as identity primary key,
  title text not null default '',
  caption text not null default '',
  alt_text text not null default '',
  image_url text not null,
  button_label text not null default '',
  button_url text not null default '',
  audience text not null default 'all'
    check (audience in ('all','unregistered','registered','new_registered','returning_registered')),
  page_scope text[] not null default array['all']::text[],
  display_frequency text not null default 'once_per_session'
    check (display_frequency in ('always','once_per_session','once_per_day','once_per_account')),
  new_user_days integer not null default 7 check (new_user_days between 1 and 90),
  starts_at timestamptz null,
  ends_at timestamptz null,
  sort_order integer not null default 100,
  dismissible boolean not null default true,
  is_active boolean not null default true,
  created_by_profile_id integer null references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint retailer_splash_page_scope_nonempty check (cardinality(page_scope) > 0),
  constraint retailer_splash_time_range check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create index if not exists retailer_splash_active_idx
  on public.retailer_splash_posters(is_active, sort_order, id);

alter table public.retailer_splash_posters enable row level security;

drop policy if exists retailer_splash_admin_select on public.retailer_splash_posters;
drop policy if exists retailer_splash_admin_insert on public.retailer_splash_posters;
drop policy if exists retailer_splash_admin_update on public.retailer_splash_posters;
drop policy if exists retailer_splash_admin_delete on public.retailer_splash_posters;

create policy retailer_splash_admin_select
on public.retailer_splash_posters
for select to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.auth_id = auth.uid()
      and p.role in ('owner','admin')
      and p.status in ('verified','active')
      and (p.role='owner' or 'settings' = any(coalesce(p.permissions,'{}'::text[])) or 'settings.store' = any(coalesce(p.permissions,'{}'::text[])))
  )
);

create policy retailer_splash_admin_insert
on public.retailer_splash_posters
for insert to authenticated
with check (
  exists (
    select 1
    from public.profiles p
    where p.auth_id = auth.uid()
      and p.role in ('owner','admin')
      and p.status in ('verified','active')
      and (p.role='owner' or 'settings' = any(coalesce(p.permissions,'{}'::text[])) or 'settings.store' = any(coalesce(p.permissions,'{}'::text[])))
  )
);

create policy retailer_splash_admin_update
on public.retailer_splash_posters
for update to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.auth_id = auth.uid()
      and p.role in ('owner','admin')
      and p.status in ('verified','active')
      and (p.role='owner' or 'settings' = any(coalesce(p.permissions,'{}'::text[])) or 'settings.store' = any(coalesce(p.permissions,'{}'::text[])))
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.auth_id = auth.uid()
      and p.role in ('owner','admin')
      and p.status in ('verified','active')
      and (p.role='owner' or 'settings' = any(coalesce(p.permissions,'{}'::text[])) or 'settings.store' = any(coalesce(p.permissions,'{}'::text[])))
  )
);

create policy retailer_splash_admin_delete
on public.retailer_splash_posters
for delete to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.auth_id = auth.uid()
      and p.role in ('owner','admin')
      and p.status in ('verified','active')
      and (p.role='owner' or 'settings' = any(coalesce(p.permissions,'{}'::text[])) or 'settings.store' = any(coalesce(p.permissions,'{}'::text[])))
  )
);

grant select, insert, update, delete on public.retailer_splash_posters to authenticated;
grant usage, select on sequence public.retailer_splash_posters_id_seq to authenticated;

create or replace function public.retailer_splash_feed(p_page text default 'home')
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  pr public.profiles;
  result jsonb;
begin
  if uid is not null then
    select * into pr
    from public.profiles
    where auth_id=uid
    limit 1;
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id',s.id,
      'title',s.title,
      'caption',s.caption,
      'alt_text',s.alt_text,
      'image_url',s.image_url,
      'button_label',s.button_label,
      'button_url',s.button_url,
      'display_frequency',s.display_frequency,
      'dismissible',s.dismissible
    )
    order by s.sort_order asc,s.id desc
  ),'[]'::jsonb)
  into result
  from public.retailer_splash_posters s
  where s.is_active
    and (s.starts_at is null or s.starts_at<=now())
    and (s.ends_at is null or s.ends_at>now())
    and ('all'=any(s.page_scope) or coalesce(nullif(p_page,''),'home')=any(s.page_scope))
    and (
      s.audience='all'
      or (s.audience='unregistered' and (uid is null or pr.id is null))
      or (s.audience='registered' and pr.role='retailer')
      or (s.audience='new_registered' and pr.role='retailer'
          and pr.created_at >= now() - make_interval(days=>s.new_user_days))
      or (s.audience='returning_registered' and pr.role='retailer'
          and pr.created_at < now() - make_interval(days=>s.new_user_days))
    );

  return result;
end
$$;

revoke all on function public.retailer_splash_feed(text) from public;
grant execute on function public.retailer_splash_feed(text) to anon, authenticated;

commit;
