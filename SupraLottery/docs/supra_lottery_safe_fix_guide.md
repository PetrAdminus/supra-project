# Supra Lottery Safe Fix Guide

## Цели
- Восстановить прохождение ключевых Move-тестов лотереи после чистки `mut`-привязок.
- Согласовать подготовку аккаунтов и ресурсов, необходимых для модулей VRF Hub, Treasury и Operators.
- Устранить несоответствия в проверках событий и аборт-кодах, вызванные изменением порядка инициализации.
- Обеспечить доступ к тестовым API Supra Framework (timestamp, VRF gas, registry helpers).

## Карта сбоев
| Пакет тестов | Конкретные тесты | Симптом | Предполагаемая причина |
|--------------|------------------|---------|------------------------|
| `operators_tests` | `admin_assigns_and_grants`, `owner_can_manage`, `unauthorized_cannot_grant` | `MISSING_DATA` при вызове `account::new_event_handle` | До инициализации не создан `Account` для `@operators` (или связанных адресов), отсутствуют ресурсы для event handle. |
| `instances_tests` | `cannot_create_without_registration`, `create_and_sync_flow`, `toggle_activity_flow`, `toggle_requires_synced_hub` | `MISSING_DATA` при `hub::init` | Перед `hub::init` отсутствует ресурс `Account` для адресов хаба/лотереи. |
| `vip_tests` | `admin_can_gift_and_cancel`, `vip_subscription_applies_bonus` | `MISSING_DATA` в `timestamp::now_microseconds` | В тестах не опубликован ресурс `CurrentTimeMicroseconds` или не вызван тестовый setter времени. |
| `lottery_tests` | `minimum_balance_reacts_to_gas_changes`, `set_minimum_balance_updates_state_and_event` | `E_INVALID_GAS_CONFIG` из `configure_vrf_gas_for_test` | Значения callback газа нарушают ограничения `<= max`. |
| `treasury_multi_tests` | `jackpot_requires_winner_store`, `jackpot_respects_frozen_winner`, `recipients_event_captures_statuses` | Несоответствие ожидаемых кодов/длины событий | Нарушен порядок подготовки стора/регистрации получателей перед вызовами. |
| `rounds_tests` | `request_and_fulfill_draw`, `schedule_and_reset_round`, `ticket_purchase_updates_state` | Переполнение/неправильные assert | Некорректный подсчет событий и пропущенная инициализация Treasury. |
| `autopurchase_tests`, `history_tests`, `jackpot_tests`, `store_tests`, `nft_rewards_tests`, `migration_tests`, `referrals_tests` | Несовпадение длины векторов событий, assert падают | После чистки `mut` привязок некоторые вызовы `ensure_core_accounts` или записи событий пропущены/сломаны. |

## План действий
1. **Восстановить подготовку аккаунтов перед инициализациями.**
   - Проверить `test_utils::ensure_core_accounts` и убедиться, что helper вызывается во всех setup-функциях (`setup_lottery`, `setup_instances`, `setup_operators`).
   - Для модулей, использующих уникальные адреса (`@vip_program`, `@history`, `@store_bonus`), добавить соответствующие вызовы `create_account_if_needed`.
   - Дополнительно убедиться, что `timestamp::publish_current_time_for_testing` (или аналог) вызывается до `vip::init`.

2. **Укрепить helper для timestamp.**
   - Добавить в `TestUtils.move` функцию, публикующую `CurrentTimeMicroseconds` с начальным значением, используя `timestamp::set_time_has_started_for_testing` / `set_time_microseconds_for_testing`.
   - Подключить helper в `vip_tests` перед `vip::init`.

3. **Перепроверить настройки VRF газа.**
   - Синхронизировать константы `VRF_MAX_GAS_*` и callback значений с актуальными параметрами Supra Testnet (из `SupraLottery/docs/SUPRA_FIX_PLAN.md` или конфигов).
   - В `lottery_tests` убедиться, что helper `configure_vrf_gas_for_test` получает значения, удовлетворяющие `callback <= max`.

4. **Нормализовать регистрацию Treasury и Stores.**
   - В `treasury_multi_tests` и `lottery_tests` переработать порядок шагов: сначала `treasury_v1::register_store`, затем `treasury_multi::init`, после чего выполнение сценариев.
   - Пересмотреть ожидаемые коды: если бизнес-логика изменилась (например, теперь возвращается `E_STORE_NOT_REGISTERED = 7`), обновить `expected_failure` и константы.

5. **Переоценить подсчеты событий.**
   - Для каждого теста с `vector::length(snapshot_events)` убедиться, что события берутся из корректного handle и что операции действительно их генерируют.
   - Где нужно — обновить ожидаемое количество событий или добавить шаги, триггерящие недостающие события.

6. **Почистить проверки `vector::borrow` в rounds.**
   - Перед обращением к `request_events_count - 1` удостовериться, что `request_events_count > 0`; иначе — адаптировать сценарий, чтобы гарантированно сгенерировать событие (через `schedule_round`, `request_random` и т.д.).

7. **Проверить миграцию и referrals.**
   - В `migration_tests::migrate_legacy_state` добавить регистрацию событий/состояния до assert.
   - В `referrals_tests` удостовериться, что pipeline покупки билетов и начисления бонусов завершён, чтобы события начисления присутствовали.

8. **Финальный прогон.**
   - Локально (или через CI) запустить `docker compose run --rm --entrypoint bash supra_cli -lc \
     "/supra/supra move tool test --package-dir /supra/move_workspace/lottery --skip-fetch-latest-git-deps"`.
   - Зафиксировать предупреждения `W09003` (unused assignment) как информационные; при необходимости исключить шум через `#[lint::allow]` в зависимых пакетах.

## Риски и проверки
- Перед изменением тестов свериться с актуальными abort-кодами модулей (см. `SupraLottery/supra/move_workspace/lottery/sources`).
- Изменение порядка инициализаций может потребовать обновить shared helpers (`setup_lottery` и т.п.) — стоит написать regression-тесты или хотя бы smoke-тесты для основных сценариев.
- После фиксов сделать выборочные проверки snapshot-структур, чтобы убедиться, что события продолжают покрывать нужные поля (через `event::all_events` либо прямой доступ к handle).

## Чек-лист перед коммитом
- [ ] Все setup-функции используют `ensure_core_accounts` и helpers timestamp.
- [ ] `configure_vrf_gas_for_test` вызывается с валидными параметрами.
- [ ] Обновлены `expected_failure` и asserts в тестах.
- [ ] Успешно выполнен полный прогон Move-тестов командой из раздела «Финальный прогон».

