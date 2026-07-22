begin;

create table if not exists public.trade_offers (
 id uuid primary key default gen_random_uuid(), proposer_id uuid not null references public.profiles(id) on delete cascade,
 recipient_id uuid not null references public.profiles(id) on delete cascade, offered_gold bigint not null default 0 check(offered_gold>=0),
 requested_gold bigint not null default 0 check(requested_gold>=0), status text not null default 'pending' check(status in('pending','accepted','declined','cancelled','expired')),
 expires_at timestamptz not null default(now()+interval '48 hours'),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 constraint trade_distinct_players check(proposer_id<>recipient_id)
);
create table if not exists public.trade_offer_items (
 trade_id uuid not null references public.trade_offers(id) on delete cascade,player_card_id uuid not null references public.player_cards(id) on delete restrict,
 owner_id uuid not null references public.profiles(id) on delete cascade,side text not null check(side in('offered','requested')),primary key(trade_id,player_card_id)
);
create table if not exists public.trade_reserved_cards (
 player_card_id uuid primary key references public.player_cards(id) on delete cascade,trade_id uuid not null references public.trade_offers(id) on delete cascade,
 owner_id uuid not null references public.profiles(id) on delete cascade,reserved_at timestamptz not null default now()
);
create index if not exists trade_offers_proposer_idx on public.trade_offers(proposer_id,status,created_at desc);
create index if not exists trade_offers_recipient_idx on public.trade_offers(recipient_id,status,created_at desc);

create or replace function public.guard_trade_reserved_card()
returns trigger language plpgsql security definer set search_path=public as $$
declare target uuid:=case when tg_table_name='market_listings' then new.player_card_id else old.id end;
begin if target is not null and exists(select 1 from public.trade_reserved_cards where player_card_id=target)then raise exception 'CARD_RESERVED_FOR_TRADE';end if;if tg_op='DELETE'then return old;else return new;end if;end $$;
drop trigger if exists market_trade_reservation_guard on public.market_listings;
create trigger market_trade_reservation_guard before insert or update of player_card_id on public.market_listings for each row execute function public.guard_trade_reserved_card();
drop trigger if exists player_card_trade_reservation_guard on public.player_cards;
create trigger player_card_trade_reservation_guard before delete on public.player_cards for each row execute function public.guard_trade_reserved_card();

create or replace function public.create_trade_offer(p_recipient uuid,p_offered_cards uuid[] default '{}',p_requested_cards uuid[] default '{}',p_offered_gold bigint default 0,p_requested_gold bigint default 0,p_expires_hours integer default 48)
returns uuid language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); v_trade_id uuid; v_card_id uuid;
begin
 if uid is null then raise exception 'AUTH_REQUIRED'; end if; perform public.enforce_rate_limit('create_trade',12,60);
 if p_recipient is null or p_recipient=uid or not exists(select 1 from public.profiles where id=p_recipient) then raise exception 'INVALID_TRADE_RECIPIENT'; end if;
 if coalesce(p_offered_gold,0)<0 or coalesce(p_requested_gold,0)<0 then raise exception 'INVALID_GOLD_AMOUNT'; end if;
 if cardinality(coalesce(p_offered_cards,'{}'))+cardinality(coalesce(p_requested_cards,'{}'))=0 and coalesce(p_offered_gold,0)=0 and coalesce(p_requested_gold,0)=0 then raise exception 'EMPTY_TRADE'; end if;
 if p_expires_hours<1 or p_expires_hours>168 then raise exception 'INVALID_TRADE_EXPIRY'; end if;
 if coalesce(p_offered_cards,'{}')&&coalesce(p_requested_cards,'{}') then raise exception 'DUPLICATE_TRADE_CARD'; end if;
 perform 1 from public.profiles where id in(uid,p_recipient) order by id for update;
 if(select gold from public.profiles where id=uid)<coalesce(p_offered_gold,0) then raise exception 'NOT_ENOUGH_GOLD'; end if;
 insert into public.trade_offers(proposer_id,recipient_id,offered_gold,requested_gold,expires_at) values(uid,p_recipient,coalesce(p_offered_gold,0),coalesce(p_requested_gold,0),now()+make_interval(hours=>p_expires_hours)) returning id into v_trade_id;
 foreach v_card_id in array coalesce(p_offered_cards,'{}') loop
  perform 1 from public.player_cards pc where pc.id=v_card_id and pc.owner_id=uid for update;if not found then raise exception 'OFFERED_CARD_NOT_OWNED';end if;
  if exists(select 1 from public.market_listings ml where ml.player_card_id=v_card_id and ml.status='active')then raise exception 'CARD_LISTED';end if;
  insert into public.trade_offer_items values(v_trade_id,v_card_id,uid,'offered');insert into public.trade_reserved_cards values(v_card_id,v_trade_id,uid,now());
 end loop;
 foreach v_card_id in array coalesce(p_requested_cards,'{}') loop
  perform 1 from public.player_cards pc where pc.id=v_card_id and pc.owner_id=p_recipient for update;if not found then raise exception 'REQUESTED_CARD_NOT_OWNED';end if;
  if exists(select 1 from public.market_listings ml where ml.player_card_id=v_card_id and ml.status='active')then raise exception 'CARD_LISTED';end if;
  insert into public.trade_offer_items values(v_trade_id,v_card_id,p_recipient,'requested');insert into public.trade_reserved_cards values(v_card_id,v_trade_id,p_recipient,now());
 end loop;return v_trade_id;
end $$;

