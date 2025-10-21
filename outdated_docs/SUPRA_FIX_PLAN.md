# SUPRA LOTTERY — ПЛАН ПРАВОК

## ⚙️ ЦЕЛЬ
Исправить ошибки тестов Move (MISSING_DATA, E_INVALID_GAS_CONFIG и др.)  
в пакетах `lottery`, `vrf_hub`, `treasury_multi`, `nft_rewards`, `operators` и др.

---

## 1️⃣ MISSING_DATA (code 4008): отсутствует Account ресурс

**Причина:**
`0x1::account::new_event_handle` требует существующий ресурс `Account` по адресу signer.

**Решение:**
Добавить создание аккаунта в setup каждого теста до вызовов init.

> 🔎 **Контрольный список адресов**
>
> - `@lottery`
> - `@vrf_hub`
> - `@operations_pool`
> - `@jackpot_pool`
> - `@lottery_owner`
> - `@nft_rewards`
>
> Если тесты добавляют новые адреса, сразу внесите их сюда и убедитесь, что для них создан `Account`.

```move
use std::account;

public fun setup_environment(lottery_admin: &signer) {
    account::create_account_for_test(@lottery);
    account::create_account_for_test(@vrf_hub);
    account::create_account_for_test(@operations_pool);
    // и любые другие адреса, от которых создаются EventHandle
    hub::init(lottery_admin);
}
```

