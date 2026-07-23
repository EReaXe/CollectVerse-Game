# Supabase kurulumu

Bu klasör CollectVerse veritabanının tek kaynağıdır. Eski projeleri yamalamak yerine boş bir Supabase projesi kullanılması önerilir.

SQL Editor içinde dosyaları tam olarak şu sırayla çalıştır:

1. `01-schema.sql`
2. `02-functions.sql`
3. `02-market.sql`
4. `03-security.sql`
5. `03-maintenance.sql`
6. `04-seed.sql`
7. `05-verify.sql`

`06-diagnostics.sql` kurulum dosyası değildir; tablo ve indeks boyutlarını
incelemek için gerektiğinde çalıştırılan salt okunur rapordur.

Son dosyadaki bütün kontroller `PASS` dönmelidir. Authentication ayarlarında uygulamanın Site URL ve Redirect URL değerlerini tanımlamayı unutma.

Tüm ekonomi yazımları `security definer` RPC fonksiyonlarından geçer. RLS açık ve doğrudan istemci yazımı yalnızca yönetici içerik tablolarında, `is_collectverse_admin()` kontrolüyle mümkündür.

## Mevcut projeyi güncelleme

Kurulu bir projede `supabase/migrations/` dosyalarını dosya adındaki tarih sırasıyla uygula. Her migration yalnızca bir kez çalıştırılmalıdır. Ardından `database/tests/` altındaki SQL kontrollerini çalıştır.

```sh
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/202607230001_security_operations.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/202607230002_direct_trades.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/202607230003_card_fusion.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/202607230004_card_price_history.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/202607230005_watchlist_notifications.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/202607230006_fix_trade_card_id_ambiguity.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/202607230007_fix_trade_retired_guard.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/202607230008_fix_market_watchlist_trade_availability.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/202607230009_database_storage_optimization.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/tests/01-security-operations.test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/tests/02-direct-trades.test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/tests/03-card-fusion.test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/tests/04-card-price-history.test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/tests/05-watchlist-notifications.test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/tests/06-storage-optimization.test.sql
```

Veritabanı parolasını repoya, komut dosyasına veya terminal geçmişine kaydetme. Yedekleme ve geri yükleme adımları `docs/operations/BACKUP.md` içindedir.
Saklama süreleri, otomatik temizlik ve boyut raporu `docs/operations/DATABASE_MAINTENANCE.md` içinde açıklanır.
