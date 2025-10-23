# Supra Integration Guide

Эта памятка описывает шаги, чтобы заменить mock-режим фронтенда на реальные вызовы Supra после получения whitelisting.

## 1. Предпосылки
- Дождаться подтверждения от Supra support (см. `../SupraLottery/docs/testnet_runbook.md`, раздел 2).
- Убедиться, что dVRF подписка успешно настроена (`deposit::*`, `configure_vrf`, `record_*` отработали без ошибок).
- Имеются учетные данные StarKey (или альтернативного кошелька), которые будут подписывать транзакции из фронтенда.
- Настроен доступ к Supra RPC (тестнет: `https://rpc-testnet.supra.com`, мейннет: `https://rpc-mainnet.supra.com`).

## 2. Замена `supraClient.ts`
Файл `src/api/supraClient.ts` содержит заглушки. Для каждого метода нужно реализовать реальные вызовы.

### Вариант A: прямые JSON-RPC запросы
- Использовать HTTP POST на `NEXT_PUBLIC_SUPRA_RPC_URL` с методами `move_view`, `submit_transaction`, `get_account_resources`, и т.д.
-  Для view-функций (`fetchLotteryStatusSupra`, `fetchWhitelistStatusSupra`, `fetchTicketsSupra`, `fetchLotteryEventsSupra`):
   1. Сформировать payload вида `{ "jsonrpc": "2.0", "id": 1, "method": "move_view", "params": { ... } }`.
   2. Передать `function_id` из соответствующего пакета (`lottery_core::main_v2::get_lottery_status`, `lottery_core::rounds::history_queue_length`, `lottery_support::history::get_history_snapshot`, `lottery_rewards::vip::get_lottery_snapshot` и т.п.) и список аргументов/типов.
   3. Распарсить ответ и привести к типам `LotteryStatus`, `WhitelistStatus`, `TicketPurchase`, `LotteryEvent`.
- Для `purchaseTicketSupra` (и других мутаций) требуется готовить и подписывать BCS-транзакцию. Рекомендуется вынести логику подписи в отдельный helper (например, использовать StarKey SDK или бэкенд-прокси, чтобы скрыть приватный ключ). Для операций наград и поддержки используйте entry-функции новых пакетов (`lottery_support::history::sync_draws_from_rounds`, `lottery_rewards::autopurchase::deposit`, `lottery_rewards::rounds_sync::sync_purchases_from_rounds` и др.).

### Вариант B: бэкенд-прокси / CLI wrapper
- Поднять сервис, который внутри вызывает `supra move tool view/run` (через Docker либо бинарь).
- Фронтенд обращается к REST эндпоинтам (например, `/api/supra/view/lottery-status`), которые возвращают JSON.
- Этот подход проще в реализации, если уже есть готовые CLI скрипты, но требует бэкенда и безопасного хранения ключей.

Рекомендуется начать с варианта B для быстрого прототипа, а затем перейти к чистому RPC (вариант A), чтобы сократить задержки и зависимость от CLI.

> После разделения SupraLottery на пакеты `lottery_core`, `lottery_support`, `lottery_rewards` фронтенду необходимо маршрутизировать запросы по новым пространствам имён. Покупка билетов (`buy_ticket`, `manual_draw`) осталась в `lottery_core::main_v2`, история розыгрышей читается через `lottery_support::history`, а VIP/рефералы и автопокупки работают через `lottery_rewards`. При внедрении RPC-клиента сразу разделяйте функции по модулям, чтобы избежать refactor-переездов позднее.

## 3. Настройка окружения (`.env`)
Пример для тестнета:
```
VITE_API_MODE=mock
VITE_SUPRA_RPC_URL=https://rpc-testnet.supra.com
VITE_SUPRA_CHAIN_ID=6
VITE_LOTTERY_CORE_MODULE=0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::lottery_core::main_v2
VITE_LOTTERY_ROUNDS_MODULE=0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::lottery_core::rounds
VITE_LOTTERY_SUPPORT_MODULE=0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::lottery_support::history
VITE_LOTTERY_REWARDS_MODULE=0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::lottery_rewards
```
При включении режима `supra` в UI читать эти переменные и использовать в `supraClient.ts`. Для удобства можно добавить алиасы для ключевых entry-функций (`LOTTERY_MANUAL_DRAW=lottery_core::main_v2::manual_draw`, `LOTTERY_SYNC_HISTORY=lottery_support::history::sync_draws_from_rounds`, `LOTTERY_SYNC_PURCHASES=lottery_rewards::rounds_sync::sync_purchases_from_rounds`).

