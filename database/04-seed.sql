begin;

insert into public.app_settings(key,value) values('maintenance',jsonb_build_object(
  'enabled',false,
  'message','Planlı bakım çalışması devam ediyor. Lütfen kısa süre sonra tekrar dene.',
  'estimated_end',null
)) on conflict(key) do nothing;

insert into public.upgrades(key,name,icon,description,type,base_price,value,price_growth,sort_order) values
('finger','Güçlü Parmak','☝️','Tıklama gücünü artırır.','click',50,1,1.55,10),
('autoclick','Otomatik Tıklayıcı','⚙️','Her saniye enerji üretir.','eps',120,1,1.55,20),
('generator','Mini Jeneratör','🔋','Düzenli enerji sağlar.','eps',600,6,1.58,30),
('reactor','Kuantum Reaktörü','⚛️','Yüksek otomatik üretim sağlar.','eps',3500,30,1.62,40)
on conflict(key) do update set name=excluded.name,icon=excluded.icon,description=excluded.description,type=excluded.type,base_price=excluded.base_price,value=excluded.value,price_growth=excluded.price_growth,sort_order=excluded.sort_order;

insert into public.pack_types(key,name,description,cost,rarity_floor,daily,sort_order) values
('daily','Günlük Ücretsiz Paket','Her UTC gününde bir kez açılır.',0,null,true,10),
('basic','Standart Paket','Tüm aktif kartlardan bir adet içerir.',100,null,false,20),
('rare','Gelişmiş Paket','Rare veya üzeri bir kart garanti eder.',650,'rare',false,30)
on conflict(key) do update set name=excluded.name,description=excluded.description,cost=excluded.cost,rarity_floor=excluded.rarity_floor,daily=excluded.daily,sort_order=excluded.sort_order;

insert into public.badges(key,name,description,icon) values
('beta-player','Beta Oyuncusu','CollectVerse beta dönemine katıldı.','◈')
on conflict(key) do update set name=excluded.name,description=excluded.description,icon=excluded.icon;

insert into public.card_sets(slug,name,description,sort_order) values
('genesis','Genesis','CollectVerse evreninin ilk kart seti.',10)
on conflict(slug) do update set name=excluded.name,description=excluded.description,sort_order=excluded.sort_order;

insert into public.cards(set_id,code,name,subtitle,description,symbol,rarity,power,score,drop_weight,card_number,total_in_set) values
((select id from public.card_sets where slug='genesis'),'CV-GEN-001','Kıvılcım','İlk enerji','Her büyük koleksiyon küçük bir kıvılcımla başlar.','✦','common',4,10,55,1,6),
((select id from public.card_sets where slug='genesis'),'CV-GEN-002','Devre Bekçisi','Sessiz koruyucu','Enerji ağlarının yorulmak bilmeyen muhafızı.','⌁','uncommon',9,24,27,2,6),
((select id from public.card_sets where slug='genesis'),'CV-GEN-003','Neon Gezgin','Sınırların ötesinde','Kayıp sinyallerin peşinde evreni dolaşır.','◇','rare',18,55,11,3,6),
((select id from public.card_sets where slug='genesis'),'CV-GEN-004','Kuantum Bahçıvanı','Yıldız tohumu','Boşluğun ortasında yeni dünyalar yetiştirir.','❋','epic',35,130,5,4,6),
((select id from public.card_sets where slug='genesis'),'CV-GEN-005','Altın Reaktör','Sonsuz güç','Unutulmuş bir uygarlığın son çalışan çekirdeği.','◉','legendary',72,320,1.8,5,6),
((select id from public.card_sets where slug='genesis'),'CV-GEN-006','Evrenin Kalbi','İlk ve son ışık','CollectVerse içindeki bütün enerjinin kaynağı.','✺','mythic',150,800,.35,6,6)
on conflict(code) do update set name=excluded.name,subtitle=excluded.subtitle,description=excluded.description,symbol=excluded.symbol,rarity=excluded.rarity,power=excluded.power,score=excluded.score,drop_weight=excluded.drop_weight;

insert into public.patch_notes(version,title,body,changes,is_published) values
('3.0.0','Yeni CollectVerse','Arayüz ve altyapı özüne sadık kalınarak sıfırdan kuruldu.','["Yeni responsive arayüz","Güvenli sunucu ekonomisi","Canlı oyuncu pazarı","Sade dosya yapısı"]'::jsonb,true)
on conflict(version) do update set title=excluded.title,body=excluded.body,changes=excluded.changes,is_published=excluded.is_published;

commit;