create or replace function public.accept_trade_offer(p_trade uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid();t public.trade_offers;proposer public.profiles;recipient public.profiles;proposer_delta bigint;recipient_delta bigint;
begin
 if uid is null then raise exception 'AUTH_REQUIRED';end if;perform public.enforce_rate_limit('accept_trade',12,60);
 select * into t from public.trade_offers where id=p_trade for update;if not found or t.status<>'pending'then raise exception 'TRADE_UNAVAILABLE';end if;
 if t.recipient_id<>uid then raise exception 'TRADE_NOT_RECIPIENT';end if;
 if t.expires_at<=now()then update public.trade_offers set status='expired',updated_at=now()where id=t.id;delete from public.trade_reserved_cards where trade_id=t.id;raise exception 'TRADE_EXPIRED';end if;
 perform 1 from public.profiles where id in(t.proposer_id,t.recipient_id)order by id for update;select * into proposer from public.profiles where id=t.proposer_id;select * into recipient from public.profiles where id=t.recipient_id;
 if proposer.gold<t.offered_gold or recipient.gold<t.requested_gold then raise exception 'TRADE_NOT_ENOUGH_GOLD';end if;
 if exists(select 1 from public.trade_offer_items i left join public.player_cards pc on pc.id=i.player_card_id where i.trade_id=t.id and(pc.id is null or pc.owner_id<>i.owner_id))then raise exception 'TRADE_OWNERSHIP_CHANGED';end if;
 if exists(select 1 from public.trade_offer_items i left join public.trade_reserved_cards r on r.player_card_id=i.player_card_id and r.trade_id=i.trade_id where i.trade_id=t.id and r.player_card_id is null)then raise exception 'TRADE_RESERVATION_LOST';end if;
 proposer_delta:=t.requested_gold-t.offered_gold;recipient_delta:=-proposer_delta;
 update public.profiles set gold=gold+proposer_delta,updated_at=now()where id=t.proposer_id returning * into proposer;update public.profiles set gold=gold+recipient_delta,updated_at=now()where id=t.recipient_id returning * into recipient;
 if proposer_delta<>0 then insert into public.gold_ledger(owner_id,amount,balance_after,reason,reference_id)values(t.proposer_id,proposer_delta,proposer.gold,'trade',t.id);end if;
 if recipient_delta<>0 then insert into public.gold_ledger(owner_id,amount,balance_after,reason,reference_id)values(t.recipient_id,recipient_delta,recipient.gold,'trade',t.id);end if;
 update public.player_cards pc set owner_id=case when i.side='offered'then t.recipient_id else t.proposer_id end,obtained_from='trade',obtained_at=now(),updated_at=now()from public.trade_offer_items i where i.trade_id=t.id and pc.id=i.player_card_id;
 update public.trade_offers set status='accepted',updated_at=now()where id=t.id;delete from public.trade_reserved_cards where trade_id=t.id;
 return jsonb_build_object('trade_id',t.id,'status','accepted','profile',to_jsonb(recipient));
end $$;

create or replace function public.close_trade_offer(p_trade uuid,p_action text)
returns boolean language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid();t public.trade_offers;next_status text;
begin if uid is null then raise exception 'AUTH_REQUIRED';end if;select * into t from public.trade_offers where id=p_trade for update;if not found or t.status<>'pending'then raise exception 'TRADE_UNAVAILABLE';end if;
 if p_action='cancel'and t.proposer_id=uid then next_status:='cancelled';elsif p_action='decline'and t.recipient_id=uid then next_status:='declined';else raise exception 'TRADE_ACTION_FORBIDDEN';end if;
 update public.trade_offers set status=next_status,updated_at=now()where id=t.id;delete from public.trade_reserved_cards where trade_id=t.id;return true;end $$;

create or replace function public.expire_trade_offers()
returns integer language plpgsql security definer set search_path=public as $$
declare changed integer;begin update public.trade_offers set status='expired',updated_at=now()where status='pending'and expires_at<=now();get diagnostics changed=row_count;delete from public.trade_reserved_cards r using public.trade_offers t where r.trade_id=t.id and t.status<>'pending';return changed;end $$;

alter table public.trade_offers enable row level security;alter table public.trade_offer_items enable row level security;alter table public.trade_reserved_cards enable row level security;
drop policy if exists trade_parties_read on public.trade_offers;create policy trade_parties_read on public.trade_offers for select to authenticated using(auth.uid()in(proposer_id,recipient_id));
drop policy if exists trade_items_parties_read on public.trade_offer_items;create policy trade_items_parties_read on public.trade_offer_items for select to authenticated using(exists(select 1 from public.trade_offers t where t.id=trade_id and auth.uid()in(t.proposer_id,t.recipient_id)));
drop policy if exists trade_reservations_owner_read on public.trade_reserved_cards;create policy trade_reservations_owner_read on public.trade_reserved_cards for select to authenticated using(auth.uid()=owner_id);
revoke all on public.trade_offers,public.trade_offer_items,public.trade_reserved_cards from anon,authenticated;grant select on public.trade_offers,public.trade_offer_items,public.trade_reserved_cards to authenticated;
revoke all on function public.guard_trade_reserved_card()from public,anon,authenticated;
revoke all on function public.create_trade_offer(uuid,uuid[],uuid[],bigint,bigint,integer),public.accept_trade_offer(uuid),public.close_trade_offer(uuid,text),public.expire_trade_offers()from public,anon;
grant execute on function public.create_trade_offer(uuid,uuid[],uuid[],bigint,bigint,integer),public.accept_trade_offer(uuid),public.close_trade_offer(uuid,text),public.expire_trade_offers()to authenticated;

commit;
