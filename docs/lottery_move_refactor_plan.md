# План перехода на обновлённые паттерны Supra-Labs

## Цели
- Устранить ошибки компиляции Move, связанные с устаревшими паттернами заимствования и арифметики.
- Перевести события, снапшоты и утилиты на официальные подходы Supra-Labs.
- Обеспечить успешное прохождение `move tool test` для пакета `lottery` и связанных пакетов.

## Этапы
- [x] **Этап 0. Первичный аудит и перечень проблем.** Собраны текущие сообщения об ошибках компиляции, классифицированы модули с нарушениями (`Autopurchase`, `Referrals`, `Jackpot`, `LotteryRounds`, `Vip`, `Store`, `NftRewards`, `Metadata`, `History`, `LotteryInstances`, `Treasury`, `TreasuryMulti`, `Migration`).
- [x] **Этап 1. Сопоставление с эталоном Supra-Labs.**
  - Найти актуальные версии соответствующих модулей в официальных репозиториях `Supra-Labs` и зафиксировать ссылки/коммиты для ориентира.
  - Сформировать сводную таблицу различий (события, арифметика, API).
- [ ] **Этап 2. Общие утилиты и арифметика.**
  - Вынести безопасные арифметические функции (`checked_add`, `checked_mul`, `from_u16`, и др.) в локальный модуль, чтобы заменить `std::math64`.
  - Подготовить единый хелпер для эмиссии событий через `event::emit`, отказаться от хранения `EventHandle` в структурах состояния.
- [ ] **Этап 3. Рефакторинг снапшотов и заимствований.**
  - Для ресурсов без `copy`/`drop` способностей внедрить пары функций `*_snapshot_from_mut` и `*_snapshot_from_parts`.
  - Переписать эмиттеры и view-функции на использование новых хелперов без `&*state` и `borrow::freeze`.
- [ ] **Этап 4. Актуализация модулей домена.**
  - `Autopurchase`, `Store`, `Referrals`, `Jackpot`, `LotteryRounds`, `LotteryInstances`, `Vip`, `NftRewards`, `Operators` — обновить события, арифметику, доступ к приватным структурам, вызывать только публичные/`public(friend)` функции.
  - `Treasury` и `TreasuryMulti` — привести friend-списки к официальным, адаптировать выдачу наград через публичные API.
  - `Metadata`, `History`, `Migration` — синхронизировать снапшоты и зависимости от новых утилит.
- [ ] **Этап 5. Обновление тестовых утилит.**
  - Исправить тестовые хелперы (`round_snapshot_fields_for_test`, доступ к `VipConfig`, и др.) на новые сигнатуры.
  - Удалить деструктуризацию приватных структур, добавить публичные getter’ы при необходимости.
- [ ] **Этап 6. Финальные проверки и документация.**
  - Запустить `docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra move tool test --package-dir /supra/move_workspace/lottery --skip-fetch-latest-git-deps"`.
  - При необходимости прогнать тесты для `lottery_factory` и `vrf_hub`.
  - Обновить документацию, зафиксировать используемые официальные источники и результат тестов.

## Ближайшие задачи
1. Собрать ссылки на эталонные реализации Supra-Labs для всех затронутых модулей. ✅
2. Подготовить черновик модуля с безопасной арифметикой (замена `math64`). ✅
3. Спроектировать общий интерфейс для `event::emit` и распределить зоны ответственности между модулями. ✅

## Справочные материалы Supra-Labs

| Модули | Официальный источник | Ключевые моменты |
| --- | --- | --- |
| `Autopurchase`, `Referrals`, `Jackpot`, `LotteryRounds`, `LotteryInstances`, `Vip`, `NftRewards`, `Store`, `Operators`, `Treasury`, `TreasuryMulti`, `History`, `Metadata` | [Emitting Events with `event::emit`](https://github.com/Supra-Labs/documentation/blob/main/movevm/learn-move/emitting-events-with-event-emit.md) | Рекомендуемый подход Supra-Labs для генерации событий без хранения `EventHandle`, примеры прямого вызова `event::emit` из функций. |
| Все перечисленные модули, а также вспомогательные утилиты | [Math Operations in Move](https://github.com/Supra-Labs/documentation/blob/main/movevm/learn-move/math-operations-in-move.md) | Описание безопасных арифметических операций, сопоставимых с требуемыми хелперами `checked_add`/`checked_mul`/`from_u16` для замены `std::math64`. |
| Модули, работающие с числовыми константами и преобразованиями (`Vip`, `Jackpot`, `LotteryRounds`, `Treasury`, `TreasuryMulti`) | [Unsigned Integers in Move](https://github.com/Supra-Labs/documentation/blob/main/movevm/learn-move/unsigned-integers-in-move.md) | Объясняет выбор типов `u8/u16/u32/u64/u128`, кастинг и влияние на газ, что понадобится при рефакторинге конвертеров. |
| Все ресурсо-ориентированные модули (`Autopurchase`, `Referrals`, `History`, `Store`, `NftRewards`, `Vip`, `LotteryInstances`, `Treasury*`) | [Reading Resource Data with `borrow_global`](https://github.com/Supra-Labs/documentation/blob/main/movevm/learn-move/reading-resource-data-with-borrow_global.md) | Разъясняет требования `acquires` и безопасное чтение ресурсов, что критично для обновлённых view-функций. |
| Модули, где требуются пере-заимствования (`History`, `Metadata`, `Referrals`, `Store`) | [Passing Data in Move: Value vs. Reference](https://github.com/Supra-Labs/documentation/blob/main/movevm/learn-move/passing-data-in-move-value-vs.-reference.md) | Напоминает правила работы с `&`/`&mut` и повторным заимствованием без нарушения владения. |

> ✅ Этап 1 завершён: для всех затронутых модулей подобраны официальные материалы Supra-Labs, которые будем использовать как эталон при последующих шагах.

