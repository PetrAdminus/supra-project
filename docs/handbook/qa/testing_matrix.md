# Тестирование и контроль качества

## Unit-тесты
- Конфигурации (`lottery_multi/tests/config_tests.move`).
- Продажи: лимиты пользователей, анти-DoS, распределение выручки, учёт выплат (`lottery_multi/tests/economics_tests.move`).
- VRF: повторные fulfill, payload V1, защита `consumed`, отказ `request_draw_admin` при паузе депозита.
- VRF-депозит: пауза запросов при низком остатке и возобновление после пополнения.
- WinnerComputation (`lottery_multi/tests/winner_tests.move`): dedup on/off, сравнение с эталонным расчётом, контроль checksum после батча.
- Выплаты (`lottery_multi/tests/payouts_tests.move`): идемпотентность батчей, контроль allowance джекпота, обновление агрегатов `Accounting`, события `PartnerPayout`/`PayoutBatch`, превышение лимитов операций и отсутствие `PartnerPayoutCap`.
- История (`lottery_multi/tests/history_dual_write_tests.move`): включённый dual-write, отсутствие ожидаемого хэша, снятие ожиданий через `notify_summary_written`, зеркальная запись `dual_write_mirror_summary` и проверка `dual_write_status`.

## Property-based
- Стабильность победителей при одинаковом seed.
- Отсутствие bias при стратегии stride.
- Сопоставление on-chain/оff-chain реализации (дифференциальный тест).

## Integration
- Партнёрские квоты, cooldown выплат и ограничение тегов.
- Dual-write миграция архива и сверка хэшей.
- AutomationBot: dry-run + execute + проверка таймлоков.

## Security
- Replay payouts с `payout_round`.
- Rate-limit на покупки, grace window.
- Ротация ключей AutomationBot и отзыв capability.

## Move Prover
- `spec/registry.move`: неизменность snapshot после freeze.
- `spec/payouts.move`: рост `payout_round` и `allocated >= paid`.
- `spec/economics.move`: невозрастающий `jackpot_allowance_token`.
- Запуск в CI обязателен (провал — блокировка merge).

## Газ и размер пакетов
- Снапшоты газа для `sales::buy_tickets`, `draw::close_and_request_vrf`, `payouts::execute_payout_batch`.
- Проверка байткода на превышение лимита 60 КБ.
- Метрика `size_growth_pct` в CI.
