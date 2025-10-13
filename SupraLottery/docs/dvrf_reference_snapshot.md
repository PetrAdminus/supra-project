# Снимок официального шаблона Supra dVRF (Supra dVRF Template)

Источник: [`Supra-Labs/supra-dapp-templates`](https://github.com/Supra-Labs/supra-dapp-templates/tree/main/templates/Supra%20dVRF%20Template).

## Move.toml
- **Адреса**: `dice_addr = "YOUR_ADDRESS"`, `supra_addr = "0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e"`.
- **Зависимости**:
  - `SupraFramework` из `Entropy-Foundation/aptos-core` (`aptos-move/framework/supra-framework`, ветка `dev`).
  - `SupraVrf` из `Entropy-Foundation/vrf-interface` (`supra/testnet`, ветка `testnet`).
- **Особенности**: шаблон ожидает именованные адреса и git-зависимости, без локальных копий библиотек.

## Модуль `contract.move`
- **Entry-функции**:
  - `init_module` — создаёт ресурс `DiceMapper` с таблицей запросов.
  - `roll_dice` — формирует `rng_request` в Supra VRF и сохраняет запрос по идентификатору.
  - `resolve_dice_roll` — колбэк, вызываемый VRF, верифицирует подпись через `supra_vrf::verify_callback` и записывает результат.
- **View-функции**: `get_dice_result` для чтения результата броска.
- **Ресурсы**: `DiceMapper` (`has key`) с таблицей `Table<u64, DiceRequest>`.
- **События**: `DiceRollEvent`, `DiceResultEvent` (используют `supra_framework::event`).
- **Используемые зависимости**: `supra_framework::event`, `aptos_std::table`, `std::string` и `std::vector`.

## Наблюдения для сравнения
- Официальный шаблон опирается на git-зависимости Supra; SupraLottery теперь зеркалирует этот подход: пакеты подтягивают `move-stdlib` и `SupraFramework` из `Entropy-Foundation/aptos-core`, а `SupraVrf` остаётся локальной копией официального пакета.
- Шаблон демонстрирует именованные адреса (`supra_addr`, `dice_addr`) и отсутствие жёстко зашитых hex-адресов внутри модулей.
- `rng_request` и `verify_callback` в шаблоне идентичны по сигнатурам текущему модулю `SupraVrf` в SupraLottery, что подтверждает правильность базового API.
- Шаблон хранит BCS-конверт запроса с полями `callbackAddress`, `callbackModule`, `callbackFunction`, счётчиками RNG и подтверждений; SupraLottery теперь строит `CallbackRequest` с тем же набором полей, добавляет whitelisted `callback_sender` (агрегатор Supra) и транслирует всё в события `DrawRequestedEvent`/`DrawHandledEvent`.
- View-функция `get_pending_request_view` возвращает `PendingRequestView` с теми же значениями, `callback_sender` и `request_hash`, что позволяет сверять события с on-chain состоянием без парсинга BCS вручную.
- Все события SupraLottery создаются через `supra_framework::account::new_event_handle`, поэтому GUID детерминирован (`id.addr` = адрес лотереи/хаба, `creation_num` фиксирован для каждого типа). После `move_to` публикуется стартовый снимок через `event::emit_event`, благодаря чему последовательность начинается с `0` и легко отслеживается off-chain инструментами.
- Для аудита Supra рекомендует фиксировать хеш запроса; VRF-хаб теперь публикует `payload_hash` (`sha3_256` от BCS-конверта), что облегчает сопоставление `RandomnessRequestedEvent` с колбэком `lottery::main_v2::DrawRequestedEvent`.
- VRF-хаб дополняет whitelisting агрегатора событием `CallbackSenderUpdatedEvent` и view `get_callback_sender_status`, поэтому оффчейн-команды могут отслеживать текущий whitelisted адрес без ручного чтения ресурсов.
- Наблюдается тесная связь с `supra_framework::event`, что нужно учесть при ревизии событий SupraLottery.

## Требования Supra VRF Subscription
- Документ [VRF Subscription FAQ](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/vrf-subscription-model.md) фиксирует формулу `minBalanceLimit = minRequests * maxGasPrice * (maxGasLimit + verificationGasValue)` и подчёркивает ограничения `callbackGasLimit ≤ maxGasLimit`, `callbackGasPrice ≤ maxGasPrice` для контрактов, зарегистрированных под подпиской.【F:SupraLottery/docs/dvrf_reference_snapshot.md†L53-L60】
- Секция [Other Functions](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/other-functions.md) перечисляет `removeContractFromWhitelist` для отключения контракта; SupraLottery теперь предоставляет обёртку `lottery::remove_subscription` и CLI `python -m supra.scripts remove-subscription`, повторяющие проверку `pending_request` перед вызовом.【F:SupraLottery/supra/move_workspace/lottery/sources/Lottery.move†L520-L551】【F:SupraLottery/supra/scripts/remove_subscription.py†L1-L123】
- Раздел [Request Random Numbers (EVMs)](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/request-random-numbers/evms.md) фиксирует предел `numConfirmations ≤ 20`; `configure_vrf_request` лотереи теперь прерывает попытки сохранить большее значение и CLI валидирует тот же диапазон перед вызовом Supra CLI.【F:SupraLottery/supra/move_workspace/lottery/sources/Lottery.move†L664-L694】【F:SupraLottery/supra/scripts/configure_vrf_request.py†L12-L49】【F:SupraLottery/tests/test_configure_vrf.py†L60-L76】

## Официальный пакет `SupraVrf` ([Entropy-Foundation/vrf-interface](https://github.com/Entropy-Foundation/vrf-interface/tree/testnet/supra/testnet))
- **Move.toml**: задаёт единственный именованный адрес `supra_addr` и подключает `SupraFramework` из `Entropy-Foundation/aptos-core` (`rev = "dev"`).
- **`supra_vrf.move`**: содержит только две native-функции (`rng_request`, `verify_callback`) с сигнатурами, совпадающими с шаблоном Supra dVRF и текущей реализацией SupraLottery.
- **`deposit.move`**: определяет native-entry функции (`client_setting_minimum_balance`, `add_contract_to_whitelist`, `remove_contract_from_whitelist`, `deposit_fund`, `withdraw_fund`) без дополнительной логики.
- **Move.toml**: локальная копия обновлена и теперь повторяет официальный пакет (`SupraFramework` через git, именованный адрес `supra_addr`).
- **Вывод**: локальный пакет `SupraVrf` в SupraLottery полностью совпадает по API с публичной версией `Entropy-Foundation/vrf-interface@testnet`; дальнейшее выравнивание смещается на синхронизацию остальных пакетов с `SupraFramework` и адресной конфигурацией.
