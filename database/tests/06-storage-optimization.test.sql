begin;
select plan(5);
select has_table('public','economy_daily_summaries','daily economy summaries exist');
select has_function('public','run_database_maintenance',array['integer'],'maintenance RPC exists');
select has_index('public','notifications','notifications_read_cleanup_idx','notification cleanup index exists');
select has_index('public','trade_offers','trade_offers_cleanup_idx','trade cleanup index exists');
select has_index('public','player_cards','player_cards_retired_cleanup_idx','retired card cleanup index exists');
select * from finish();
rollback;
