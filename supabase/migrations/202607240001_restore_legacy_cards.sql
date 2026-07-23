-- CollectVerse legacy card restoration
-- Source: cards_rows.json (60 cards)
--
-- Safe to run more than once:
--   * Sets are matched by slug.
--   * Cards are matched by code.
--   * Existing card ids and minted_supply values are preserved, so player_cards
--     references and already minted serial numbers are not damaged.

begin;

insert into public.card_sets(slug,name,description,sort_order,is_active) values
  ('world-cup-2026','World Cup 2026','48 milli takımın yer aldığı sınırlı futbol koleksiyonu.',20,true),
  ('beta-relics','Beta Relics','CollectVerse beta döneminden restore edilen büyülü eserler.',30,true),
  ('community-legends','Community Legends','Topluluğun erken dönemlerinden kalan tekil hatıra kartları.',40,true)
on conflict(slug) do update set
  name=excluded.name,
  description=excluded.description,
  sort_order=excluded.sort_order,
  is_active=excluded.is_active,
  updated_at=now();

-- Eski yedekte yalnızca Beta-4 kodunda sonda satır sonu bulunuyordu.
-- Bu düzeltme, eski katalog doğrudan taşınmışsa aynı kartın tekrar oluşmasını önler.
update public.cards
set code='Beta-4',updated_at=now()
where code<>btrim(code)
  and btrim(code)='Beta-4'
  and not exists(select 1 from public.cards clean where clean.code='Beta-4');

