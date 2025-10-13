# План перехода SupraLottery на Move 1

Документ фиксирует все необходимые шаги для полного соответствия текущего кода требованиям Move 1 и Supra Framework. Выполняйте пункты последовательно; отмечайте прогресс ссылками на коммиты либо отчёты тестов.

---

## 1. Обновление инициализации событий

**Цель:** избавиться от устаревшего `event::new_event_handle` и перейти на `supra_framework::account::new_event_handle`, что гарантирует корректные GUID и совместимость с Move 1.

1. В каждом модуле замените создание хэндлов на `account::new_event_handle`. Актуальные файлы:
   - `SupraLottery/supra/move_workspace/lottery/sources/Autopurchase.move`
   - `…/History.move`, `…/Jackpot.move`, `…/Lottery.move`, `…/LotteryInstances.move`, `…/LotteryRounds.move`
   - `…/Metadata.move`, `…/NftRewards.move`, `…/Operators.move`, `…/Referrals.move`, `…/Store.move`
   - `…/Treasury.move`, `…/TreasuryMulti.move`, `…/Vip.move`
   - `SupraLottery/supra/move_workspace/lottery_factory/sources/LotteryFactory.move`
   - `SupraLottery/supra/move_workspace/vrf_hub/sources/VRFHub.move`
   - `SupraLottery/supra/move_workspace/SupraVrf/sources/*.move`
2. После `move_to` сразу выполняйте `borrow_global_mut` и генерируйте первый снапшот (см. пример в `LotteryFactory.move`).
3. Удалите вспомогательные функции `lottery::events::new_handle`, либо сведите их к thin-wrapper над `account::new_event_handle` и скорректируйте импорты.

**Проверка:** `move tool test --package-dir …/lottery` без ошибок и без предупреждений о недоступности `event::new_event_handle`.

---

## 2. Коррекция видимости и friend-доступа

**Цель:** Move 1 жёстче относится к `public(package)` и friend-модулям.

1. Проанализируйте каждую функцию с `public(package)` и переведите:
   - на `public(friend)` с явным перечислением дружественных модулей, либо
   - на `public entry`/`public` (если требуется внешний вызов), либо
   - на `public(package)` в пределах одного пакета Move 1 (без использования в других пакетах).
2. Убедитесь, что `friend`-списки покрывают реальные импорты (`friend lottery::rounds`, `friend lottery::jackpot` и т. д.). Move 1 требует, чтобы friend-импортируемые модули находились в том же пакете.
3. Пересоберите workspace; если компилятор сообщает «unbound module», либо перенесите модуль в тот же пакет, либо замените friend на публичный API.

---

## 3. Замена вспомогательных `events::emit*`

**Цель:** использовать базовые функции Supra Framework и избежать промежуточных обёрток.

1. В `SupraLottery/supra/move_workspace/lottery/sources/Events.move` замените содержимое:
   - уберите `emit`/`emit_copy`, используйте напрямую `event::emit_event`.
   - при необходимости оставьте thin-wrapper, но без собственных проверок.
2. В модулях (`Autopurchase`, `LotteryInstances`, `TreasuryMulti`, `Vip` и т. д.) замените вызовы `events::emit*` на `event::emit_event` или `event::emit_event(handle, copy message)` в зависимости от необходимости.
3. Убедитесь, что после изменения компилятор не сообщает предупреждений о неиспользуемых функциях в `Events.move`.

---

## 4. Очистка синтаксиса Move 1

**Цель:** убрать конструкции, несовместимые с Move 1.

1. Циклы вида:
   ```move
   let mut idx = 0;
   while (idx < len) {
       …
   }
   ```
   Замените на:
   ```move
   let idx = 0;
   while (idx < len) {
       …
       idx = idx + 1;
   }
   ```
   Тесты и код (`lottery`, `lottery_factory`, `vrf_hub`, `SupraVrf`) должны полностью уйти от `let mut`.
2. Уберите не-ASCII в исходниках и тестах (в частности, комментарии в `lottery/tests/*.move`).
3. Исправьте операторы `copy event.request_hash` на `copy event.request_hash` внутри корректных scopes (Move 1 требует закрывающих скобок).

---

## 5. Обновление Move.toml и адресов

1. `SupraLottery/supra/move_workspace/Move.toml` уже содержит `[package]` и `[addresses]`. Убедитесь, что локальные проекты (`supra/move_workspace`) синхронизированы с такой же структурой.
2. В пакетах `lottery`, `SupraVrf` и др. замените шаблоны `{{supra_addr}}` на реальные значения (например, тестнет-адрес `0x186…1219e`) либо подключите механизм override (через CLI).
3. Обновите `.move/config` (см. README) с новым workspace и адресами.

---

## 6. Автоматизация тестов

1. В `SupraLottery/supra/scripts/move_tests.py` добавьте режим, поддерживающий:
   - `--mode check` (только `move check`),
   - запуск через Docker Supra CLI и Aptos CLI,
   - fallback на `move test` с `--package-dir`.
2. Интегрируйте скрипт в GitHub Actions (`.github/workflows/*`), чтобы прогонять пакеты `lottery`, `lottery_factory`, `vrf_hub`, `SupraVrf` в CI.
3. Сохраняйте отчёты: `tmp/move-test-report.json`, `tmp/move-test-report.xml`, лог `tmp/unittest.log`.

---

## 7. Документация и конфигурация CLI

1. Обновите `README.md` и `SupraLottery/README.md`: добавьте инструкции Move 1 (`supra move tool test`, `--named-addresses`, обновлённый `move-tests` скрипт).
2. В `docs/testnet_runbook.md`, `docs/dvrf_reference_snapshot.md`, `docs/audit/internal_audit_*` свяжите новые команды CLI, структуру событий и GUID.
3. Добавьте `.move/config.example` и раздел в README о настройке (адреса, профили CLI, переменные окружения).
4. Убедитесь, что профиль `my_new_profile` добавлен в whitelist Supra. Обновите служебные проверки (`deposit::checkClientFund`, `monitor-json`) под новые адреса и зафиксируйте изменения в документах QA/hand-over.

---

## 8. План внедрения (рекомендуемый порядок)

1. **Этап A — инфраструктура**
   - Обновить `Move.toml` и заменить `supra_addr` во всех пакетах.
   - Почистить `.move/config`, README.
2. **Этап B — события**
   - Перевести все модули на `account::new_event_handle`.
   - Убрать `events::emit*`.
3. **Этап C — синтаксис**
   - Удалить `let mut`, кириллицу в комментариях, привести циклы.
   - Исправить `public(package)`/`friend`.
4. **Этап D — тесты**
   - `move tool test` для каждого пакета (`lottery`, `lottery_factory`, `vrf_hub`, `SupraVrf`).
   - `python -m supra.scripts.cli move-test --workspace … --all-packages`.
   - `PYTHONPATH=SupraLottery python -m unittest`.
5. **Этап E — CI и документация**
   - Обновить `move_tests.py`, добавить workflow.
   - Обновить `docs/*`.
6. **Этап F — финализация инфраструктуры**
   - Проверьте, что зеркало `/supra/move_workspace` ссылается на актуальный workspace (для Docker, CI и скриптов).
   - Обновите CI и вспомогательные скрипты, которые обращаются к зеркальным путям.
   - Уточните README и служебные инструкции, описывающие конечную структуру каталогов.

Фиксируйте результат каждого шага отдельным коммитом и ссылкой на отчёт (JSON/JUnit, unittest logs). После выполнения всех этапов `move tool test` на workspace должен проходить без ошибок, а чек-листы (internal audit + dVRF v3) — закрываться автоматом.
