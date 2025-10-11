# Мониторинг событий Supra dVRF 3.0

Этот документ описывает, как отслеживать события Supra dVRF 3.0 в сети testnet
после настройки подписки и запуска розыгрыша. Все примеры подразумевают, что
вы уже выполнили команды из [testnet_runbook](./testnet_runbook.md) и знаете
адрес контракта лотереи (`LOTTERY_ADDR`) и профиль Supra CLI (`PROFILE`).

## Основные события контракта лотереи

| Событие | Когда эмитится | Зачем отслеживать |
| --- | --- | --- |
| `SubscriptionConfiguredEvent` | После успешного `create_subscription` | Подтверждает, что депозит внесён и whitelisting завершён. |
| `DrawRequestedEvent` | При вызове `manual_draw`/`request_draw` | Фиксирует nonce и параметры запроса dVRF. |
| `DrawHandledEvent` | После колбэка Supra VRF | Публикует `request_hash`, whitelisted `callback_sender`, `client_seed`, `rng_count`, `num_confirmations` и список `randomness`, подтверждая, что случайность обработана правильным агрегатором. |
| `RoundSnapshotUpdatedEvent` | После `buy_ticket`, `schedule_draw`, `reset_round`, `request_randomness`, `fulfill_draw` | Публикует агрегированный `RoundSnapshot` (число билетов, статус расписания, `pending_request_id`, `next_ticket_id`) и позволяет Supra отслеживать готовность раундов без чтения таблиц. |
| `AggregatorWhitelistedEvent`/`ConsumerWhitelistedEvent` | При изменении whitelist | Позволяют аудиторам убедиться, что доступ выдан корректным адресам. |
| `WhitelistSnapshotUpdatedEvent` | После `init`, `whitelist_callback_sender`, `revoke_callback_sender`, `whitelist_consumer`, `remove_consumer` | Публикует whitelisted агрегатор и полный список потребителей одним событием — достаточно смотреть только этот поток, чтобы видеть текущее состояние whitelist. |
| `JackpotSnapshotUpdatedEvent` | После `init`, выдачи билетов, планирования или сброса розыгрыша, запроса и fulfill глобального джекпота | Публикует снимок глобального джекпота: администратора, `lottery_id`, количество билетов, статус расписания и `pending_request_id`, что позволяет Supra отслеживать готовность без чтения storage. |

## События VRF Hub

| Событие | Когда эмитится | Зачем отслеживать |
| --- | --- | --- |
| `CallbackSenderUpdatedEvent` (`@vrf_hub::hub`) | При вызове `set_callback_sender` администратором VRF Hub | Фиксирует предыдущий и текущий whitelisted агрегатор Supra; журнал пригодится для аудита операций whitelisting на уровне hub перед выдачей доступа конкретным лотереям. |

## События фабрики лотерей

| Событие | Когда эмитится | Зачем отслеживать |
| --- | --- | --- |
| `LotteryRegistrySnapshotUpdatedEvent` (`@lottery_factory::registry`) | После `init`, `create_lottery`, `update_blueprint`, `set_admin` | Публикует администратора фабрики и полный список лотерей с адресами, ценой билета и долей джекпота; позволяет Supra сверять, какие проекты зарегистрированы и кто управляет фабрикой без чтения всей истории событий. |

View-функция `@lottery_factory::registry::get_registry_snapshot` возвращает те же поля в JSON, а `list_lottery_ids` пригодится для быстрой проверки количества зарегистрированных лотерей:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move view \
  --profile $PROFILE \
  --function $LOTTERY_FACTORY_ADDR::registry::get_registry_snapshot"
```

Для получения только идентификаторов выполните:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move view \
  --profile $PROFILE \
  --function $LOTTERY_FACTORY_ADDR::registry::list_lottery_ids"
```

## Быстрый просмотр последних событий

Чтобы увидеть последние записи по каждому событию, используйте `move tool events list`. Для `DrawRequestedEvent` и `DrawHandledEvent` проверьте, что совпадают `request_hash`, `callback_sender` и параметры газа/подтверждений.
Команда выводит JSON; аргумент `--limit` задаёт количество событий, начиная с
последних (по убыванию номера).

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events list \
  --profile $PROFILE \
  --address $LOTTERY_ADDR \
  --event-type $LOTTERY_ADDR::main_v2::DrawHandledEvent \
  --limit 5"
