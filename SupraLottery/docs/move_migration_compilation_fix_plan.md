# План исправлений для успешной компиляции пакета lottery (Move 1)

Документ фиксирует полный перечень шагов, необходимых для устранения текущих ошибок компиляции и приведения кода к требованиям Move 1. Все изменения выполняем последовательно и фиксируем отдельными коммитами с упоминанием выполненных пунктов.

---

## 0. Подготовка

1. Во всех модулях, где понадобится «заморозка» мутабельной ссылки, добавляем `use std::borrow;` в начало файла.
2. Для дальнейших проверок держим под рукой быстрые команды:
   ```bash
   rg "math64::" SupraLottery/supra/move_workspace
   rg "&\*[_a-zA-Z]" SupraLottery/supra/move_workspace
   rg "\*[_a-zA-Z]" SupraLottery/supra/move_workspace/lottery -g"*.move"
   rg "round_snapshot_fields_for_test" -n
   rg "VipConfig" SupraLottery/supra/move_workspace/lottery/tests
   ```

### Быстрая сверка с актуальными ошибками компиляции

На 2024‑05‑29 компилятор Supra Move сообщает следующие классы ошибок (см. лог `move tool check`):

| Сообщение | Первопричина | Где встречается |
|-----------|---------------|-----------------|
| `Invalid dereference. Dereference requires the 'copy' ability` | Попытка вызвать `build_*snapshot(&*state)` или `build_*snapshot(&state)` | `metadata/Metadata.move`, `history/History.move`, `jackpot/Jackpot.move`, `lottery_instances/LotteryInstances.move`, `nft_rewards/NftRewards.move`, `operators/Operators.move`, `referrals/Referrals.move`, `rounds/LotteryRounds.move`, `vip/Vip.move` |
| `Invalid module access. Unbound function 'checked_add' in module '(std=0x1)::math64'` и подобные | Модуль `std::math64` в Supra Move не содержит `checked_add`, `checked_mul`, `mod`, `from_u16`, `mul_div` | `treasury_multi/TreasuryMulti.move`, `lottery_instances/LotteryInstances.move`, `rounds/LotteryRounds.move`, `jackpot/Jackpot.move`, `vip/Vip.move`, `store/Store.move`, `referrals/Referrals.move`, `autopurchase/Autopurchase.move` |
| `Invalid module '(lottery...)::lottery'` / `public(friend)` | Устаревший friend `lottery::lottery` и обращения к приватным API без friend-объявления | `treasury/Treasury.move`, `lottery/Lottery.move`, `referrals/Referrals.move`, `treasury_multi/TreasuryMulti.move` |
| Несовпадение длины кортежа (`Expected expression list of length 4`) | Сигнатуры helper-функций расширены до 5 элементов | `tests/migration_tests.move`, `tests/vip_tests.move`, `tests/autopurchase_tests.move` |
| `Invalid deconstruction binding` | Попытка распаковать приватный `VipConfig` в тестах | `tests/vip_tests.move` |
| `Invalid borrow` для `build_*snapshot(&state)` | Передача `&&T` вместо `&T` после `borrow_global<T>` | `history/History.move`, `lottery_instances/LotteryInstances.move`, `vip/Vip.move`, `nft_rewards/NftRewards.move`, `referrals/Referrals.move`, `operators/Operators.move` |

Эти сообщения полностью покрываются шагами ниже; таблица помогает быстро сопоставить конкретную ошибку с требуемым пунктом плана.

---

## 1. Удаление вызовов `math64::*`

**Проблема:** модуль `std::math64` в Supra Move не предоставляет функций `checked_add`, `checked_mul`, `mod`, `from_u16`, `mul_div`.  
**Исправление:** заменить на встроенные операции или локальные helper’ы (если нужна проверка).

| Файл | Что заменить |
|------|--------------|
| `lottery/sources/TreasuryMulti.move` | `math64::checked_add`, `math64::mul_div` |
| `lottery/sources/LotteryInstances.move` | `math64::checked_add` |
| `lottery/sources/LotteryRounds.move` | `math64::mod`, `math64::checked_add`, `math64::from_u16`, `math64::mul_div`, `math64::checked_mul` |
| `lottery/sources/Jackpot.move` | `math64::mod`, `math64::checked_mul`, `math64::checked_add` |
| `lottery/sources/Vip.move` | `math64::checked_add` |
| `lottery/sources/Store.move` | `math64::checked_mul`, `math64::checked_add` |
| `lottery/sources/Referrals.move` | `math64::mul_div` |
| `lottery/sources/Autopurchase.move` | `math64::checked_add` |

