-- Salt okunur veritabanı boyut ve büyüme raporu.
-- Supabase SQL Editor içinde çalıştırılabilir.

select
  n.nspname as schema_name,
  c.relname as object_name,
  case c.relkind when 'r' then 'table' when 'm' then 'materialized_view' end as object_type,
  pg_size_pretty(pg_total_relation_size(c.oid)) as total_size,
  pg_size_pretty(pg_relation_size(c.oid)) as table_size,
  pg_size_pretty(pg_indexes_size(c.oid)) as index_size,
  coalesce(s.n_live_tup,0) as estimated_rows,
  coalesce(s.n_dead_tup,0) as dead_rows,
  s.last_autovacuum,
  s.last_autoanalyze
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
left join pg_stat_user_tables s on s.relid=c.oid
where n.nspname='public'and c.relkind in('r','m')
order by pg_total_relation_size(c.oid)desc;

select
  'economy_events' as object_name,count(*) as row_count,min(created_at)as oldest,max(created_at)as newest
from public.economy_events
union all
select 'admin_audit_log',count(*),min(created_at),max(created_at)from public.admin_audit_log
union all
select 'notifications',count(*),min(created_at),max(created_at)from public.notifications
union all
select 'market_bids',count(*),min(created_at),max(created_at)from public.market_bids
union all
select 'market_listings',count(*),min(created_at),max(created_at)from public.market_listings
union all
select 'trade_offers',count(*),min(created_at),max(created_at)from public.trade_offers;

select
  indexrelname as index_name,
  relname as table_name,
  idx_scan,
  pg_size_pretty(pg_relation_size(indexrelid))as index_size
from pg_stat_user_indexes
order by pg_relation_size(indexrelid)desc,idx_scan;