```

## Непрерывное слежение во время тестов

Для live-мониторинга используйте `events tail`. Команда будет выводить новые
записи в режиме реального времени, пока вы не прервёте процесс (`Ctrl+C`).

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events tail \
  --profile $PROFILE \
  --address $LOTTERY_ADDR \
  --event-type $LOTTERY_ADDR::main_v2::DrawRequestedEvent"
```

Повторите команду для `DrawHandledEvent`, чтобы увидеть успешное завершение
розыгрыша. Аналогично можно отслеживать события whitelisting:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events tail \
  --profile $PROFILE \
  --address $LOTTERY_ADDR \
  --event-type $LOTTERY_ADDR::main_v2::WhitelistSnapshotUpdatedEvent"
```

## Проверка событий модулей Supra

Модуль `deposit` также публикует события (например, пополнение депозита).
Чтобы посмотреть их, укажите адрес модуля (по умолчанию
`0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e`).

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events list \
  --profile $PROFILE \
  --address $DEPOSIT_ADDR \
  --limit 10"
```

`events tail` также работает для адресов модулей Supra, что полезно при
разборе проблем с whitelisting или депозитом.

## Использование jq для агрегации

Чтобы быстро фильтровать поля (например, nonce или client seed), можно
использовать `jq`:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events list \
  --profile $PROFILE \
  --address $LOTTERY_ADDR \
  --event-type $LOTTERY_ADDR::main_v2::DrawRequestedEvent \
  --limit 1" | jq '.result[0].data'
```

## Просмотр pending-заявки через view

Событий достаточно для аудита, но Supra также рекомендует сверять состояние
контракта. Для этого в `Lottery.move` добавлена view-функция
`get_pending_request_view`, возвращающая структуру `PendingRequestView` с nonce,
адресом `requester`, хешем `request_hash`, параметрами газа и подтверждений.

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move view \
  --profile $PROFILE \
  --function $LOTTERY_ADDR::main_v2::get_pending_request_view"
```

Результат приходит в JSON: поле `Some` содержит все значения, которые Supra
ожидает видеть в `CallbackRequest`. Это удобно при отладке CLI или сравнении с
данными VRF Hub (`payload_hash`).

Для контроля глобального джекпота вызовите view `lottery::jackpot::get_snapshot` — структура совпадает с событием `JackpotSnapshotUpdatedEvent` и содержит `pending_request_id`, если заявка активна:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move view \
  --profile $PROFILE \
  --function $LOTTERY_ADDR::jackpot::get_snapshot"
```

Ответ `None` означает, что модуль ещё не инициализирован; `Some` возвращает поля `admin`, `lottery_id`, `ticket_count`, `draw_scheduled`, `has_pending_request` и `pending_request_id`.

Для раундов основной лотереи используйте view `lottery::rounds::get_round_snapshot`: результат содержит тот же `RoundSnapshot`, что публикует событие `RoundSnapshotUpdatedEvent`.

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move view \
  --profile $PROFILE \
  --function $LOTTERY_ADDR::rounds::get_round_snapshot \
  --arg u64:$LOTTERY_ID"
```

При активной заявке поле `pending_request_id` вернёт идентификатор VRF-запроса; в остальных случаях значение будет `None`, что совпадает с событиями снапшотов и упрощает сверку мониторинга Supra.

Для проверки whitelisted агрегатора VRF Hub вызовите view `@vrf_hub::hub::get_callback_sender_status`:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move view \
  --profile $PROFILE \
  --function $VRF_HUB_ADDR::hub::get_callback_sender_status"
```

Если агрегатор назначен, JSON вернёт `"Some": "0x…"`; значение `None` означает,
что VRF Hub не готов к обработке колбэков Supra и необходимо повторно вызвать
`set_callback_sender`.

## Интеграция в процессы QA

- Фиксируйте хэши транзакций и события `DrawRequestedEvent`/`DrawHandledEvent`
  в отчётах QA.
- При миграции на новые лимиты газа запускать `events list` перед и после
  изменений, чтобы сравнить, какие параметры закреплены в `SubscriptionConfiguredEvent`.
- Для аудита whitelisting выгружайте события в файл: `... events list --limit 50 > whitelist_events.json`.

Документ обновляется по мере появления новых требований Supra и внутренних
процессов QA.
