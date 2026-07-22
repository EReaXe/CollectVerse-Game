# Veritabanı regresyon testleri

Bu testler gerçek PostgreSQL/Supabase şemasına karşı çalışır ve transaction sonunda `rollback` yapar.

```sh
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/tests/01-security-operations.test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/tests/02-direct-trades.test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/tests/03-card-fusion.test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/tests/04-card-price-history.test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/tests/05-watchlist-notifications.test.sql
```

Testleri üretim veritabanına karşı değil, migration uygulanmış geçici test projesine karşı çalıştır.
