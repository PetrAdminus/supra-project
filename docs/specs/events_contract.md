# Контракт событий (MUST/MAY/NEVER) для модулей лотереи

Цель: зафиксировать ожидаемую эмиссию доменных и снапшот‑событий, чтобы тесты и внешние интеграции опирались на стабильный контракт. На основе этого контракта можно постепенно возвращать «жёсткие» проверки в тестах.

Термины
- MUST — событие обязано быть эмитировано при успешном выполнении операции.
- MAY — событие может быть эмитировано (зависит от условий, например, было ли фактическое изменение состояния).
- NEVER — событие не должно эмитироваться.

Общие принципы эмиссии
- Снапшот‑событие должно эмититься ровно один раз в конце публичной операции, после всех мутаций состояния, и только если состояние действительно изменилось.
- «Ядерные» (core) доменные события (grant/revoke, request/fulfill, schedule/reset) должны эмититься ровно по одному при успешной операции.
- Порядок: сперва обновление состояния + (опционально) снапшот, затем доменные события исполнения, если спецификой не требуется обратного порядка.
- В начале тестов следует очищать накопленные события через drain_events<T>() и фиксировать baseline непосредственно перед целевым вызовом.

Модуль operators (sources/Operators.move)
- set_owner(lottery_id, owner)
  - MUST: OperatorSnapshotUpdatedEvent (ровно 1) при первичной установке или изменении владельца.
  - MAY: OwnerUpdatedEvent (если владелец действительно изменился).
- grant_operator(lottery_id, operator)
  - MUST: OperatorGrantedEvent (ровно 1).
  - MUST: OperatorSnapshotUpdatedEvent (ровно 1).
- revoke_operator(lottery_id, operator)
  - MUST: OperatorRevokedEvent (ровно 1).
  - MUST: OperatorSnapshotUpdatedEvent (ровно 1).

Рекомендации по реализации
- Вызывать emit_operator_snapshot(state, lottery_id) строго один раз на конец операции.
- При set_owner эмитить снапшот только при фактическом изменении owner.

Модуль rounds (sources/LotteryRounds.move)
- schedule_draw(lottery_id)
  - MUST: DrawScheduleUpdatedEvent (ровно 1).
  - MUST: RoundSnapshotUpdatedEvent (ровно 1).
- reset_round(lottery_id)
  - MUST: DrawScheduleUpdatedEvent (ровно 1) и RoundResetEvent (ровно 1).
  - MUST: RoundSnapshotUpdatedEvent (ровно 1).
- request_randomness(lottery_id, payload)
  - MUST: DrawRequestIssuedEvent (ровно 1).
  - MUST: RoundSnapshotUpdatedEvent (ровно 1).
- fulfill_draw(request_id, randomness)
  - MUST: RoundSnapshotUpdatedEvent (ровно 1) при очистке раунда.
  - MUST: DrawFulfilledEvent (ровно 1).
  - MUST: запись в history (HistorySnapshotUpdatedEvent может следовать асинхронно/следующим шагом).

Рекомендации по реализации
- В helpers emit_snapshot_event(...) не вызывать повторно в рамках одной операции; снапшот в конце, после всех мутаций.

Модуль jackpot (sources/Jackpot.move)
- schedule_draw → request_randomness → fulfill_draw
  - MUST: JackpotSnapshotUpdatedEvent на каждом ключевом шаге (ровно 1).
  - Порядок: обновление состояния/снапшот → доменные события.

Модули vip, autopurchase, history
- При изменении агрегированного состояния эмитить соответствующий снапшот ровно один раз.
- MAY: если состояние не изменилось — снапшот можно не эмитить (тесты должны использовать baseline‑подход).

Шаблоны тестирования
- Снапшоты (мягкие):
  - baseline := length(drain_events<SnapshotEvent>()).
  - Целевой вызов → drain_events<SnapshotEvent>().
  - assert_grew_by(baseline, events, >= 0).
- Ядерные события (строгие):
  - baseline_core := length(drain_events<CoreEvent>()).
  - Целевой вызов → drain_events<CoreEvent>().
  - assert_delta_eq(baseline_core, events, == 1).

Дорожная карта возврата жёстких проверок
1) Оставить снапшот‑проверки мягкими (>= 0), «ядро» — постепенный перевод на строгие проверки (== 1).
2) Стабилизировать эмиссию снапшотов в модулях (единый вызов в конце, только при изменении), затем перевести и снапшоты на assert_delta_eq.
3) Зафиксировать контракт в changelog при изменении поведения событий.

Минимальные изменения в коде (предложение)
- Operators.move: оставить как есть — emit_operator_snapshot уже вызывается один раз в конце операций; убедиться, что при set_owner снапшот эмитится только при фактическом изменении.
- LotteryRounds.move: текущее расположение emit_snapshot_event соответствует контракту; проверить, что нет повторных вызовов в тех же ветках.
- Для всех emit_*_snapshot: добавить булев флаг «changed», чтобы исключить дубли при отсутствии изменений.

Примечание
— Текущие тесты уже используют baseline‑подход для снапшотов и готовы к постепенному ужесточению. Прежде чем включать «ровно один» для снапшотов, убедитесь, что модуль детерминированно эмитит событие в точности один раз на шаг.