with legacy(
  set_slug,code,name,symbol,rarity,image_url,card_number,total_in_set
) as (
  values
  ('world-cup-2026','WC26-01','Panama','🇵🇦','common',null,1,48),
  ('world-cup-2026','WC26-02','Özbekistan','🇺🇿','common',null,2,48),
  ('world-cup-2026','WC26-03','Ürdün','🇯🇴','common',null,3,48),
  ('world-cup-2026','WC26-04','Irak','🇮🇶','common',null,4,48),
  ('world-cup-2026','WC26-05','Suudi Arabistan','🇸🇦','common',null,5,48),
  ('world-cup-2026','WC26-06','Uruguay','🇺🇾','common',null,6,48),
  ('world-cup-2026','WC26-07','Yeni Zelanda','🇳🇿','common',null,7,48),
  ('world-cup-2026','WC26-08','İran','🇮🇷','common',null,8,48),
  ('world-cup-2026','WC26-09','Tunus','🇹🇳','common',null,9,48),
  ('world-cup-2026','WC26-10','Curaçao','🇨🇼','common',null,10,48),
  ('world-cup-2026','WC26-11','Türkiye','🇹🇷','common',null,11,48),
  ('world-cup-2026','WC26-12','Haiti','🇭🇹','common',null,12,48),
  ('world-cup-2026','WC26-13','İskoçya','🏴','common',null,13,48),
  ('world-cup-2026','WC26-14','Katar','🇶🇦','common',null,14,48),
  ('world-cup-2026','WC26-15','Çekya','🇨🇿','common',null,15,48),
  ('world-cup-2026','WC26-16','Güney Kore','🇰🇷','common',null,16,48),
  ('world-cup-2026','WC26-17','Almanya','🇩🇪','uncommon',null,17,48),
  ('world-cup-2026','WC26-18','İsveç','🇸🇪','uncommon',null,18,48),
  ('world-cup-2026','WC26-19','Güney Afrika','🇿🇦','uncommon',null,19,48),
  ('world-cup-2026','WC26-20','Hollanda','🇳🇱','uncommon',null,20,48),
  ('world-cup-2026','WC26-21','Hırvatistan','🇭🇷','uncommon',null,21,48),
  ('world-cup-2026','WC26-22','Avusturya','🇦🇹','uncommon',null,22,48),
  ('world-cup-2026','WC26-23','Bosna-Hersek','🇧🇦','uncommon',null,23,48),
  ('world-cup-2026','WC26-24','Senegal','🇸🇳','uncommon',null,24,48),
  ('world-cup-2026','WC26-25','Japonya','🇯🇵','uncommon',null,25,48),
  ('world-cup-2026','WC26-26','Fildişi Sahili','🇨🇮','uncommon',null,26,48),
  ('world-cup-2026','WC26-27','Ekvador','🇪🇨','uncommon',null,27,48),
  ('world-cup-2026','WC26-28','Kongo DC','🇨🇩','uncommon',null,28,48),
  ('world-cup-2026','WC26-29','Cabo Verde','🇨🇻','uncommon',null,29,48),
  ('world-cup-2026','WC26-30','Avustralya','🇦🇺','uncommon',null,30,48),
  ('world-cup-2026','WC26-31','Cezayir','🇩🇿','uncommon',null,31,48),
  ('world-cup-2026','WC26-32','Gana','🇬🇭','uncommon',null,32,48),
  ('world-cup-2026','WC26-33','Paraguay','🇵🇾','rare',null,33,48),
  ('world-cup-2026','WC26-34','Kanada','🇨🇦','rare',null,34,48),
  ('world-cup-2026','WC26-35','Portekiz','🇵🇹','rare',null,35,48),
  ('world-cup-2026','WC26-36','ABD','🇺🇸','rare',null,36,48),
  ('world-cup-2026','WC26-37','Brezilya','🇧🇷','rare',null,37,48),
  ('world-cup-2026','WC26-38','Meksika','🇲🇽','rare',null,38,48),
  ('world-cup-2026','WC26-39','Mısır','🇪🇬','rare',null,39,48),
  ('world-cup-2026','WC26-40','Kolombiya','🇨🇴','rare',null,40,48),
  ('world-cup-2026','WC26-41','Fas','🇲🇦','epic',null,41,48),
  ('world-cup-2026','WC26-42','Belçika','🇧🇪','epic',null,42,48),
  ('world-cup-2026','WC26-43','Norveç','🇳🇴','epic',null,43,48),
  ('world-cup-2026','WC26-44','İsviçre','🇨🇭','epic',null,44,48),
  ('world-cup-2026','WC26-45','Fransa','🇫🇷','legendary',null,45,48),
  ('world-cup-2026','WC26-46','İngiltere','🏴','legendary',null,46,48),
  ('world-cup-2026','WC26-47','İspanya','🇪🇸','mythic',null,47,48),
  ('world-cup-2026','WC26-48','Arjantin','🇦🇷','mythic',null,48,48),

  ('beta-relics','Beta-1','Ejderha Kalbi','🐉','legendary',null,1,12),
  ('beta-relics','Beta-2','Safir Gerdanlık','📿','rare',null,2,12),
  ('beta-relics','Beta-3','Rünlü Parşömen','📜','rare',null,3,12),
  ('beta-relics','Beta-4','Akik Taşı','🪨','uncommon',null,4,12),
  ('beta-relics','Beta-5','Demir Örs','⚒️','uncommon',null,5,12),
  ('beta-relics','Beta-6','Gezgin Feneri','🏮','uncommon',null,6,12),
  ('beta-relics','Beta-7','Tahta Kalkan','🛡️','common',null,7,12),
  ('beta-relics','Beta-8','Çırak Tılsımı','🧿','common',null,8,12),
  ('beta-relics','Beta-9','Paslı Çark','⚙️','common',null,9,12),
  ('beta-relics','Beta-11','Anka Tüyü','🪶','epic',null,11,12),
  ('beta-relics','Beta-12','Kusursuz Elmas','💎','epic',null,12,12),

  ('community-legends','Mugo-1','LunarLords | EtliPilav','🎲','mythic',
   'https://resmim.net/cdn/2026/07/19/EWeRo8.png',1,1)
),
balanced as (
  select
    s.id as set_id,
    l.code,
    l.name,
    case
      when l.set_slug='world-cup-2026' then
        case l.rarity
          when 'common' then 'Yükselen takım'
          when 'uncommon' then 'Güçlü rakip'
          when 'rare' then 'Turnuva iddiası'
          when 'epic' then 'Kupanın favorilerinden'
          when 'legendary' then 'Futbol devi'
          else 'Şampiyonluk mirası'
        end
      when l.set_slug='community-legends' then 'Topluluk efsanesi'
      else
        case l.rarity
          when 'common' then 'Mütevazı başlangıç'
          when 'uncommon' then 'Ustalık eseri'
          when 'rare' then 'Kadim emanet'
          when 'epic' then 'Efsanevi kalıntı'
          else 'Çağların gücü'
        end
    end as subtitle,
    case
      when l.set_slug='world-cup-2026'
        then l.name||', 2026 dünya sahnesinde koleksiyon gücünü temsil eden özel milli takım kartı.'
      when l.code='Beta-1'
        then 'Kadim bir ejderhanın hâlâ atan kalbi; sahibine durdurulamaz bir güç bahşeder.'
      when l.code='Beta-2'
        then 'Eski bir kraliçeye ait bu gerdanlık, zarafetinin yanında büyük bir güç barındırır.'
      when l.code='Beta-3'
        then 'Kadim rünleri okunduğunda çevresindeki enerjiyi kendine çeken gizemli parşömen.'
      when l.code='Beta-4'
        then 'Yeraltı madenlerinden çıkarılan bu taş, sahibine sessiz bir şans getirir.'
      when l.code='Beta-5'
        then 'Üzerinde binlerce kılıcın dövüldüğü, emeğin ve dayanıklılığın simgesi.'
      when l.code='Beta-6'
        then 'İçindeki büyülü ateş sayesinde karanlık yollarda hiç sönmeyen gezgin feneri.'
      when l.code='Beta-7'
        then 'Mütevazı görünümüne rağmen nice acemi savaşçının hayatını kurtaran kalkan.'
      when l.code='Beta-8'
        then 'Büyücülük okulunun ilk gününde verilen basit fakat güvenilir koruma tılsımı.'
      when l.code='Beta-9'
        then 'Büyük bir makineden düşen bu paslı çark hâlâ az da olsa enerji üretir.'
      when l.code='Beta-11'
        then 'Küllerinden doğan efsanevi kuşun sıcaklığını ve yaşam enerjisini koruyan tüy.'
      when l.code='Beta-12'
        then 'Işığı kusursuz yansıtan ve yalnızca en yetenekli madencilerin bulabildiği elmas.'
      else 'CollectVerse topluluğunun ilk dönemlerinden kalan tek kopyalık özel hatıra kartı.'
    end as description,
    l.image_url,
    l.symbol,
    l.rarity::public.card_rarity as rarity,
    case l.rarity
      when 'common' then 8 when 'uncommon' then 16 when 'rare' then 30
      when 'epic' then 55 when 'legendary' then 95 else 150
    end + case when l.set_slug='community-legends' then 25 else 0 end as power,
    case l.rarity
      when 'common' then 15 when 'uncommon' then 35 when 'rare' then 80
      when 'epic' then 180 when 'legendary' then 420 else 900
    end + case when l.set_slug='community-legends' then 300 else 0 end as score,
    case l.rarity
      when 'common' then 1 when 'uncommon' then 2 when 'rare' then 4
      when 'epic' then 7 when 'legendary' then 12 else 20
    end::numeric as click_bonus,
    case l.rarity
      when 'common' then 0 when 'uncommon' then .25 when 'rare' then .75
      when 'epic' then 1.5 when 'legendary' then 3 else 6
    end + case when l.set_slug='community-legends' then 2 else 0 end as eps_bonus,
    case
      when l.set_slug='community-legends' then .05
      else case l.rarity
        when 'common' then 48 when 'uncommon' then 26 when 'rare' then 11
        when 'epic' then 4 when 'legendary' then 1 else .22
      end
    end::numeric as drop_weight,
    case
      when l.set_slug='community-legends' then 1
      when l.set_slug='beta-relics' then
        case l.rarity
          when 'common' then 240 when 'uncommon' then 140 when 'rare' then 70
          when 'epic' then 24 when 'legendary' then 6 else 2
        end
      else
        case l.rarity
          when 'common' then 260 when 'uncommon' then 180 when 'rare' then 100
          when 'epic' then 45 when 'legendary' then 14 else 5
        end
    end as max_supply,
    case
      when l.set_slug='world-cup-2026' then 'CollectVerse Studio'
      when l.set_slug='beta-relics' then 'CollectVerse Studio'
      else 'CollectVerse Community'
    end as illustrator,
    case
      when l.set_slug='world-cup-2026' then 'World Cup'
      when l.set_slug='beta-relics' then 'Beta Relics'
      else 'Community Legends'
    end as series_name,
    case
      when l.set_slug='world-cup-2026' then '2026'
      when l.set_slug='beta-relics' then 'Beta'
      else 'Founders'
    end as season_name,
    case
      when l.set_slug='world-cup-2026' then 'World Cup 2026'
      when l.set_slug='beta-relics' then 'Restore Edition'
      else 'One of One'
    end as edition_name,
    l.card_number,
    l.total_in_set,
    case when l.set_slug='world-cup-2026' then date '2026-07-19' else date '2026-07-24' end as release_date
  from legacy l
  join public.card_sets s on s.slug=l.set_slug
)
insert into public.cards(
  set_id,code,name,subtitle,description,image_url,symbol,rarity,
  illustrator,series_name,season_name,edition_name,card_number,total_in_set,
  power,score,click_bonus,eps_bonus,drop_weight,max_supply,minted_supply,
  is_limited,is_signed,release_date,is_active
)
select
  set_id,code,name,subtitle,description,image_url,symbol,rarity,
  illustrator,series_name,season_name,edition_name,card_number,total_in_set,
  power,score,click_bonus,eps_bonus,drop_weight,max_supply,0,
  true,false,release_date,true
