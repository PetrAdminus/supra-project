# Переход SupraLottery на Fungible Asset

> Опираться на официальные материалы Supra: [token-standards](https://docs.supra.com/network/move/token-standards), [описание модуля fungible_asset](https://docs.supra.com/network/move/supra-fungible-asset-fa-module) и исходники `supra-framework` на GitHub ([Supra-Labs](https://github.com/Supra-Labs), [Entropy-Foundation/aptos-core](https://github.com/Entropy-Foundation/aptos-core/tree/dev/aptos-move/framework/supra-framework)).

## Статус
- ✅ Реализация Supra FA завершена: `treasury_v1` хранит `fungible_asset::Metadata` и capability, операции используют `primary_fungible_store`, а view-функции возвращают адреса primary store и supply. Оставшиеся задачи смещаются на доработку мультикадров (`TreasuryMulti`) и документации по миграции.
- ✅ `treasury_multi` валидирует, что `treasury_v1` инициализирован и адреса пулов зарегистрировали primary store, предоставляя view `get_recipients` для аудита перед выплатами.

## 1. Анализ текущей системы
- Провести поиск всех зависимостей `coin::Coin<SupraCoin>`:
  - `supra/move_workspace/lottery/sources/Lottery.move`.
- `supra/move_workspace/lottery/sources/Treasury.move`.
- Юнит-тесты в `supra/move_workspace/lottery/tests`.
  - CLI-скрипты и утилиты (например, `scripts/testnet_migration.sh`).
  - Фронтовые моки и типы.
- Зафиксировать бизнес-инварианты:
  - Кто обладает правом минта/бёрна и вывода средств.
  - Требуемые события и учётные записи, которые должны сохранять балансы.
  - Какие ограничения накладываются на продажи билетов и выплату джекпотов.

## 2. Дизайн схемы Fungible Asset
- Определить стратегию токена: выпуск нового проектного токена с собственной метаданной.
- Спроектировать владение capability-ресурсами:
  - Модуль `treasury_v1` хранит `MintCapability`, `BurnCapability` и `TransferCapability`.
  - Контракт лотереи и пользователи регистрируют `Store` на своих адресах.
- Продумать правила управления:
  - Нужен ли freeze-механизм, allowlist transfer, ограничения по supply.
  - Поведение при миграции и обновлениях.

## 3. Интеграция FA в Move-модули
- Добавить обёрточный модуль над `fungible_asset` с функциями `init_token`, `register_store`, `register_store_for`, `register_stores_for`, `mint_to`, `burn_from`, `transfer_between`.
- В `treasury_v1` заменить использование `coin::Coin` на числовые балансы через `fungible_asset::deposit/withdraw` или wrapper.
- Переписать функции `buy_ticket`, `payout_jackpot`, `withdraw_treasury` для работы с `Store` и capability.
- В `Lottery.move` адаптировать логику покупки билета, выплаты приза и сбор статистики.
- Зафиксировать хранение конфигурации распределения (basis points), добавить событие `ConfigUpdatedEvent` и админский метод `set_config`.

## 4. Миграция тестов и скриптов
- Обновить Move-юнит-тесты: регистрация `Store`, сценарии минта/переводов, проверка событий и негативные кейсы на попытку минта/депозита/покупки билета без подготовленного `Store`.
- Переписать скрипты (включая `supra/scripts/testnet_migration.sh` и CLI) под новые API: инициализация метадаты, регистрация хранилищ, выдача capability.

## 5. Вспомогательные утилиты
- Добавить view-функции: текущий баланс, общий supply, статус capability, а также админские хелперы для массовой регистрации `Store`.
- Предоставить агрегирующие view-функции `account_status` и `account_extended_status`, чтобы фронтенд получал регистрацию, freeze-статус и баланс за один RPC.
- Предусмотреть инструменты заморозки store: entry-функции администратора и view `store_frozen`, чтобы оперативно блокировать подозрительные аккаунты и отслеживать статус.
- При назначении получателей распределения проверять, что для каждого адреса предварительно зарегистрирован primary store и store не заморожен; иначе `set_recipients` должна завершаться с ошибкой, чтобы соблюсти требования Supra FA к зарегистрированным и активным хранилищам. ✅ Реализовано в `treasury_v1::set_recipients` и дополнено в `treasury_multi::init/set_recipients`.
- Добавить view для аудита получателей мультикадров: `treasury_multi::get_recipient_statuses` отдаёт адрес, признак регистрации, freeze и баланс Supra FA; Move-тесты проверяют сценарии после распределения и вывода средств. ✅
- Добавить view для аудита базовых получателей: `treasury_v1::get_recipient_statuses` публикует регистрацию, freeze и адрес primary store для направлений казначейства; тестовый декодер `recipient_status_fields_for_test` позволяет валидировать структуру в Move-тестах. ✅
- Усилить проверки выплат: `treasury_multi::init/set_recipients`, `withdraw_operations`, `pay_operations_bonus_internal` и `distribute_jackpot` проверяют регистрацию и freeze-статус получателей, предотвращая зависание средств в замороженных primary store. ✅
- Логировать обновления получателей базового казначейства: событие `treasury_v1::RecipientsUpdatedEvent` публикует парные снимки (предыдущий и текущий `VaultRecipientsSnapshot`) при инициализации и каждом вызове `set_recipients`, что позволяет Supra отслеживать историю изменений и сравнивать конфигурации. ✅
- Синхронизировать журналирование мультипулов: `treasury_multi::RecipientsUpdatedEvent` эмитится при `init` и `set_recipients`, публикуя `RecipientStatus` для предыдущих и новых адресов, что позволяет Supra наблюдать за сменой пулов и freeze-статусами. ✅
- Экспортировать `get_config`, `config_event_fields` и документацию по конфигурации распределения, чтобы фронтенд и операторские скрипты отображали доли и реагировали на события.
- Реализовать функции миграции Store для безопасного обновления конфигураций.

## 6. Документация и фронтенд
- Обновить `README`, `testnet_runbook` и фронтовые моки, описав новый токен, адрес метадаты и процесс регистрации.
- Актуализировать API фронтенда: получение балансов казначейства, долей и статистики.

## 7. Тестирование и сопровождение
- Запустить локальные Move-тесты и интеграционные сценарии: минт → покупка → выплата → бёрн.
- Подготовить чеклист деплоя на тестнет: порядок вызовов инициализации и регистрации Store.
- Описать откатный план: резервирование capability и снапшоты балансов для возврата на старую логику.
