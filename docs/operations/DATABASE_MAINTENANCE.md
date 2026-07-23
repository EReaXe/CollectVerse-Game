# Veritabanı bakımı

CollectVerse enerji hareketlerini artık işlem başına ayrı satır olarak değil,
oyuncu ve UTC günü başına `economy_daily_summaries` tablosunda birleştirir.
Gold hareketlerinin ayrıntılı ve değiştirilemez kaynağı `gold_ledger` tablosudur;
bakım işlemi bu tabloyu silmez.

## Saklama süreleri

| Veri | Saklama |
|---|---:|
| Okunmuş bildirim | 30 gün |
| Okunmamış/eski bildirim | 180 gün |
| Ham ekonomi olayı | 365 gün |
| Eski enerji-only olayı | 7 gün |
| Yönetici denetim izi | 365 gün |
| Kapanmış ilan | 180 gün |
| Kapanmış ilana ait teklif | 90 gün |
| Kapanmış takas | 180 gün |
| Emekli kart kopyası | 365 gün |
| Kullanılmış sistem havuzu kaydı | 180 gün |
| Günlük paket talebi | 400 gün |
| Günlük ekonomi özeti | 730 gün |

## Bakımı çalıştırma

Önce yedek al. Supabase SQL Editor içinde:

```sql
select public.run_database_maintenance(5000);
```

Sonuçtaki değerler her tablodan o çalıştırmada silinen satır sayılarıdır.
Bir değer `5000` ise aynı komutu tekrar çalıştır; bütün değerler `5000` altına
inene kadar küçük partiler halinde devam edebilirsin.

## Otomatik zamanlama

Migration çalışırken Cron uzantısı etkinse günlük görev otomatik oluşturulur.
Etkin değilse Supabase Dashboard içindeki Cron bölümünde günlük bir görev oluştur:

```sql
select public.run_database_maintenance(5000);
```

Önerilen zaman: her gün UTC `03:17`. Cron özelliği kullanılmıyorsa komutu
haftada bir SQL Editor içinde çalıştırmak yeterlidir.

## Boyut raporu

`database/06-diagnostics.sql` dosyasını SQL Editor içinde çalıştır. Rapor:

- tablo, indeks ve toplam boyutları;
- tahmini canlı ve ölü satır sayılarını;
- en eski ve en yeni geçmiş kayıtlarını;
- büyük fakat az kullanılan indeksleri

gösterir. Büyük bir temizlikten sonra alanın işletim sistemi seviyesinde hemen
küçülmemesi normaldir; PostgreSQL alanı sonraki kayıtlar için yeniden kullanır.
Autovacuum tabloyu zaman içinde düzenler.