from balanced
on conflict(code) do update set
  set_id=excluded.set_id,
  name=excluded.name,
  subtitle=excluded.subtitle,
  description=excluded.description,
  image_url=coalesce(excluded.image_url,public.cards.image_url),
  symbol=excluded.symbol,
  rarity=excluded.rarity,
  illustrator=excluded.illustrator,
  series_name=excluded.series_name,
  season_name=excluded.season_name,
  edition_name=excluded.edition_name,
  card_number=excluded.card_number,
  total_in_set=excluded.total_in_set,
  power=excluded.power,
  score=excluded.score,
  click_bonus=excluded.click_bonus,
  eps_bonus=excluded.eps_bonus,
  drop_weight=excluded.drop_weight,
  max_supply=greatest(excluded.max_supply,public.cards.minted_supply),
  is_limited=excluded.is_limited,
  is_signed=excluded.is_signed,
  release_date=excluded.release_date,
  is_active=excluded.is_active,
  updated_at=now();

-- Migrationın eksik veya bozuk veriyle sessizce tamamlanmasını engeller.
do $verify$
declare
  restored_count integer;
  invalid_count integer;
begin
  select count(*) into restored_count
  from public.cards
  where code like 'WC26-%'
     or code like 'Beta-%'
     or code='Mugo-1';

  select count(*) into invalid_count
  from public.cards
  where (code like 'WC26-%' or code like 'Beta-%' or code='Mugo-1')
    and (
      nullif(btrim(name),'') is null
      or nullif(btrim(symbol),'') is null
      or score<=0
      or power<=0
      or drop_weight<=0
      or max_supply is null
      or minted_supply>max_supply
    );

  if restored_count<>60 then
    raise exception 'LEGACY_CARD_COUNT_MISMATCH: expected 60, found %',restored_count;
  end if;

  if invalid_count<>0 then
    raise exception 'LEGACY_CARD_VALIDATION_FAILED: % invalid cards',invalid_count;
  end if;
end
$verify$;

commit;
