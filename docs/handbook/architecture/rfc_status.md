# Статус реализации RFC v1

| Этап | Описание | Статус |
| --- | --- | --- |
| 0 | Подготовка структуры пакета `lottery_multi`, согласование модулей и событий | Выполнен |
| 1 | Реализация контрактов и документации (registry, sales, draw, payouts, automation, price_feed) | Выполнен |
| 2 | План миграции, расширение тестов и Prover-спек, контроль VRF-депозита | Выполнен |
| 3 | Интеграция фронтенда и партнёрских панелей, прайс-фид и AutomationBot в проде | В процессе (агрегаты и события выплат завершены, добавлены негативные `payouts_tests` и `sales_tests`, `views_tests` покрывают фильтры UI; модуль `price_feed` получил тесты `price_feed_tests`, спецификацию `spec/price_feed` и справочник [price_feeds.md](price_feeds.md); обновлены runbook AutomationBot и тесты `automation_tests`) |
| 4 | Мультисетевые профили и dual-write миграция архива | В процессе (dual-write мост, CLI и тест `dual_write_mismatch_requires_manual_clear`) |
| 5 | Governance и публичный API | В процессе (JSON Schema и пример ответов для view `lottery_multi`, Python-валидатор схемы, подготовлены runbook’и мониторинга и релизный чек-лист, добавлена агрегированная view `status_overview` и [status_page.md](../operations/status_page.md)) |
| 6 | Пострелизная поддержка, баг-баунти, аудит | В процессе (добавлены [post_release_support.md](../operations/post_release_support.md) и [postmortems.md](../operations/postmortems.md), программа [bug_bounty.md](../operations/bug_bounty.md) опубликована, требуется согласование наград и аудит документации) |

Актуальный прогресс фикcируется также в [../../architecture/rfc_v1_implementation_notes.md](../../architecture/rfc_v1_implementation_notes.md).
