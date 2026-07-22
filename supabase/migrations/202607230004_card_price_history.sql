begin;

alter table public.market_listings add column if not exists card_variant public.card_variant;
update public.market_listings l set card_variant=pc.variant from public.player_cards pc where pc.id=l.player_card_id and l.card_variant is null;
create or replace function public.snapshot_market_listing_variant() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.player_card_id is not null then select variant into new.card_variant from public.player_cards where id=new.player_card_id; end if;
 return new;
end $$;
drop trigger if exists market_listing_variant_snapshot on public.market_listings;
create trigger market_listing_variant_snapshot before insert or update of player_card_id on public.market_listings for each row execute function public.snapshot_market_listing_variant();

create or replace function public.get_card_price_stats(p_card uuid,p_variant public.card_variant default 'Standard')
returns jsonb language plpgsql security definer set search_path=public as $$
declare base_value bigint; avg_value numeric; last_value bigint; sales_count integer; history jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 select greatest(1,ceil(c.score*10*case p_variant
   when 'Foil' then 1.5 when 'Gold Foil' then 2.5 when 'Black Edition' then 3
   when 'Rainbow Holo' then 4 when 'Animated' then 5 when 'Founder Edition' then 6
   when 'Beta Edition' then 4 else 1 end)::bigint)
 into base_value from public.cards c where c.id=p_card;
 if base_value is null then raise exception 'CARD_NOT_FOUND'; end if;
 select round(avg(coalesce(l.current_bid,l.price)))::numeric,count(*)::integer into avg_value,sales_count
 from public.market_listings l join public.player_cards pc on pc.id=l.player_card_id
 where l.card_id=p_card and coalesce(l.card_variant,pc.variant)=p_variant and l.status='sold';
 select coalesce(l.current_bid,l.price) into last_value
 from public.market_listings l join public.player_cards pc on pc.id=l.player_card_id
 where l.card_id=p_card and coalesce(l.card_variant,pc.variant)=p_variant and l.status='sold'
 order by l.sold_at desc nulls last limit 1;
 select coalesce(jsonb_agg(jsonb_build_object('date',sale_day,'average',average_price,'sales',day_sales) order by sale_day),'[]'::jsonb)
 into history from (
  select date(l.sold_at) as sale_day,round(avg(coalesce(l.current_bid,l.price)))::bigint average_price,count(*)::integer day_sales
  from public.market_listings l join public.player_cards pc on pc.id=l.player_card_id
  where l.card_id=p_card and coalesce(l.card_variant,pc.variant)=p_variant and l.status='sold' and l.sold_at>=current_date-29
  group by date(l.sold_at)
 ) daily;
 return jsonb_build_object('card_id',p_card,'variant',p_variant,'base_price',base_value,
  'average_price',avg_value,'last_price',last_value,'sales_count',sales_count,
  'suggested_price',coalesce(avg_value::bigint,last_value,base_value),'history',history);
end $$;

revoke all on function public.get_card_price_stats(uuid,public.card_variant) from public,anon;
revoke all on function public.snapshot_market_listing_variant() from public,anon,authenticated;
grant execute on function public.get_card_price_stats(uuid,public.card_variant) to authenticated;

commit;
