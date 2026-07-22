begin;
select plan(4);
select has_function('public','get_card_price_stats',array['uuid','card_variant'],'price stats RPC exists');
select function_returns('public','get_card_price_stats',array['uuid','card_variant'],'jsonb','price stats returns jsonb');
select function_privs_are('public','get_card_price_stats',array['uuid','card_variant'],'authenticated',array['EXECUTE'],'authenticated can read price stats');
select function_privs_are('public','get_card_price_stats',array['uuid','card_variant'],'anon',array[]::text[],'anon cannot read price stats');
select * from finish();
rollback;
