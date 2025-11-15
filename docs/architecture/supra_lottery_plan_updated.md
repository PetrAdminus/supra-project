
# Supra Lottery 2.0 — Архитектурный План (Обновлённая версия)

## Обновления:
- Добавлены тестовые боты player1–5 (только для testnet).
- Добавлена расширенная конфигурация лотерей и розыгрышей.
- План соответствует честной и прозрачной модели Web3 dApp.

## 1. Резервные боты (player1–5)
На тестовой сети проект использует заранее созданные аккаунты:
- player1
- player2
- player3
- player4
- player5

### Назначение:
- Автоматическое участие в тестовых розыгрышах через AutomationBot.
- Проверка механики min_participants.
- Генерация активности, если реальных участников мало.
- Тестирование больших выборок и VRF.

### Важно:
- **На mainnet боты навсегда отключены.**
- Используются только на devnet/testnet.
- Любые награды ботов не выводятся, а идут обратно в фонд тестов.

---

## 2. Конфигурация лотерей / розыгрышей

Каждая лотерея создаётся на основе `LotteryConfig`:

### Основные параметры:

#### Экономика
- `ticket_price: u64`
- `currency: address` (SUPRA по умолчанию)
- `max_tickets_per_user: Option<u64>`

#### Участники
- `min_participants: u64`
- `max_participants: Option<u64>`
- `allow_bots: bool` (только testnet)

#### Время
- `sales_start_ts: u64`
- `sales_end_ts: u64`
- `auto_close_on_end: bool`

#### Призовой план
- `prize_slots: vector<PrizeSlot>`
- `winners_dedup: bool`
- `draw_algo: u8`  
  0 — simple mod  
  1 — dedup  
  2 — stride  

#### Метаданные
- `primary_type: u8`
- `tags_mask: u64`

---

## 3. Интеграция с Supra-экосистемой

### Используем официальные механизмы:
- Supra MoveVM + Stdlib + Framework
- dVRF v3 (хэширующий payload)
- Automation & AutoFi
- Push Oracles (SUPRA/USD)
- dApp templates (npx @supranpm/supra-dapp-templates)

---

## 4. Позиционирование проекта
Проект продвигается как:

> **100% честный, прозрачный и проверяемый Web3 dApp.  
> Каждый розыгрыш доказываем математически через dVRF.  
> Каждый шаг доступен в on-chain истории.**

---

## 5. Testnet → Mainnet

### Testnet:
- включены player1–5,
- более мягкие лимиты,
- автоматическое участие ботов,
- расширенные логи.

### Mainnet:
- боты отключены,
- строгие лимиты,
- аудит,
- Move Prover инварианты.

---

## 6. Структура новых пакетов Move

### Пакет 1 — core_lottery  
Основные модули:
- registry  
- config  
- sales  
- draw  
- payouts  
- accounting  
- profiles  
- views  
- feature_switch  
- tags  

### Пакет 2 — core_rewards  
Хранилища:
- jackpot  
- nft_store  
- partner_vault  

---

## 7. Лимиты
- Каждый модуль ≤ **60 000 байт**.
- Только Move v1 синтаксис.
- Никакой кириллицы в коде.

---

## 8. Возможность расширения
Можно в любой момент создать новый пакет:
- core_campaigns  
- core_social  
- core_markets  
- core_privacy  
- core_premium  
- core_governance  

И подключить его без изменения ядра.

---

## 9. Чек-лист честности
- dVRF seed → event  
- hash payload → stored  
- winner selection deterministic  
- payouts logged  
- no admin overrides  
- no hidden logic  
- all configs on-chain  

---

## Файл готов к использованию
