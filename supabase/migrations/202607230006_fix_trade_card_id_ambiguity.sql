begin;

create or replace function public.create_trade_offer(
 p_recipient uuid,p_offered_cards uuid[] default '{}',p_requested_cards uuid[] default '{}',
 p_offered_gold bigint default 0,p_requested_gold bigint default 0,p_expires_hours integer default 48)
returns uuid language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); v_trade_id uuid; v_card_id uuid;
begin
 if uid is null then raise exception 'AUTH_REQUIRED'; end if;
 perform public.enforce_rate_limit('create_trade',12,60);
 if p_recipient is null or p_recipient=uid or not exists(select 1 from public.profiles where id=p_recipient) then raise exception 'INVALID_TRADE_RECIPIENT'; end if;
 if coalesce(p_offered_gold,0)<0 or coalesce(p_requested_gold,0)<0 then raise exception 'INVALID_GOLD_AMOUNT'; end if;
 if cardinality(coalesce(p_offered_cards,'{}'))+cardinality(coalesce(p_requested_cards,'{}'))=0 and coalesce(p_offered_gold,0)=0 and coalesce(p_requested_gold,0)=0 then raise exception 'EMPTY_TRADE'; end if;
 if p_expires_hours<1 or p_expires_hours>168 then raise exception 'INVALID_TRADE_EXPIRY'; end if;
 if coalesce(p_offered_cards,'{}')&&coalesce(p_requested_cards,'{}') then raise exception 'DUPLICATE_TRADE_CARD'; end if;
 perform 1 from public.profiles p where p.id in(uid,p_recipient) order by p.id for update;
 if (select p.gold from public.profiles p where p.id=uid)<coalesce(p_offered_gold,0) then raise exception 'NOT_ENOUGH_GOLD'; end if;
 insert into public.trade_offers(proposer_id,recipient_id,offered_gold,requested_gold,expires_at)
 values(uid,p_recipient,coalesce(p_offered_gold,0),coalesce(p_requested_gold,0),now()+make_interval(hours=>p_expires_hours)) returning id into v_trade_id;
 foreach v_card_id in array coalesce(p_offered_cards,'{}') loop
  perform 1 from public.player_cards pc where pc.id=v_card_id and pc.owner_id=uid and pc.retired_at is null for update;
  if not found then raise exception 'OFFERED_CARD_NOT_OWNED'; end if;
  if exists(select 1 from public.market_listings ml where ml.player_card_id=v_card_id and ml.status='active') then raise exception 'CARD_LISTED'; end if;
  insert into public.trade_offer_items(trade_id,player_card_id,owner_id,side) values(v_trade_id,v_card_id,uid,'offered');
  insert into public.trade_reserved_cards(player_card_id,trade_id,owner_id,reserved_at) values(v_card_id,v_trade_id,uid,now());
 end loop;
 foreach v_card_id in array coalesce(p_requested_cards,'{}') loop
  perform 1 from public.player_cards pc where pc.id=v_card_id and pc.owner_id=p_recipient and pc.retired_at is null for update;
  if not found then raise exception 'REQUESTED_CARD_NOT_OWNED'; end if;
  if exists(select 1 from public.market_listings ml where ml.player_card_id=v_card_id and ml.status='active') then raise exception 'CARD_LISTED'; end if;
  insert into public.trade_offer_items(trade_id,player_card_id,owner_id,side) values(v_trade_id,v_card_id,p_recipient,'requested');
  insert into public.trade_reserved_cards(player_card_id,trade_id,owner_id,reserved_at) values(v_card_id,v_trade_id,p_recipient,now());
 end loop;
 return v_trade_id;
end $$;

revoke all on function public.create_trade_offer(uuid,uuid[],uuid[],bigint,bigint,integer) from public,anon;
grant execute on function public.create_trade_offer(uuid,uuid[],uuid[],bigint,bigint,integer) to authenticated;

commit;