Базовые замены:
```move
// было
let value = math64::checked_add(a, b);
let rest  = math64::mod(a, b);
let mul   = math64::checked_mul(x, y);
let bps64 = math64::from_u16(bps);
let share = math64::mul_div(amount, basis_points, BASIS_POINT_DENOMINATOR);

// стало
let value = a + b;
let rest  = a % b;
let mul   = x * y;
let bps64 = bps as u64;
let share = amount * basis_points as u64 / BASIS_POINT_DENOMINATOR; // при необходимости добавить проверки вручную
```
Если требуется защита от переполнения, добавляем явные `assert!` перед операцией.

---

## 2. Корректные заимствования (`&T`, `&mut T`, `borrow::freeze`)

**Проблема:** повсеместно встречаются конструкции `build_snapshot(&state)` (когда `state: &T`) и `build_snapshot(&*state)` (когда `state: &mut T`). Move 1 запрещает такое обращение без `copy` у структуры.

### 2.1. Если `state: &T`
Заменяем `build_snapshot(&state)` → `build_snapshot(state)`.

### 2.2. Если `state: &mut T`
Заменяем `build_snapshot(&*state)` на:
```move
let snapshot = build_snapshot(borrow::freeze(state));
```

### 2.3. Обязательные места (не исчерпывающий список — проверить весь модуль)
- `lottery/sources/History.move`
- `lottery/sources/Operators.move`
- `lottery/sources/LotteryInstances.move`
- `lottery/sources/Autopurchase.move`
- `lottery/sources/Vip.move`
- `lottery/sources/NftRewards.move`
- `lottery/sources/Jackpot.move`
- `lottery/sources/LotteryRounds.move`
- `lottery/sources/Referrals.move`
- `lottery/sources/TreasuryMulti.move`
- Все тесты, которые вызывают `build_*_snapshot` или `*_fields_for_test`.

После правок обязательно прогоняем:
```bash
rg "&\*[^=]" SupraLottery/supra/move_workspace/lottery -g"*.move"
rg "build_.*(&state" SupraLottery/supra/move_workspace/lottery -g"*.move"
```

---

## 3. Доступ к полям без лишнего `*`

**Проблема:** разыменование `*event.request_hash`/`*event.randomness` и аналогичных полей, у которых нет copy-ability.

**Решение:** использовать прямой доступ (если тип copy) либо заранее клонировать вектор (как сделано с `clone_bytes` / `clone_u256_vector` в `Lottery.move`).

Проверяем командой:
```bash
rg "\*[a-zA-Z_]+\." SupraLottery/supra/move_workspace/lottery -g"*.move"
```
и устраняем каждое вхождение.

---

## 4. Настройка friend-видимости и вызовов `public(friend)`

### 4.1. Актуализировать списки друзей
- В `Treasury.move` заменить `friend lottery::lottery;` на `friend lottery::main_v2;`.
- Проверить, какие модулы обращаются к функциям `public(friend)` (например, `treasury_v1::distribute_payout`) и убедиться, что их модуль указан в friend-списке.

### 4.2. Доступ из других модулей
- Если `Referrals.move` вызывает `treasury_multi::share_config_operations_bps`, объявить функцию как `public(friend)` и добавить `friend lottery::referrals;` в `TreasuryMulti.move`.
- Аналогично для прочих приватных API.

### 4.3. Проверка
```bash
rg "public(friend)" SupraLottery/supra/move_workspace/lottery -g"*.move"
```
Убедиться, что для каждой функции есть соответствующий `friend`.

---

## 5. Сигнатуры helper-функций и tuple-деструктуризация

1. Если вспомогательные функции `*_fields_for_test` возвращают 5 значений, но тесты ожидают 4, обновляем тесты:
   ```move
   let (tickets, draw_scheduled, pending, next_id, maybe_request) =
       rounds::round_snapshot_fields_for_test(&snapshot);
   ```
   Если дополнительные поля не нужны, используем `_`.