## 4. Кошелёк StarKey / WalletConnect
- В `src/features/wallet/` сейчас используется стаб. Реализуйте:
  - `connectWallet` / `disconnectWallet` через StarKey SDK.
  - Подписанные транзакции передайте в `purchaseTicketSupra`.
  - Добавьте обработку событий (пример: Crystara SDK использует `walletEvents.on(WALLET_EVENTS.TRANSACTION_START)` — можно повторить подход).
- Если потребуется WalletConnect, заведите отдельный провайдер и переключатель в UI.

## 5. Storybook и тесты
- После интеграции важно обновить JSON в `src/mocks/`, чтобы `mock` режим и сторисы отражали реальные структуры.
- Добавить истории, покрывающие `supra` режим (например, Storybook `SupraMode` уже есть для Tickets — расширить аналогами для Dashboard/Admin/Logs).
- Юнит-тесты (`Vitest`) можно дополнить моками RPC запросов (использовать `vi.mock('node-fetch', ...)`).

## 6. Контроль качества
- Для каждого RPC-запроса логируйте (в dev-режиме) payload/response — пригодится при отладке.
- Настройте наблюдение за ошибками (Sentry, console-toasts) — приложение должно корректно отображать ошибки Supra и retry-сценарии.
- При деплое зафиксируйте используемые RPC endpoints и chain_id в документации.

## 7. Чеклист перехода на реальную сеть
1. Получить whitelisting и записать хэши транзакций в `docs/testnet_runbook.md`.
2. Реализовать `supraClient.ts` (view + мутации) и проверять через `VITE_API_MODE=supra`.
3. Заменить стаб кошелька на StarKey/WalletConnect.
4. Обновить mock JSON и Storybook.
5. Прогнать e2e (Playwright/Cypress) в режиме mock и затем supra.
6. Обновить README/runbook с итоговыми параметрами (RPC, chain id, идентификаторы пакетов `lottery_core`/`lottery_support`/`lottery_rewards`).

## 8. Полезные материалы
- Supra JSON-RPC спецификация (в официальной документации)
- Пример Crystara SDK (README в `/docs/crystara_note` или общий README проекта)
- Наш runbook: `../SupraLottery/docs/testnet_runbook.md`### Reference: Base documentation snippets
- Foundry tutorial �Generating random numbers contracts using Supra dVRF� ����������, ��� � EVM ��������� �������� `ISupraRouter.generateRequest("requestCallback(uint256,uint256[])", rngCount, numConfirmations, clientAddress)` � ������������ ������ `requestCallback(uint256 nonce, uint256[] rngList)` � ��������� `msg.sender == supraAddr`.
- ��� Base Sepolia ������������ `ISUPRA_ROUTER_ADDRESS=0x99a021029EBC90020B193e111Ae2726264a111A2`; ����������� ������ ����� �������� ��� Supra testnet/mainnet.
- ����� ������������� �������� ����� whitelisting���� � ��������� ������ ����� Supra (����������� ���� ����������� � ����� runbook).
- ����� ������ ���������� ����� Foundry �������� `forge create ... --constructor-args $ISUPRA_ROUTER_ADDRESS`, � ������ ����������� �������� `cast wallet import` � ����������, ���� ����� �������� � EVM-��������� ������ Supra.
## ������� �� ������ "What Components Do You Need to Build a dApp on Supra"
- dApp �� Supra = backend (Move-��������� + CLI) + frontend (React.js + SDK + Vite). ��� ���� React/Vite ������������� �������������, � CLI-������� �� ../SupraLottery/docs/testnet_runbook.md ��������� ������-�����.
- SupraClient ������ ����� ��� ����: ������ on-chain ������ (view), �������� ��������� ���������� � ���������� ����������� ��������. ������ ��� ��������� ����������� � src/api/supraClient.ts ����� whitelisting.
- CLI ������� ������� ��������: ����� ���� �����������, ������� � �������� ���������. ��� �������� �� �������� RPC ����� ��������� ������� � ������� (compile/run/view) � �������� ��������� �� �� �� �������.
- ������ (StarKey/WalletConnect) ���������� ��� ������� ����������: ������������ ������������, �����������, SupraClient ����������. ���� ������� wallet-���� � ��������� �������, ����� ����� �������� �� �������� SDK.
- ���� ���������: ���� > SupraClient RPC. ����� whitelisting ����������� piMode �� supra � ��������� ���� ��������� ��������; Storybook � ����� ������ �������� �� �� ��������� ������.
