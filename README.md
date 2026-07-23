# CollectVerse

Framework kullanmadan geliştirilmiş, Supabase tabanlı çevrim içi kart koleksiyon oyunu.

## Özellikler

- E-posta ve şifreyle üyelik
- Sunucu hesaplı enerji, tıklama ve en fazla 8 saat çevrimdışı üretim
- Seviyeye göre enerji kapasitesi ve üretim geliştirmeleri
- Günlük/ücretli paketler, nadirlikler ve sınırlı seri numaraları
- Koleksiyon, profil, global sıralama ve yama notları
- Gold dönüşümü, sabit fiyatlı satış ve 1–6 günlük açık artırma
- Kartları puanının %20'si karşılığında sisteme hızlı satış; satılan kopyayı seri, varyant ve kondisyonuyla paket havuzuna geri döndürme
- Her cuma Epic ve üzeri üç süreli sistem ilanı
- 24 saatlik günlük paket sayacı ve zaman/s stok uygunluğu
- Kart kopyalarında UUID, seri numarası, varyant ve kondisyon detayları
- Sıralamadan açılabilen herkese açık oyuncu profilleri, kart ve rozet vitrinleri
- Yönetici kontrollü, özel mesaj ve tahmini açılış zamanlı bakım modu
- İnternet kesintisinde otomatik çevrimdışı ekranı ve yeniden deneme akışı
- Çoklu kart ve Gold destekli, rezervasyonlu oyuncudan oyuncuya doğrudan takas
- Numaralı Supabase migration'ları, ekonomi hareket günlüğü, yönetici denetim izi ve işlem rate limit altyapısı
- Günlük özetlenen enerji hareketleri, süreli veri saklama ve toplu veritabanı bakımı
- 5 Standard → 1 Foil ve 3 Foil → 1 Gold Foil kart birleştirme atölyesi; emekli malzeme ve fusion geçmişi
- RLS, atomik RPC işlemleri ve Gold hareket defteri
- Kart, set, paket ve yama notu yönetim paneli

## Dizin

```text
index.html                    Oyuncu uygulaması
admin.html                    Yönetim paneli
assets/
  css/app.css                 Ortak tasarım sistemi ve oyuncu arayüzü
  css/admin.css               Yönetim paneli stilleri
  js/app.js                   Oyuncu uygulaması
  js/admin.js                 Yönetim paneli
database/
  01-schema.sql               Tipler, tablolar ve indeksler
  02-functions.sql            Enerji, paket ve temel ekonomi RPC'leri
  02-market.sql               Pazar ve açık artırma RPC'leri
  03-security.sql             RLS, yetkiler ve kullanıcı tetikleyicisi
  04-seed.sql                 Başlangıç içerikleri
  05-verify.sql               Kurulum doğrulaması
supabase-config.example.js    Public bağlantı ayarı örneği
```

## Kurulum

1. Boş bir Supabase projesi oluştur.
2. [database/README.md](database/README.md) içindeki SQL sırasını uygula.
3. `supabase-config.example.js` dosyasını `supabase-config.js` olarak kopyala.
4. Project URL ile publishable/anon key değerini gir.
5. Projeyi yerel bir HTTP sunucusunda veya statik hosting üzerinde aç.

Yönetici yapmak istediğin kullanıcı için SQL Editor'da:

```sql
update public.profiles p
set is_admin = true
from auth.users u
where p.id = u.id and u.email = 'yonetici@ornek.com';
```

`service_role` anahtarını hiçbir zaman istemci dosyalarına koyma.

## Kontrol

Veritabanı kurulumundan sonra `database/05-verify.sql` ve
`database/tests/` altındaki SQL regresyon kontrollerini çalıştır.
