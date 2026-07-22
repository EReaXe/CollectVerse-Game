begin;
do $$ begin
 if to_regclass('public.card_fusions')is null then raise exception 'card_fusions missing';end if;
 if to_regprocedure('public.fuse_card_copies(uuid,public.card_variant)')is null then raise exception 'fuse_card_copies missing';end if;
 if not exists(select 1 from information_schema.columns where table_schema='public'and table_name='player_cards'and column_name='retired_at')then raise exception 'player_cards.retired_at missing';end if;
 if not(select relrowsecurity from pg_class where oid='public.card_fusions'::regclass)then raise exception 'card_fusions RLS disabled';end if;
end $$;
select 'card_fusion_ok'as result;
rollback;
