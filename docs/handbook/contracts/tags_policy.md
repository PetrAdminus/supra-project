# Политика классификаторов `lottery_multi`

Документ описывает правила работы с основным типом (`primary_type`) и маской тегов (`tags_mask`) для лотерей в пакете `lottery_multi`. Материал дополняет обзор модулей в [lottery_multi.md](lottery_multi.md) и используется операционными командами при согласовании новых розыгрышей и миграций.

## 1. Основные типы

| Константа | Назначение | Кто может использовать |
| --- | --- | --- |
| `TYPE_BASIC` | Базовые розыгрыши Supra. | RootAdmin, OperationalAdmin |
| `TYPE_PARTNER` | Запуски с внешними партнёрами. | Партнёры, имеющие `PartnerCreateCap` с соответствующим whitelisting |
| `TYPE_JACKPOT` | Серии, связанные с глобальным джекпотом. | Только RootAdmin/OperationalAdmin |
| `TYPE_VIP` | Премиальные/закрытые розыгрыши. | OperationalAdmin совместно с командой премиум-продукта |

## 2. Допустимые комбинации тегов

Правила валидации реализованы в `tags::validate` и `registry::ensure_tags_allowed`, а также в тестах `config_tests::cannot_update_tags_after_snapshot` и `roles_tests::tag_budget_limits_active_bits`. Дополнительные проверки для партнёров выполняет `roles::ensure_tags_allowed`.

| Primary type →<br/>Tag ↓ | `TYPE_BASIC` | `TYPE_PARTNER` | `TYPE_JACKPOT` | `TYPE_VIP` | Комментарий |
| --- | --- | --- | --- | --- | --- |
| `TAG_NFT` | ✅ | ✅ (если `PartnerCreateCap.allowed_tags_mask` содержит бит) | ⚠️ Требует escrow в `reward_bridge` | ✅ | Партнёр обязан предоставить escrow либо хук NFT. |
| `TAG_DAILY` | ✅ | ✅ | ❌ | ✅ | Джекпот не совмещается с дневными сериями; VIP допускает daily циклы. |
| `TAG_WEEKLY` | ✅ | ✅ | ✅ | ⚠️ Требуется ручное подтверждение премиум-команды. |
| `TAG_SPLIT_PRIZE` | ✅ | ✅ | ✅ | ✅ | Требует `winners_dedup = true`. |
| `TAG_PROMO` | ✅ | ✅ (по заявке маркетинга) | ❌ | ✅ | Для партнёров — только после согласования бюджета. |
| `TAG_EXPERIMENTAL` | ⚠️ Только с ручным включением во фронте | ❌ | ❌ | ⚠️ Только для внутренних A/B-тестов | Маска скрывается во view, требуется запись в [incident_log.md](../operations/incident_log.md). |

Допускается до 16 активных тегов одновременно (`tags::assert_tag_budget`). При нарушении правило генератор масок выбрасывает `errors::E_TAG_BUDGET_EXCEEDED`.

## 3. Жизненный цикл и блокировки

| Состояние лотереи | Допустимые операции | Ограничения |
| --- | --- | --- |
| `Draft` | `registry::set_primary_type`, `registry::set_tags_mask` | Проверка whitelists capability; изменение фиксируется событием `LotteryUpdated` |
| `Active` | `registry::set_tags_mask` (без изменения типа) | `tags::freeze_primary_type` блокирует смену `primary_type`; теги можно корректировать до `Closing` |
| `Closing` | Нет | Снимок конфигурации заморожен (`registry::freeze_snapshot`). Попытка изменения → `errors::E_TAGS_LOCKED`. |
| `DrawRequested` и далее | Нет | Изменения запрещены; см. негативный тест `config_tests::cannot_update_tags_after_snapshot`. |
| `Legacy archive` | `history::update_legacy_classification_admin` | RootAdmin может переписать классификаторы для импортированных сводок после dry-run миграции. |

## 4. Исключения и ручные процедуры

1. **RootAdmin override.** Единственный сценарий изменения тегов после `Closing` — ручной вызов `legacy_bridge::update_legacy_classification_admin` для архивных записей. Требуется dry-run `history_backfill.sh` и запись в журнал инцидентов.
2. **Partner escalation.** Если партнёр запрашивает новый тег, бизнес-команда обновляет `PartnerCreateCap.allowed_tags_mask`; изменение вступает в силу только после 48-часового таймлока (см. [roles.md](../governance/roles.md#матрица-выдачи-и-ревокации-capability)).
3. **Experimental режим.** Тег `TAG_EXPERIMENTAL` включается только для внутренних тестов. Перед активацией фронтенд обязан скрыть розыгрыш, а DevOps отмечает эксперимент в статусной странице.

## 5. Наблюдаемость и тестирование

- View `views::get_lottery_badges` и `views::list_by_all_tags` позволяют аудиторам контролировать актуальную маску тегов.
- Партнёрские capability отображают допустимые значения через `roles::list_partner_caps`.
- Тесты `history_migration_tests::update_legacy_classification` и `payouts_tests::finalize_records_summary` проверяют, что архивные и финальные записи сохраняют классификацию.
- При каждом изменении классификаторов runbook требует обновить индикаторы на статусной странице и уведомить фронтенд.