📘 **Источник:**  
[Supra Move Framework — Events](https://docs.supra.com/supra-network/smart-contracts/move/framework#emitting-events)

---

## 2️⃣ Предупреждения `#[expected_failure(abort_code = N)]`

**Причина:**  
Атрибут без `location` может “сработать” при любом модуле.

**Решение:**  
Добавить `location=…` или использовать константы модуля.

```move
#[expected_failure(location = @lottery::treasury_multi, abort_code = 14)]
fun operations_withdraw_requires_not_frozen(...) { ... }

#[expected_failure(
    abort_code = treasury_multi::E_OPERATIONS_RECIPIENT_FROZEN,
    location = @lottery::treasury_multi
)]
fun operations_withdraw_requires_not_frozen(...) { ... }
```

📘 **Источник:**  
[Zellic Blog — Aptos Move testing framework](https://www.zellic.io/blog/exploring-the-aptos-move-testing-framework#expected_failure-attribute)

---

## 3️⃣ Утилита `unwrap` (ошибка `option::extract`)

**Причина:**  
`option::extract` требует `&mut Option<T>`.

**Решение:**  
Использовать `&mut` в сигнатуре и вызовах.

```move
public fun unwrap<T>(o: &mut option::Option<T>): T {
    assert!(option::is_some(o), 9);
    option::extract(o)
}

// использование
let val = test_utils::unwrap(&mut opt_val);
```

📘 **Источник:**  
[StackOverflow — Option.extract usage](https://stackoverflow.com/questions/79116778/how-can-i-destroy-delete-an-option)

---

## 4️⃣ `E_INVALID_GAS_CONFIG` в VRF

**Причина:**
`callback_gas_price` / `callback_gas_limit` превышают `max_gas_price` / `max_gas_limit`.

**Решение:**
В тестах согласовать значения:

> 📏 **Откуда взять значения**
>
> - Базу берём из `main_v2::DEFAULT_VRF_GAS_CONFIG` (или аналогичной константы в коде).
> - Для тестов можно уменьшить лимиты, но важно сохранять соотношение `callback <= max`.
> - При необходимости сравниваем с конфигом сети (см. `supra/config/vrf` в репозитории).

```move
let max_gas_price = 1000;
let callback_gas_price = 900;
let max_gas_limit = 2_000_000;
let callback_gas_limit = 1_500_000;

main_v2::configure_vrf_gas_for_test(
  max_gas_price, max_gas_limit, callback_gas_price, callback_gas_limit
);
```

📘 **Источник:**  
[Supra VRF — Docs](https://docs.supra.com/supra-network/vrf)

---

## 5️⃣ Treasury tests: порядок инициализации

**Причина:**  
`init` вызывается раньше, чем зарегистрированы store и создан Account.

**Решение:**  
Правильный порядок в setup:

```move
use std::account;
use lottery::treasury_v1;

account::create_account_for_test(@lottery);
account::create_account_for_test(@jackpot_pool);
account::create_account_for_test(@operations_pool);

treasury_v1::init_token(lottery_admin, b"LotteryCoin", b"Lottery Coin", b"LOT", 6, b"", b"");
treasury_v1::register_store_for(lottery_admin, @jackpot_pool);
treasury_v1::register_store_for(lottery_admin, @operations_pool);

treasury_multi::init(lottery_admin, @lottery_owner, @operations_pool);

// доп. шаг для тестов NFT-вознаграждений
lottery_rewards::nft_rewards::init(lottery_admin, @nft_rewards);
```

📘 **Источник:**  
[Supra Move Framework](https://docs.supra.com/supra-network/smart-contracts/move/framework)

---

## 6️⃣ `friend lottery::treasury_multi_tests` ошибка

**Причина:**  
Модуль friend не существует при обычной сборке.

**Решения:**  
a) Оставить `friend`, если сборка всегда идёт с tests.  
b) Или удалить и использовать `#[test_only] public` методы.

```move
// убрать лишний friend
// friend lottery::treasury_multi_tests;
#[test_only]
public fun test_get_state(...) { ... }
```

📘 **Источник:**  
[Supra Move Environment](https://docs.supra.com/supra-network/smart-contracts/move/environment)

---

## 7️⃣ Проверить `VRFHub.init` и `treasury_multi.init`

Оба используют `account::new_event_handle`.
→ убедиться, что `account::create_account_for_test(@lottery)` вызван до них.

---

## ✅ Финальный чек-лист перед коммитом

1. `move test -p SupraLottery` — все тесты зелёные.
2. Отдельно прогнать `move test --filter vrf` для VRF кейсов.
3. Проверить, что все новые адреса добавлены в список из раздела 1.
4. Убедиться, что ни один модуль не зависит от `friend` вне тестового окружения.

### 🧪 Команды для запуска тестов

```bash
# 1. Поднимите CLI-окружение Supra (если ещё не поднято)
docker compose up -d supra_cli

# 2. Выполните тесты пакета Lottery из контейнера
docker compose exec supra_cli supra move test -p SupraLottery

# 3. Запустите VRF-ориентированные сценарии отдельно
docker compose exec supra_cli supra move test -p SupraLottery --filter vrf

# 4. По окончании работы остановите контейнер
docker compose down
```

---

## 8️⃣ Мелкие исправления

- Игнорировать W09003 “unused assignment” в внешних либах (`vesting_without_staking.move`)
- Проверить consistency abort-кодов (`E_OPERATIONS_RECIPIENT_FROZEN` и т.д.)
- При необходимости добавить `location` в `expected_failure` для всех тестов.

---

## 9️⃣ Финальный чек-лист перед тестами

✅ создать Account для всех адресов, где вызываются `init/new_event_handle`  
✅ зарегистрировать store перед init Treasury  
✅ согласовать VRF gas config  
✅ исправить unwrap  
✅ уточнить expected_failure(location = …)  
✅ friend → #[test_only] public  
✅ запустить docker compose test

---

## 🔗 ИСТОЧНИКИ

- [Supra Move Framework](https://docs.supra.com/supra-network/smart-contracts/move/framework)
- [Supra VRF](https://docs.supra.com/supra-network/vrf)
- [Expected_failure attribute](https://www.zellic.io/blog/exploring-the-aptos-move-testing-framework#expected_failure-attribute)
- [Option.extract example](https://stackoverflow.com/questions/79116778/how-can-i-destroy-delete-an-option)
- [Supra Move Environment](https://docs.supra.com/supra-network/smart-contracts/move/environment)

---

**Конец плана ✅**
