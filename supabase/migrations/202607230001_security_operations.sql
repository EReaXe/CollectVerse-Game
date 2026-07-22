begin;

create table if not exists public.rate_limit_buckets (
  owner_id uuid not null references public.profiles(id) on delete cascade,
  action text not null,
  window_started_at timestamptz not null default clock_timestamp(),
  hits integer not null default 0 check (hits >= 0),
  primary key(owner_id,action)
);

create table if not exists public.economy_events (
  id bigint generated always as identity primary key,
  owner_id uuid references public.profiles(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  energy_delta numeric(24,2) not null default 0,
  gold_delta bigint not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.admin_audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  table_name text not null,
  record_id text,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create index if not exists economy_events_owner_idx on public.economy_events(owner_id,created_at desc);
create index if not exists economy_events_type_idx on public.economy_events(event_type,created_at desc);
create index if not exists admin_audit_actor_idx on public.admin_audit_log(actor_id,created_at desc);

create or replace function public.enforce_rate_limit(p_action text,p_max_hits integer,p_window_seconds integer)
returns void language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); bucket public.rate_limit_buckets;
begin
 if uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_action is null or p_max_hits<1 or p_window_seconds<1 then raise exception 'INVALID_RATE_LIMIT'; end if;
 insert into public.rate_limit_buckets(owner_id,action,window_started_at,hits)
 values(uid,p_action,clock_timestamp(),1)
 on conflict(owner_id,action) do update set
  window_started_at=case when public.rate_limit_buckets.window_started_at<=clock_timestamp()-make_interval(secs=>p_window_seconds) then clock_timestamp() else public.rate_limit_buckets.window_started_at end,
  hits=case when public.rate_limit_buckets.window_started_at<=clock_timestamp()-make_interval(secs=>p_window_seconds) then 1 else public.rate_limit_buckets.hits+1 end
 returning * into bucket;
 if bucket.hits>p_max_hits then raise exception 'RATE_LIMITED'; end if;
end $$;

create or replace function public.log_profile_economy_change()
returns trigger language plpgsql security definer set search_path=public as $$
declare energy_change numeric:=new.energy-old.energy; gold_change bigint:=new.gold-old.gold;
begin
 if energy_change<>0 or gold_change<>0 then
  insert into public.economy_events(owner_id,actor_id,event_type,energy_delta,gold_delta,metadata)
  values(new.id,auth.uid(),coalesce(nullif(current_setting('collectverse.event_type',true),''),'balance_change'),energy_change,gold_change,
   jsonb_build_object('total_energy_delta',new.total_energy-old.total_energy,'total_clicks_delta',new.total_clicks-old.total_clicks));
 end if;
 return new;
end $$;

create or replace function public.log_admin_change()
returns trigger language plpgsql security definer set search_path=public as $$
declare before_data jsonb; after_data jsonb; target_id text;
begin
 if not public.is_collectverse_admin() then if tg_op='DELETE' then return old; else return new; end if; end if;
 before_data:=case when tg_op='INSERT' then null else to_jsonb(old) end;
 after_data:=case when tg_op='DELETE' then null else to_jsonb(new) end;
 target_id:=coalesce(after_data->>'id',before_data->>'id',after_data->>'key',before_data->>'key',after_data->>'owner_id',before_data->>'owner_id');
 insert into public.admin_audit_log(actor_id,action,table_name,record_id,old_data,new_data)
 values(auth.uid(),tg_op,tg_table_name,target_id,before_data,after_data);
 if tg_op='DELETE' then return old; else return new; end if;
end $$;

drop trigger if exists profiles_economy_audit on public.profiles;
create trigger profiles_economy_audit after update of energy,gold,total_energy,total_clicks on public.profiles for each row execute function public.log_profile_economy_change();
drop trigger if exists audit_admin_profiles on public.profiles;
create trigger audit_admin_profiles after update on public.profiles for each row execute function public.log_admin_change();
drop trigger if exists audit_admin_cards on public.cards;
create trigger audit_admin_cards after insert or update or delete on public.cards for each row execute function public.log_admin_change();
drop trigger if exists audit_admin_sets on public.card_sets;
create trigger audit_admin_sets after insert or update or delete on public.card_sets for each row execute function public.log_admin_change();
drop trigger if exists audit_admin_packs on public.pack_types;
create trigger audit_admin_packs after insert or update or delete on public.pack_types for each row execute function public.log_admin_change();
drop trigger if exists audit_admin_notes on public.patch_notes;
create trigger audit_admin_notes after insert or update or delete on public.patch_notes for each row execute function public.log_admin_change();
drop trigger if exists audit_admin_settings on public.app_settings;
create trigger audit_admin_settings after insert or update or delete on public.app_settings for each row execute function public.log_admin_change();

alter table public.rate_limit_buckets enable row level security;
alter table public.economy_events enable row level security;
alter table public.admin_audit_log enable row level security;
drop policy if exists own_economy_events_read on public.economy_events;
create policy own_economy_events_read on public.economy_events for select to authenticated using(auth.uid()=owner_id or public.is_collectverse_admin());
drop policy if exists admin_audit_read on public.admin_audit_log;
create policy admin_audit_read on public.admin_audit_log for select to authenticated using(public.is_collectverse_admin());

revoke all on public.rate_limit_buckets,public.economy_events,public.admin_audit_log from anon,authenticated;
grant select on public.economy_events,public.admin_audit_log to authenticated;
revoke all on function public.enforce_rate_limit(text,integer,integer) from public,anon,authenticated;
revoke all on function public.log_profile_economy_change() from public,anon,authenticated;
revoke all on function public.log_admin_change() from public,anon,authenticated;

commit;
