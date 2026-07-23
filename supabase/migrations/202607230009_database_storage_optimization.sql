begin;

create table if not exists public.economy_daily_summaries (
  owner_id uuid not null references public.profiles(id) on delete cascade,
  summary_date date not null default (timezone('utc',now()))::date,
  energy_delta numeric(24,2) not null default 0,
  total_energy_delta numeric(24,2) not null default 0,
  total_clicks_delta bigint not null default 0,
  update_count integer not null default 0 check(update_count>=0),
  updated_at timestamptz not null default now(),
  primary key(owner_id,summary_date)
);

insert into public.economy_daily_summaries(
  owner_id,summary_date,energy_delta,total_energy_delta,total_clicks_delta,update_count,updated_at
)
select
  owner_id,
  (timezone('utc',created_at))::date,
  sum(energy_delta),
  sum(case when jsonb_typeof(metadata->'total_energy_delta')='number' then(metadata->>'total_energy_delta')::numeric else 0 end),
  sum(case when jsonb_typeof(metadata->'total_clicks_delta')='number' then(metadata->>'total_clicks_delta')::bigint else 0 end),
  count(*)::integer,
  max(created_at)
from public.economy_events
where owner_id is not null and created_at>=now()-interval '730 days'
group by owner_id,(timezone('utc',created_at))::date
on conflict(owner_id,summary_date)do nothing;

create index if not exists economy_events_created_idx on public.economy_events(created_at);
create index if not exists admin_audit_created_idx on public.admin_audit_log(created_at);
create index if not exists notifications_read_cleanup_idx on public.notifications(read_at,created_at) where read_at is not null;
create index if not exists market_listings_cleanup_idx on public.market_listings(status,updated_at);
create index if not exists market_bids_created_idx on public.market_bids(created_at);
create index if not exists trade_offers_cleanup_idx on public.trade_offers(status,updated_at);
create index if not exists player_cards_retired_cleanup_idx on public.player_cards(retired_at) where retired_at is not null;
create index if not exists system_card_pool_claimed_cleanup_idx on public.system_card_pool(claimed_at) where claimed_at is not null;
create index if not exists daily_claims_date_idx on public.daily_claims(claim_date);
create index if not exists rate_limit_window_idx on public.rate_limit_buckets(window_started_at);

create or replace function public.log_profile_economy_change()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  energy_change numeric:=new.energy-old.energy;
  gold_change bigint:=new.gold-old.gold;
  total_energy_change numeric:=new.total_energy-old.total_energy;
  total_clicks_change bigint:=new.total_clicks-old.total_clicks;
  event_name text:=coalesce(nullif(current_setting('collectverse.event_type',true),''),'balance_change');
begin
  if energy_change<>0 or total_energy_change<>0 or total_clicks_change<>0 then
    insert into public.economy_daily_summaries(
      owner_id,summary_date,energy_delta,total_energy_delta,total_clicks_delta,update_count,updated_at
    )
    values(
      new.id,(timezone('utc',now()))::date,energy_change,total_energy_change,total_clicks_change,1,now()
    )
    on conflict(owner_id,summary_date) do update set
      energy_delta=public.economy_daily_summaries.energy_delta+excluded.energy_delta,
      total_energy_delta=public.economy_daily_summaries.total_energy_delta+excluded.total_energy_delta,
      total_clicks_delta=public.economy_daily_summaries.total_clicks_delta+excluded.total_clicks_delta,
      update_count=public.economy_daily_summaries.update_count+1,
      updated_at=now();
  end if;

  -- Ayrıntılı olay tablosu yalnızca Gold değişikliklerini tutar.
  -- Enerji hareketleri yukarıdaki günlük özette birleşir.
  if gold_change<>0 then
    insert into public.economy_events(owner_id,actor_id,event_type,energy_delta,gold_delta,metadata)
    values(
      new.id,auth.uid(),event_name,energy_change,gold_change,
      jsonb_build_object(
        'total_energy_delta',total_energy_change,
        'total_clicks_delta',total_clicks_change
      )
    );
  end if;
  return new;
end $$;

create or replace function public.log_admin_change()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  before_row jsonb;
  after_row jsonb;
  before_data jsonb;
  after_data jsonb;
  target_id text;
begin
  if not public.is_collectverse_admin() then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;

  before_row:=case when tg_op='INSERT' then null else to_jsonb(old) end;
  after_row:=case when tg_op='DELETE' then null else to_jsonb(new) end;

  if tg_op='UPDATE' then
    select coalesce(jsonb_object_agg(b.key,b.value),'{}'::jsonb)
      into before_data
      from jsonb_each(before_row) b
      where after_row->b.key is distinct from b.value;
    select coalesce(jsonb_object_agg(a.key,a.value),'{}'::jsonb)
      into after_data
      from jsonb_each(after_row) a
      where before_row->a.key is distinct from a.value;
  else
    before_data:=before_row;
    after_data:=after_row;
  end if;

  target_id:=coalesce(
    after_row->>'id',before_row->>'id',
    after_row->>'key',before_row->>'key',
    after_row->>'owner_id',before_row->>'owner_id'
  );
  insert into public.admin_audit_log(actor_id,action,table_name,record_id,old_data,new_data)
  values(auth.uid(),tg_op,tg_table_name,target_id,before_data,after_data);
  if tg_op='DELETE' then return old; else return new; end if;
end $$;

create or replace function public.run_database_maintenance(p_batch_size integer default 5000)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  batch_size integer:=greatest(100,least(coalesce(p_batch_size,5000),20000));
  deleted_count integer;
  result jsonb:='{}'::jsonb;
