begin;

alter table public.player_cards add column if not exists retired_at timestamptz;
alter table public.player_cards add column if not exists retired_reason text;

create table if not exists public.card_fusions(
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references public.profiles(id)on delete cascade,
 card_id uuid not null references public.cards(id)on delete restrict,output_player_card_id uuid not null references public.player_cards(id)on delete restrict,
 from_variant public.card_variant not null,to_variant public.card_variant not null,material_card_ids uuid[] not null,
 material_count integer not null check(material_count>1),created_at timestamptz not null default now()
);
create index if not exists card_fusions_owner_idx on public.card_fusions(owner_id,created_at desc);
create index if not exists player_cards_active_variant_idx on public.player_cards(owner_id,card_id,variant)where retired_at is null;

create or replace function public.guard_retired_card_use()
returns trigger language plpgsql security definer set search_path=public as $$
declare target uuid:=new.player_card_id;
begin if target is not null and exists(select 1 from public.player_cards where id=target and retired_at is not null)then raise exception 'CARD_RETIRED';end if;if tg_op='DELETE'then return old;else return new;end if;end $$;
drop trigger if exists market_retired_card_guard on public.market_listings;
create trigger market_retired_card_guard before insert or update of player_card_id on public.market_listings for each row execute function public.guard_retired_card_use();
drop trigger if exists trade_retired_card_guard on public.trade_reserved_cards;
create trigger trade_retired_card_guard before insert or update of player_card_id on public.trade_reserved_cards for each row execute function public.guard_retired_card_use();
drop trigger if exists retired_player_card_delete_guard on public.player_cards;

create or replace function public.cv_stats(p_user uuid)
returns table(click_power numeric,eps numeric)language sql security definer stable set search_path=public as $$
with u as(select coalesce(sum(case when x.type='click'then pu.level*x.value else 0 end),0)click_add,coalesce(sum(case when x.type='eps'then pu.level*x.value else 0 end),0)eps_base from public.player_upgrades pu join public.upgrades x on x.key=pu.upgrade_key where pu.owner_id=p_user and x.is_active),
c as(select coalesce(sum(x.click_bonus),0)click_pct,coalesce(sum(x.eps_bonus),0)eps_pct from public.player_cards pc join public.cards x on x.id=pc.card_id where pc.owner_id=p_user and pc.retired_at is null)
select round((1+u.click_add)*(1+c.click_pct/100),2),round(u.eps_base*(1+c.eps_pct/100),2)from u,c;$$;

create or replace function public.get_scoreboard(p_limit integer default 100)
returns table(user_id uuid,username text,avatar_url text,total_energy numeric,total_clicks bigint,created_at timestamptz,collection_score bigint,unique_cards bigint,total_cards bigint,level integer,rank bigint)
language sql security definer stable set search_path=public as $$
with stats as(select p.id,p.username,p.avatar_url,p.total_energy,p.total_clicks,p.created_at,coalesce(sum(c.score*case pc.variant when 'Foil'then 1.5 when 'Gold Foil'then 2.5 when 'Black Edition'then 3 when 'Rainbow Holo'then 4 when 'Animated'then 5 when 'Founder Edition'then 6 when 'Beta Edition'then 4 else 1 end),0)::bigint collection_score,count(distinct pc.card_id)::bigint unique_cards,count(pc.id)::bigint total_cards from public.profiles p left join public.player_cards pc on pc.owner_id=p.id and pc.retired_at is null left join public.cards c on c.id=pc.card_id group by p.id),ranked as(select s.*,(floor(sqrt(greatest(s.total_energy,0)/250))+1)::integer level,row_number()over(order by s.collection_score desc,s.total_energy desc,s.created_at asc)::bigint rank from stats s)
select id,username,avatar_url,total_energy,total_clicks,created_at,collection_score,unique_cards,total_cards,level,rank from ranked order by rank limit greatest(1,least(coalesce(p_limit,100),500));$$;

