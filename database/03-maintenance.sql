begin;

create or replace function public.run_database_maintenance(p_batch_size integer default 5000)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 batch_size integer:=greatest(100,least(coalesce(p_batch_size,5000),20000));
 deleted_count integer;
 result jsonb:='{}'::jsonb;
begin
 if session_user not in('postgres','supabase_admin')and not public.is_collectverse_admin() then raise exception 'ADMIN_REQUIRED';end if;

 with targets as(
  select id from public.notifications
  where(read_at is not null and read_at<now()-interval '30 days')or created_at<now()-interval '180 days'
  order by created_at limit batch_size
 )delete from public.notifications n using targets t where n.id=t.id;
 get diagnostics deleted_count=row_count;result:=result||jsonb_build_object('notifications',deleted_count);

 with targets as(
  select id from public.economy_events
  where(event_type='balance_change'and gold_delta=0 and created_at<now()-interval '7 days')or created_at<now()-interval '365 days'
  order by created_at limit batch_size
 )delete from public.economy_events e using targets t where e.id=t.id;
 get diagnostics deleted_count=row_count;result:=result||jsonb_build_object('economy_events',deleted_count);

 with targets as(
  select id from public.admin_audit_log where created_at<now()-interval '365 days'
  order by created_at limit batch_size
 )delete from public.admin_audit_log a using targets t where a.id=t.id;
 get diagnostics deleted_count=row_count;result:=result||jsonb_build_object('admin_audit_log',deleted_count);

 with targets as(
  select b.id from public.market_bids b join public.market_listings l on l.id=b.listing_id
  where l.status<>'active'and b.created_at<now()-interval '90 days'
  order by b.created_at limit batch_size
 )delete from public.market_bids b using targets t where b.id=t.id;
 get diagnostics deleted_count=row_count;result:=result||jsonb_build_object('market_bids',deleted_count);

 with targets as(
  select id from public.market_listings where status<>'active'and updated_at<now()-interval '180 days'
  order by updated_at limit batch_size
 )delete from public.market_listings l using targets t where l.id=t.id;
 get diagnostics deleted_count=row_count;result:=result||jsonb_build_object('market_listings',deleted_count);

 with targets as(
  select id from public.trade_offers where status<>'pending'and updated_at<now()-interval '180 days'
  order by updated_at limit batch_size
 )delete from public.trade_offers o using targets t where o.id=t.id;
 get diagnostics deleted_count=row_count;result:=result||jsonb_build_object('trade_offers',deleted_count);

 with targets as(
  select id from public.player_cards
  where retired_at<now()-interval '365 days'
   and not exists(select 1 from public.trade_offer_items i where i.player_card_id=player_cards.id)
   and not exists(select 1 from public.card_fusions f where f.output_player_card_id=player_cards.id)
  order by retired_at limit batch_size
 )delete from public.player_cards p using targets t where p.id=t.id;
 get diagnostics deleted_count=row_count;result:=result||jsonb_build_object('retired_player_cards',deleted_count);

 with targets as(
  select id from public.system_card_pool where claimed_at<now()-interval '180 days'
  order by claimed_at limit batch_size
 )delete from public.system_card_pool p using targets t where p.id=t.id;
 get diagnostics deleted_count=row_count;result:=result||jsonb_build_object('claimed_system_pool',deleted_count);

 with targets as(
  select owner_id,claim_date from public.daily_claims
  where claim_date<(timezone('utc',now()))::date-400 order by claim_date limit batch_size
 )delete from public.daily_claims d using targets t where d.owner_id=t.owner_id and d.claim_date=t.claim_date;
 get diagnostics deleted_count=row_count;result:=result||jsonb_build_object('daily_claims',deleted_count);

 delete from public.rate_limit_buckets where ctid in(
  select ctid from public.rate_limit_buckets
  where window_started_at<clock_timestamp()-interval '1 day'order by window_started_at limit batch_size
 );
 get diagnostics deleted_count=row_count;result:=result||jsonb_build_object('rate_limit_buckets',deleted_count);

 delete from public.economy_daily_summaries where ctid in(
  select ctid from public.economy_daily_summaries
  where summary_date<(timezone('utc',now()))::date-730 order by summary_date limit batch_size
 );
 get diagnostics deleted_count=row_count;result:=result||jsonb_build_object('economy_daily_summaries',deleted_count);

 return result||jsonb_build_object('batch_size',batch_size,'completed_at',now());
end $$;

revoke all on function public.run_database_maintenance(integer)from public,anon,authenticated;
grant execute on function public.run_database_maintenance(integer)to authenticated;

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
exception when insufficient_privilege then null;
end
$schedule$;

commit;
