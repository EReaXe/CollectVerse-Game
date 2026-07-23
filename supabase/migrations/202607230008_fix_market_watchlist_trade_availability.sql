begin;

-- Takas ekranı, karşı oyuncunun yalnızca gerçekten kullanılabilir kartlarını
-- gösterebilmek için aktif rezervasyon durumunu okuyabilmelidir.
drop policy if exists trade_reservations_owner_read on public.trade_reserved_cards;
drop policy if exists trade_reservations_authenticated_read on public.trade_reserved_cards;
create policy trade_reservations_authenticated_read
on public.trade_reserved_cards
for select
to authenticated
using (
  exists (
    select 1
    from public.trade_offers t
    where t.id = trade_id
      and t.status = 'pending'
  )
);

commit;
