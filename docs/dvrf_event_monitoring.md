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
| `DrawHandledEvent` | После колбэка Supra VRF | Показывает, что случайность обработана и розыгрыш завершён. |
| `AggregatorWhitelistedEvent`/`ConsumerWhitelistedEvent` | При изменении whitelist | Позволяют аудиторам убедиться, что доступ выдан корректным адресам. |

## Быстрый просмотр последних событий

Чтобы увидеть последние записи по каждому событию, используйте `move tool events list`.
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
  --event-type $LOTTERY_ADDR::main_v2::AggregatorWhitelistedEvent"
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

## Интеграция в процессы QA

- Фиксируйте хэши транзакций и события `DrawRequestedEvent`/`DrawHandledEvent`
  в отчётах QA.
- При миграции на новые лимиты газа запускать `events list` перед и после
  изменений, чтобы сравнить, какие параметры закреплены в `SubscriptionConfiguredEvent`.
- Для аудита whitelisting выгружайте события в файл: `... events list --limit 50 > whitelist_events.json`.

Документ обновляется по мере появления новых требований Supra и внутренних
процессов QA.
