# Numaralı migration'lar

Dosyalar UTC tarih ve artan sıra numarasıyla adlandırılır: `YYYYMMDDNNNN_aciklama.sql`.

- Migration yayımlandıktan sonra değiştirilmez; düzeltme yeni bir migration olarak eklenir.
- Her dosya mümkün olduğunda `begin`/`commit` içinde atomik çalışır.
- Üretime geçmeden önce ayrı bir Supabase projesinde ve güncel bir anonimleştirilmiş yedek üzerinde denenir.
- Uygulama öncesi yedek alınır, uygulama sonrası `database/tests/` ve `database/05-verify.sql` çalıştırılır.
