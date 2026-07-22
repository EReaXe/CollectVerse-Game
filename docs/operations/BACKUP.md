# CollectVerse yedekleme prosedürü

## Zamanlama

- Supabase günlük otomatik yedeklerini proje planında etkin tut.
- Büyük migration veya ekonomi değişikliklerinden hemen önce manuel mantıksal yedek al.
- Ayda bir kez geri yükleme tatbikatı yap; yalnızca yedek alınmış olması yeterli değildir.

## Manuel yedek

Supabase Dashboard içindeki güncel bağlantı dizesini güvenli bir secret yöneticisinden al. Parolayı komut geçmişine veya depoya yazma.

```sh
pg_dump "$DATABASE_URL" --format=custom --no-owner --no-privileges --file="collectverse-$(date +%Y%m%d-%H%M).dump"
```

Üretilen dosyayı şifreli ve erişimi kısıtlı bir depoya yükle. En az 7 günlük, 4 haftalık ve 6 aylık kopya sakla.

## Geri yükleme tatbikatı

1. Boş ve üretimden tamamen ayrı bir Supabase/PostgreSQL projesi oluştur.
2. Yedeği `pg_restore --clean --if-exists --no-owner` ile geri yükle.
3. `database/05-verify.sql` ve `database/tests/*.test.sql` kontrollerini çalıştır.
4. Profil, kart sahipliği, Gold defteri, aktif ilan ve sistem kart havuzu sayılarını üretim anlık görüntüsüyle karşılaştır.
5. Sonucu tarih, yedek kimliği, süre ve hatalarla operasyon günlüğüne kaydet.

## Olay anı

- Yazma işlemlerini bakım modu ile durdur.
- Geri yüklemeden önce bozuk veritabanının ayrıca adli kopyasını al.
- En son doğrulanmış yedeği geri yükle ve eksik işlemleri `gold_ledger`, `economy_events` ve `admin_audit_log` üzerinden uzlaştır.
- Doğrulamalar geçmeden bakım modunu kapatma.
