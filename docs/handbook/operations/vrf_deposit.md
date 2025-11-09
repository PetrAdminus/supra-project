# VRF-депозит Supra

## Цель
Отслеживать и поддерживать баланс колбэк-депозита dVRF так, чтобы новые запросы случайности не блокировались из-за нулевого `effective balance`.

## Метрики и пороги
- `total_balance` — общий баланс кошелька.
- `minimum_balance` — расчёт Supra (`window × maxGasPrice × (maxGasLimit + verificationGas)`).
- `effective_balance` — доступный остаток после резервов.
- `required_minimum` — значение `minimum_balance × min_balance_multiplier_bps / 10_000` из ончейн-конфигурации.
- `effective_floor` — абсолютный нижний порог в монетах.

Функция `views::get_vrf_deposit_status` возвращает эти значения и флаг `requests_paused`. Если `effective_balance < required_minimum` или `effective_balance < effective_floor`, модуль `vrf_deposit` автоматически публикует событие `VrfDepositAlert` и блокирует новые запросы VRF.

## Процедура оператора (RootAdmin / OperationalAdmin)
1. Вызвать `views::get_vrf_deposit_status` (или Supra CLI) и убедиться, что `requests_paused = false` и `effective_balance` выше порогов.
2. При необходимости зафиксировать снимок командой `vrf_deposit::record_snapshot_admin(total, minimum, effective, now_ts)` и сохранить значения в журнале эксплуатации.
3. Если `requests_paused = true`, пополнить колбэк-депозит на сумму не менее `required_minimum × 1.2` и вызвать `vrf_deposit::resume_requests`.
4. После пополнения отправить повторный снимок, проверить, что события `VrfRequestsResumed` и `VrfDepositSnapshot` опубликованы.
5. Обновить запись в runbook и уведомить команды поддержки о восстановлении сервисов.

## Автоматизация
- `AutomationBot` может использовать `vrf_deposit::record_snapshot_automation`, если обладает capability `ACTION_TOPUP_VRF_DEPOSIT`.
- При срабатывании алертов бот публикует `AutomationCallRejected` либо dry-run план пополнения, чтобы DevOps успели подтвердить транзакцию.

## Документация и журнал
- Все снимки и пополнения фиксируются в `docs/handbook/operations/incident_log.md` с указанием даты, суммы и ответственного.
- При изменении коэффициентов вызывается `vrf_deposit::update_config`, а новая конфигурация отражается в «книге проекта» и таблице лимитов газа.

## Ответственные
- **DevOps** — регулярный мониторинг, dry-run через AutomationBot.
- **RootAdmin** — утверждение лимитов и ручное пополнение.
- **TreasuryCustodian** — перевод средств на кошелёк депозита.
