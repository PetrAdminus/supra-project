# SupraLottery — статическая проверка модулей (этап G1)

Документ фиксирует результаты статического аудита, покрывающего пункт 2 чек-листа `internal_audit_checklist.md`. Цель — подтвердить соответствие ключевых модулей обновлённым требованиям Supra до запуска динамических тестов этапа G1.

## 1. dVRF, лотерея и фабрика
- Структуры `CallbackRequest`, `PendingRequestView`, события `DrawRequestedEvent`/`DrawHandledEvent` и whitelist-снимки в `lottery::main_v2` содержат поля `payload_hash`, `callback_sender`, данные колбэка и параметры газа, что совпадает с эталоном Supra.【F:SupraLottery/supra/move_workspace/lottery/sources/Lottery.move†L152-L259】
- Модуль `vrf_hub::hub` публикует событие `RandomnessRequestedEvent` с `payload` и `payload_hash`, а также снапшоты whitelisted агрегатора через `CallbackSenderUpdatedEvent` и одноимённый view.【F:SupraLottery/supra/move_workspace/vrf_hub/sources/VRFHub.move†L83-L131】
- `lottery_factory::registry` эмитит агрегированный `LotteryRegistrySnapshotUpdatedEvent` в `init`, `create_lottery`, `update_blueprint` и `set_admin`, предоставляя полный снимок зарегистрированных лотерей.【F:SupraLottery/supra/move_workspace/lottery_factory/sources/LotteryFactory.move†L47-L137】

## 2. Казначейство и распределение выплат
- `lottery::treasury_v1` использует `supra_framework::fungible_asset`, хранит `TokenState` с `MintRef`/`BurnRef`/`TransferRef` и публикует `RecipientsUpdatedEvent` с парами снапшотов получателей.【F:SupraLottery/supra/move_workspace/lottery/sources/Treasury.move†L1-L109】
- `lottery::treasury_multi` для каждого изменения получателей вызывает `RecipientsUpdatedEvent` с детальными статусами и предоставляет view `get_recipient_statuses`, возвращающий registration/freeze/balance для пулов джекпота и операций.【F:SupraLottery/supra/move_workspace/lottery/sources/TreasuryMulti.move†L62-L448】

## 3. Вспомогательные модули и наблюдаемость
- Реестр метаданных публикует `MetadataSnapshotUpdatedEvent` и view `get_metadata_snapshot`, обеспечивая агрегацию описаний витрины.【F:SupraLottery/supra/move_workspace/lottery/sources/Metadata.move†L34-L223】
- Каталог экземпляров лотерей эмитит `LotteryInstancesSnapshotUpdatedEvent` и предоставляет view `get_instance_snapshot`/`get_instances_snapshot` для административного и операционного мониторинга.【F:SupraLottery/supra/move_workspace/lottery/sources/LotteryInstances.move†L118-L501】
- Ресурсы `operators`, `autopurchase`, `rounds`, `treasury_multi` и смежные модули создают обработчики через `supra_framework::account::new_event_handle`, сразу публикуют стартовые снапшоты и тем самым фиксируют GUID (`creation_num`) в детерминированном порядке для мониторинга событий.【F:SupraLottery/supra/move_workspace/lottery/sources/Operators.move†L63-L103】【F:SupraLottery/supra/move_workspace/lottery/sources/LotteryRounds.move†L109-L132】【F:SupraLottery/supra/move_workspace/lottery/sources/TreasuryMulti.move†L176-L205】
- Автопокупка (`lottery::autopurchase`) публикует снапшоты и имеет view `get_lottery_snapshot`/`get_autopurchase_snapshot` для контроля планов и балансов.【F:SupraLottery/supra/move_workspace/lottery/sources/Autopurchase.move†L392-L415】
- VIP-подписки (`lottery::vip`) поддерживают view `get_vip_snapshot` и `get_lottery_snapshot`, а также снапшоты подписок.【F:SupraLottery/supra/move_workspace/lottery/sources/Vip.move†L308-L328】
- Магазин (`lottery::store`) предоставляет снапшоты ассортимента через `StoreSnapshotUpdatedEvent` и view `get_store_snapshot`/`get_lottery_snapshot`.【F:SupraLottery/supra/move_workspace/lottery/sources/Store.move†L361-L383】
- История розыгрышей (`lottery::history`) возвращает агрегированные данные функциями `get_lottery_snapshot` и `get_history_snapshot`, синхронно со снапшот-событиями.【F:SupraLottery/supra/move_workspace/lottery/sources/History.move†L209-L231】
- Джекпот (`lottery::jackpot`) экспортирует view `get_snapshot` и события fulfil/ticket, фиксирующие pending-заявки и розыгрыши.【F:SupraLottery/supra/move_workspace/lottery/sources/Jackpot.move†L274-L280】
- Раунды (`lottery::rounds`) публикуют `RoundSnapshotUpdatedEvent` и view `get_round_snapshot`/`pending_request_id` для аудита состояния draw.【F:SupraLottery/supra/move_workspace/lottery/sources/LotteryRounds.move†L317-L341】
- Реферальная программа (`lottery::referrals`) предоставляет агрегированный `ReferralSnapshotUpdatedEvent` и view `get_referral_snapshot` с полным списком лотерей и статистикой бонусов.【F:SupraLottery/supra/move_workspace/lottery/sources/Referrals.move†L464-L505】
- NFT-бейджи (`lottery_rewards::nft_rewards`) поддерживают view `get_snapshot`/`get_owner_snapshot` и снапшоты победителей, обеспечивая наблюдаемость наград.【F:SupraLottery/supra/move_workspace/lottery_rewards/sources/NftRewards.move†L242-L263】

## 4. Выводы и следующие шаги
- Статические проверки подтверждают, что ключевые требования Supra к событиям, snapshot-view и использованию Supra Framework выполнены. Отметки перенесены в чек-лист `internal_audit_checklist.md`.
- Динамические проверки (`move-test`, `python -m unittest`, смоук-тест testnet) остаются в плане этапа G1 и будут выполнены при наличии Supra CLI/тестового стенда.
