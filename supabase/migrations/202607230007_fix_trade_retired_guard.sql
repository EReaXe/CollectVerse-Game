begin;

create or replace function public.guard_retired_card_use()
returns trigger language plpgsql security definer set search_path=public as $$
declare target uuid:=new.player_card_id;
begin
 if target is not null and exists(select 1 from public.player_cards pc where pc.id=target and pc.retired_at is not null) then
  raise exception 'CARD_RETIRED';
 end if;
 return new;
end $$;

revoke all on function public.guard_retired_card_use() from public,anon,authenticated;

commit;