begin
  if session_user not in('postgres','supabase_admin')and not public.is_collectverse_admin() then raise exception 'ADMIN_REQUIRED'; end if;

  with targets as (
    select id from public.notifications
    where (read_at is not null and read_at<now()-interval '30 days')
       or created_at<now()-interval '180 days'
    order by created_at limit batch_size
  )
  delete from public.notifications n using targets t where n.id=t.id;
  get diagnostics deleted_count=row_count;
  result:=result||jsonb_build_object('notifications',deleted_count);

  with targets as (
    select id from public.economy_events
    where (event_type='balance_change' and gold_delta=0 and created_at<now()-interval '7 days')
       or created_at<now()-interval '365 days'
    order by created_at limit batch_size
  )
  delete from public.economy_events e using targets t where e.id=t.id;
  get diagnostics deleted_count=row_count;
  result:=result||jsonb_build_object('economy_events',deleted_count);

  with targets as (
    select id from public.admin_audit_log
    where created_at<now()-interval '365 days'
    order by created_at limit batch_size
  )
  delete from public.admin_audit_log a using targets t where a.id=t.id;
  get diagnostics deleted_count=row_count;
  result:=result||jsonb_build_object('admin_audit_log',deleted_count);

  with targets as (
    select b.id
    from public.market_bids b
    join public.market_listings l on l.id=b.listing_id
    where l.status<>'active' and b.created_at<now()-interval '90 days'
    order by b.created_at limit batch_size
  )
  delete from public.market_bids b using targets t where b.id=t.id;
  get diagnostics deleted_count=row_count;
  result:=result||jsonb_build_object('market_bids',deleted_count);

  with targets as (
    select id from public.market_listings
    where status<>'active' and updated_at<now()-interval '180 days'
    order by updated_at limit batch_size
  )
  delete from public.market_listings l using targets t where l.id=t.id;
  get diagnostics deleted_count=row_count;
  result:=result||jsonb_build_object('market_listings',deleted_count);

  with targets as (
    select id from public.trade_offers
    where status<>'pending' and updated_at<now()-interval '180 days'
    order by updated_at limit batch_size
  )
  delete from public.trade_offers o using targets t where o.id=t.id;
  get diagnostics deleted_count=row_count;
  result:=result||jsonb_build_object('trade_offers',deleted_count);

  with targets as (
    select id from public.player_cards
    where retired_at<now()-interval '365 days'
      and not exists(select 1 from public.trade_offer_items i where i.player_card_id=player_cards.id)
      and not exists(select 1 from public.card_fusions f where f.output_player_card_id=player_cards.id)
    order by retired_at limit batch_size
  )
  delete from public.player_cards p using targets t where p.id=t.id;
  get diagnostics deleted_count=row_count;
  result:=result||jsonb_build_object('retired_player_cards',deleted_count);

  with targets as (
    select id from public.system_card_pool
    where claimed_at<now()-interval '180 days'
    order by claimed_at limit batch_size
  )
  delete from public.system_card_pool p using targets t where p.id=t.id;
  get diagnostics deleted_count=row_count;
  result:=result||jsonb_build_object('claimed_system_pool',deleted_count);

  with targets as (
    select owner_id,claim_date from public.daily_claims
    where claim_date<(timezone('utc',now()))::date-400
    order by claim_date limit batch_size
  )
  delete from public.daily_claims d using targets t
  where d.owner_id=t.owner_id and d.claim_date=t.claim_date;
  get diagnostics deleted_count=row_count;
  result:=result||jsonb_build_object('daily_claims',deleted_count);

  delete from public.rate_limit_buckets
  where ctid in (
    select ctid from public.rate_limit_buckets
    where window_started_at<clock_timestamp()-interval '1 day'
    order by window_started_at limit batch_size
  );
  get diagnostics deleted_count=row_count;
  result:=result||jsonb_build_object('rate_limit_buckets',deleted_count);

  delete from public.economy_daily_summaries
  where ctid in (
    select ctid from public.economy_daily_summaries
    where summary_date<(timezone('utc',now()))::date-730
    order by summary_date limit batch_size
  );
  get diagnostics deleted_count=row_count;
  result:=result||jsonb_build_object('economy_daily_summaries',deleted_count);

  return result||jsonb_build_object('batch_size',batch_size,'completed_at',now());
end $$;

alter table public.economy_daily_summaries enable row level security;
drop policy if exists own_economy_daily_summaries_read on public.economy_daily_summaries;
create policy own_economy_daily_summaries_read
on public.economy_daily_summaries
for select to authenticated
using(auth.uid()=owner_id or public.is_collectverse_admin());

revoke all on public.economy_daily_summaries from anon,authenticated;
grant select on public.economy_daily_summaries to authenticated;
revoke all on function public.run_database_maintenance(integer) from public,anon,authenticated;
grant execute on function public.run_database_maintenance(integer) to authenticated;

do $schedule$
declare already_scheduled boolean:=false;
begin
  if to_regclass('cron.job')is not null then
    execute 'select exists(select 1 from cron.job where jobname=$1)'
      into already_scheduled using 'collectverse-database-maintenance';
    if not already_scheduled then
      execute $sql$select cron.schedule(
        'collectverse-database-maintenance',
        '17 3 * * *',
        'select public.run_database_maintenance(5000)'
      )$sql$;
    end if;
  end if;
exception when insufficient_privilege then
  null;
end
$schedule$;

commit;