2. Аналогично обновляем обращение к `main_v2::pending_request_view_fields` и другим helper’ам, чтобы количество переменных соответствовало кортежу.

3. Переходим по сообщениям компилятора с «Expected expression list of length 4» и правим каждую точку.

---

## 6. Геттеры вместо деструктуризации чужих структур

В тестах больше нельзя распаковывать приватные структуры (`VipConfig`, `LotteryShareConfig`, и т.д.). Добавляем в соответствующих модулях публичные функции-геттеры:
```move
public fun vip_config_price(cfg: &VipConfig): u64 { cfg.price }
public fun vip_config_duration_secs(cfg: &VipConfig): u64 { cfg.duration_secs }
public fun vip_config_bonus_tickets(cfg: &VipConfig): u64 { cfg.bonus_tickets }
```
Тесты переводим на вызов геттеров.

Проверка:
```bash
rg "let [^{]*VipConfig" SupraLottery/supra/move_workspace/lottery/tests
```

---

## 7. Обновление snapshot/helper API

Для каждого модуля со snapshot’ами (History, Jackpot, LotteryInstances, Autopurchase, Vip, Referrals, NftRewards, Operators, LotteryRounds):

1. Функции `build_*_snapshot` должны принимать `&T`, а вызывающий код передаёт:
   ```move
   let snapshot = build_*_snapshot(borrow::freeze(state), ...);
   ```
2. Если нужны мутабельные обновления + событие, последовательность следующая:
   ```move
   let state = borrow_global_mut<SomeState>(@lottery);
   let previous = option::some(build_snapshot(borrow::freeze(state)));
   // ... обновление state ...
   event::emit(... { previous, current });
   ```

3. Удаляем все повторяющиеся helper’ы, возвращающие &&T или требующие `copy`.

---

## 8. Проверки после правок

1. Локальные скрипты:
   ```bash
   rg "math64::" SupraLottery/supra/move_workspace            # должно вернуть только комментарии/ничего
   rg "&\*" SupraLottery/supra/move_workspace -g"*.move"      # не должно быть попаданий
   rg "public(friend)" SupraLottery/supra/move_workspace/lottery -g"*.move"
   rg "\*[A-Za-z_]+\." SupraLottery/supra/move_workspace/lottery -g"*.move"
   ```
2. Компиляция каждого пакета:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra move tool check --package-dir /supra/move_workspace/lottery --skip-fetch-latest-git-deps"
   docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra move tool check --package-dir /supra/move_workspace/lottery_factory --skip-fetch-latest-git-deps"
   docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra move tool check --package-dir /supra/move_workspace/vrf_hub --skip-fetch-latest-git-deps"
   docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra move tool check --package-dir /supra/move_workspace/SupraVrf --skip-fetch-latest-git-deps"
   ```
3. После успешного `move tool check` запускаем `move tool test` и python-раннер.

---

## 9. Дополнительные места для ревизии

Помимо сообщений компилятора, обязательно проверить:

- Модули, где ещё встречается `clone_*` без необходимости (`clone_bytes`, `clone_addresses`) — убедиться, что они вызываются только там, где действительно нужны копии.
- Все функции `ensure_*` и `record_*`, которые вызывают helper’ы — согласно новым сигнатурам.
- Тесты на миграцию, VIP, автопокупку — обновить кортежи и опять же убрать деструктуризацию приватных структур.
- Документацию и комментарии: при необходимости дописать пояснения, почему теперь используется `borrow::freeze`.

---

## 10. Финальный чек-лист

1. Поиск `math64::` возвращает пустой список.
2. Нет ни одного `&*` или `*field` для типов без copy.
3. Все вызовы snapshot/helper функций используют `borrow::freeze` или прямую ссылку без двойных `&`.
4. Friend-списки соответствуют фактическим зависимостям между модулями.
5. Тесты обновлены под новые кортежи и геттеры, нет деструктуризации чужих структур.
6. `docker compose run ... move tool check` и `move tool test` проходят для всех пакетов воркспейса.
7. `python -m supra.scripts.move_tests --workspace SupraLottery/supra/move_workspace --all-packages --mode check` возвращает код 0.

После завершения всех пунктов документ обновить, отметить выполненные шаги и приложить номера коммитов/отчётов тестов.