create or replace function public.fuse_card_copies(p_card uuid,p_from_variant public.card_variant)
returns jsonb language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid();target public.card_variant;needed integer;materials uuid[];output_id uuid;fusion_id uuid;output_copy public.player_cards;
begin if uid is null then raise exception 'AUTH_REQUIRED';end if;perform public.enforce_rate_limit('fuse_cards',8,60);
 if p_from_variant='Standard'then target:='Foil';needed:=5;elsif p_from_variant='Foil'then target:='Gold Foil';needed:=3;else raise exception 'VARIANT_NOT_FUSIBLE';end if;
 select array_agg(candidate.id order by candidate.obtained_at,candidate.id)into materials from(select pc.id,pc.obtained_at from public.player_cards pc where pc.owner_id=uid and pc.card_id=p_card and pc.variant=p_from_variant and pc.retired_at is null and not exists(select 1 from public.market_listings l where l.player_card_id=pc.id and l.status='active')and not exists(select 1 from public.trade_reserved_cards r where r.player_card_id=pc.id)order by pc.obtained_at,pc.id limit needed for update skip locked)candidate;
 if coalesce(cardinality(materials),0)<needed then raise exception 'NOT_ENOUGH_FUSION_COPIES';end if;output_id:=materials[1];
 update public.player_cards set variant=target,updated_at=now()where id=output_id returning * into output_copy;
 update public.player_cards set retired_at=now(),retired_reason='fusion:'||output_id::text,updated_at=now()where id=any(materials)and id<>output_id;
 insert into public.card_fusions(owner_id,card_id,output_player_card_id,from_variant,to_variant,material_card_ids,material_count)values(uid,p_card,output_id,p_from_variant,target,materials,needed)returning id into fusion_id;
 return jsonb_build_object('fusion_id',fusion_id,'output',to_jsonb(output_copy),'from_variant',p_from_variant,'to_variant',target,'consumed',needed-1);end $$;

create or replace function public.sell_card_to_system(p_player_card uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid();pc public.player_cards;c public.cards;payout bigint;p public.profiles;
begin if uid is null then raise exception 'AUTH_REQUIRED';end if;perform public.enforce_rate_limit('system_buyback',20,60);
 select * into pc from public.player_cards where id=p_player_card and owner_id=uid and retired_at is null for update;if not found then raise exception 'CARD_COPY_NOT_FOUND';end if;
 if exists(select 1 from public.trade_reserved_cards where player_card_id=pc.id)then raise exception 'CARD_RESERVED_FOR_TRADE';end if;
 if exists(select 1 from public.market_listings where player_card_id=pc.id and status='active')then raise exception 'CARD_LISTED';end if;
 select * into c from public.cards where id=pc.card_id;payout:=greatest(1,floor(greatest(c.score,1)*0.20));
 insert into public.system_card_pool(original_player_card_id,card_id,serial_number,variant,condition,returned_by)values(pc.id,pc.card_id,pc.serial_number,pc.variant,pc.condition,uid);
 delete from public.player_cards where id=pc.id;update public.profiles set gold=gold+payout,updated_at=now()where id=uid returning * into p;
 insert into public.gold_ledger(owner_id,amount,balance_after,reason,reference_id)values(uid,payout,p.gold,'system_buyback',pc.id);
 return jsonb_build_object('profile',to_jsonb(p),'gold_received',payout,'card_id',c.id,'recycled',true);end $$;

alter table public.card_fusions enable row level security;
drop policy if exists card_fusions_owner_read on public.card_fusions;
create policy card_fusions_owner_read on public.card_fusions for select to authenticated using(auth.uid()=owner_id or public.is_collectverse_admin());
revoke all on public.card_fusions from anon,authenticated;grant select on public.card_fusions to authenticated;
revoke all on function public.guard_retired_card_use(),public.fuse_card_copies(uuid,public.card_variant)from public,anon,authenticated;
grant execute on function public.fuse_card_copies(uuid,public.card_variant)to authenticated;

commit;
