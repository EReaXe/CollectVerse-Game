begin;
do $$ begin
 if to_regclass('public.trade_offers')is null then raise exception 'trade_offers missing';end if;
 if to_regclass('public.trade_offer_items')is null then raise exception 'trade_offer_items missing';end if;
 if to_regclass('public.trade_reserved_cards')is null then raise exception 'trade_reserved_cards missing';end if;
 if to_regprocedure('public.create_trade_offer(uuid,uuid[],uuid[],bigint,bigint,integer)')is null then raise exception 'create_trade_offer missing';end if;
 if to_regprocedure('public.accept_trade_offer(uuid)')is null then raise exception 'accept_trade_offer missing';end if;
 if not exists(select 1 from pg_policies where schemaname='public' and tablename='trade_reserved_cards' and policyname='trade_reservations_authenticated_read') then raise exception 'trade reservation visibility policy missing';end if;
end $$;
select 'direct_trades_ok' as result;
rollback;
