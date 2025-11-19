# РџРѕС€Р°РіРѕРІРѕРµ СЂСѓРєРѕРІРѕРґСЃС‚РІРѕ РїРѕ СЌС‚Р°РїР°Рј `lottery_multi`

Р”РѕРєСѓРјРµРЅС‚ РѕРїРёСЃС‹РІР°РµС‚ РїСЂР°РєС‚РёС‡РµСЃРєСѓСЋ СЃС‚РѕСЂРѕРЅСѓ РІРЅРµРґСЂРµРЅРёСЏ RFC v1 РґР»СЏ `lottery_multi` Рё СЃРІСЏР·С‹РІР°РµС‚ СЂРµР°Р»РёР·РѕРІР°РЅРЅС‹Рµ РјРµС…Р°РЅРёРєРё СЃ РєРѕРЅС‚СЂР°РєС‚РЅС‹РјРё
РјРѕРґСѓР»СЏРјРё, С‚РµСЃС‚Р°РјРё Рё РѕРїРµСЂР°С†РёРѕРЅРЅС‹РјРё РїСЂРѕС†РµРґСѓСЂР°РјРё. РСЃРїРѕР»СЊР·СѓР№С‚Рµ СЌС‚РѕС‚ С„Р°Р№Р» РєР°Рє РґРѕРїРѕР»РЅРµРЅРёРµ Рє [РѕСЃРЅРѕРІРЅРѕРјСѓ РѕРїРёСЃР°РЅРёСЋ РїР°РєРµС‚Р°](lottery_multi.md)
Рё РѕРїРµСЂР°С†РёРѕРЅРЅС‹Рј runbookвЂ™Р°Рј.

## Р­С‚Р°Рї 3. РџСЂРѕРґР°Р¶Рё, СЌРєРѕРЅРѕРјРёРєР° Рё РІС‹РїР»Р°С‚С‹

### РћСЃРЅРѕРІРЅС‹Рµ РјРѕРґСѓР»Рё
- `sales` вЂ” РїСЂРѕРґР°Р¶Рё Р±РёР»РµС‚РѕРІ СЃ Р°РЅС‚Рё-DoS Р·Р°С‰РёС‚РѕР№ (`block`, `window`, `grace`). РЎРѕР±С‹С‚РёСЏ `TicketPurchaseEvent` Рё `PurchaseRateLimitHit`
  С„РѕСЂРјРёСЂСѓСЋС‚ РїРѕС‚РѕРє РјРѕРЅРёС‚РѕСЂРёРЅРіР°.
- `economics` вЂ” СЂР°СЃРїСЂРµРґРµР»РµРЅРёРµ РІС‹СЂСѓС‡РєРё, РєРѕРЅС‚СЂРѕР»СЊ Р»РёРјРёС‚РѕРІ Рё С‚РѕРєРµРЅР° РґР¶РµРєРїРѕС‚Р° С‡РµСЂРµР· `assert_distribution`, `record_prize_payout`,
  `record_operations_payout`.
- `payouts` вЂ” РІС‹С‡РёСЃР»РµРЅРёРµ Рё С„РёРєСЃР°С†РёСЏ РїРѕР±РµРґРёС‚РµР»РµР№, РїР°СЂС‚РЅС‘СЂСЃРєРёРµ РІС‹РїР»Р°С‚С‹, С„РёРЅР°Р»РёР·Р°С†РёСЏ Рё СЂРµС„Р°РЅРґС‹, СЃРѕР±С‹С‚РёСЏ `WinnerBatchComputed`,
  `PayoutBatchEvent`, `PartnerPayoutEvent`, `RefundBatchEvent`.
- `roles` вЂ” СѓРїСЂР°РІР»РµРЅРёРµ `PayoutBatchCap`, `PartnerPayoutCap`, РїСЂРµРјРёР°Р»СЊРЅС‹РјРё РїРѕРґРїРёСЃРєР°РјРё Рё РїР°СЂС‚РЅС‘СЂСЃРєРёРјРё С€Р°Р±Р»РѕРЅР°РјРё.

### РЎС†РµРЅР°СЂРёРё СЌРєСЃРїР»СѓР°С‚Р°С†РёРё
1. **Р—Р°РїСѓСЃРє РїСЂРѕРґР°Р¶.** РџРµСЂРµРґ Р°РєС‚РёРІР°С†РёРµР№ Р»РѕС‚РµСЂРµРё РѕРїРµСЂР°С‚РѕСЂ РїСЂРѕРІРµСЂСЏРµС‚ РєРѕРЅС„РёРіСѓСЂР°С†РёСЋ (`views::validate_config`) Рё Р»РёРјРёС‚С‹ РїСЂРѕРґР°Р¶.
   РђРЅС‚Рё-DoS РјРµС…Р°РЅРёРєРё РїРѕРєСЂС‹С‚С‹ С‚РµСЃС‚Р°РјРё `sales_tests::{block_rate_limit_triggers, window_rate_limit_triggers,
   grace_window_blocks_first_purchase}` вЂ” РїСЂРё РёС… СЃСЂР°Р±Р°С‚С‹РІР°РЅРёРё РѕР¶РёРґР°С‚СЊ `E_PURCHASE_RATE_LIMIT_BLOCK`, `E_PURCHASE_RATE_LIMIT_WINDOW`,
   `E_PURCHASE_GRACE_RESTRICTED` Рё С„РёРєСЃРёСЂРѕРІР°С‚СЊ РёРЅС†РёРґРµРЅС‚.
2. **РљРѕРЅС‚СЂРѕР»СЊ СЌРєРѕРЅРѕРјРёРєРё.** РџСЂРё РєР°Р¶РґРѕРј Р±Р°С‚С‡Рµ `payouts::record_payout_batch_admin` СЃРІРµСЂСЏСЋС‚СЃСЏ Р°РіСЂРµРіР°С‚С‹ `sales::accounting_snapshot`.
   Prover-СЃРїРµРєРё РІ `spec/economics.move` Рё `spec/payouts.move` РіР°СЂР°РЅС‚РёСЂСѓСЋС‚, С‡С‚Рѕ `allocated >= paid`, `payout_round` РІРѕР·СЂР°СЃС‚Р°РµС‚
   РјРѕРЅРѕС‚РѕРЅРЅРѕ, Р° С‚РѕРєРµРЅ РґР¶РµРєРїРѕС‚Р° РЅРµ РїРµСЂРµСЂР°СЃС…РѕРґСѓРµС‚СЃСЏ.
3. **РџР°СЂС‚РЅС‘СЂСЃРєРёРµ РІС‹РїР»Р°С‚С‹.** РџРµСЂРµРґ `record_partner_payout_admin` РѕРїРµСЂР°С‚РѕСЂ РїСЂРѕРІРµСЂСЏРµС‚ РѕСЃС‚Р°С‚РѕРє `PartnerPayoutCap` (`roles::list_partner_caps`).
   РћС‚РєР°Р· С„РёРєСЃРёСЂСѓРµС‚СЃСЏ РѕС€РёР±РєР°РјРё `E_PARTNER_PAYOUT_BUDGET_EXCEEDED`, `E_PARTNER_PAYOUT_COOLDOWN`, `E_PARTNER_PAYOUT_NONCE`,
   `E_PARTNER_PAYOUT_EXPIRED`. Р®РЅРёС‚ `payouts_tests::partner_payout_cannot_exceed_cap` РґРµРјРѕРЅСЃС‚СЂРёСЂСѓРµС‚ Р·Р°С‰РёС‚Сѓ РѕС‚ РїРµСЂРµСЂР°СЃС…РѕРґР°.
4. **Р¤РёРЅР°Р»РёР·Р°С†РёСЏ.** `payouts_tests::{finalize_requires_all_winners, finalize_records_summary}` РїРѕРґС‚РІРµСЂР¶РґР°СЋС‚ Р±Р»РѕРєРёСЂРѕРІРєСѓ, РїРѕРєР°
   РЅРµ РІС‹С‡РёСЃР»РµРЅС‹ РїРѕР±РµРґРёС‚РµР»Рё Рё РЅРµ Р·Р°РїРёСЃР°РЅР° СЃРІРѕРґРєР°. РџРѕСЃР»Рµ `finalize_lottery_admin` РІС‹Р·С‹РІР°РµС‚СЃСЏ `history::record_summary` Рё
   Р·Р°РїСѓСЃРєР°РµС‚СЃСЏ dual-write Р·РµСЂРєР°Р»Рѕ.
5. **VRF Рё РїРѕРІС‚РѕСЂРЅС‹Рµ Р·Р°РїСЂРѕСЃС‹.** `draw::request_draw_admin` РёСЃРїРѕР»СЊР·СѓРµС‚ retry-СЃС‚СЂР°С‚РµРіРёСЋ СЃ С‚Р°Р№РјР»РѕРєР°РјРё. РўРµСЃС‚С‹ `draw_tests`
   РїСЂРѕРІРµСЂСЏСЋС‚ РѕРєРЅР° retry (`E_VRF_RETRY_WINDOW`), Р·Р°С‰РёС‚Сѓ РѕС‚ РїРµСЂРµРїРѕР»РЅРµРЅРёСЏ `attempt` Рё С„РѕСЂРјРёСЂРѕРІР°РЅРёРµ `finalization_snapshot`.
6. **AutomationBot.** Dry-run РѕР±СЏР·Р°С‚РµР»РµРЅ (`automation_tests::record_success_requires_pending`), Р»РёРјРёС‚С‹ `max_failures`
   РєРѕРЅС‚СЂРѕР»РёСЂСѓСЋС‚СЃСЏ С‚РµСЃС‚Р°РјРё `ensure_action_blocks_after_failure_limit`, `record_success_resets_failure_limit`. РџСѓР±Р»РёС‡РЅС‹Рµ
   view `lottery_engine::automation::registry_snapshot`/`lottery_engine::automation::bot_status` РІРѕР·РІСЂР°С‰Р°СЋС‚ СЃРѕСЃС‚РѕСЏРЅРёРµ Р±РѕС‚Р° РґР»СЏ РѕРїРµСЂР°С‚РѕСЂРѕРІ Рё РїРѕРєСЂС‹С‚С‹ С‚РµСЃС‚РѕРј
   `views_tests::automation_views_list_registered_bot`.

### РћРїРµСЂР°С†РёРѕРЅРЅС‹Рµ Р°СЂС‚РµС„Р°РєС‚С‹
- Runbook: СЂР°Р·РґРµР»С‹ В«РђРґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂВ», В«AutomationBotВ», В«Dual-write РјРёРіСЂР°С†РёСЏВ» РІ [operations/runbooks.md](../operations/runbooks.md).
- РњРѕРЅРёС‚РѕСЂРёРЅРі: РјРµС‚СЂРёРєРё `status_overview`, `payout_round_gap`, `automation_failure_count`, `price_feed_*` Рё РЅРѕРІС‹Рµ view
  `lottery_engine::automation::registry_snapshot`/`lottery_engine::automation::bot_status` описаны в [operations/monitoring.md](../operations/monitoring.md).
- Р§РµРє-Р»РёСЃС‚ СЂРµР»РёР·Р°: СЃРµРєС†РёРё В«РџСЂРѕРґР°Р¶Рё Рё РІС‹РїР»Р°С‚С‹В», В«AutomationBotВ», В«РџСЂР°Р№СЃ-С„РёРґВ» РІ [operations/release_checklist.md](../operations/release_checklist.md).

## Р­С‚Р°Рї 4. РњРёРіСЂР°С†РёРё Рё backfill

### РћСЃРЅРѕРІРЅС‹Рµ РјРѕРґСѓР»Рё
- `history` вЂ” РёРјРїРѕСЂС‚ Рё РѕС‚РєР°С‚ legacy-СЃРІРѕРґРѕРє (`import_legacy_summary_admin`, `rollback_legacy_summary_admin`,
  `update_legacy_classification_admin`), СЃРѕР±С‹С‚РёСЏ `LegacySummaryImportedEvent`, `LegacySummaryRolledBackEvent`,
  `LegacySummaryClassificationUpdatedEvent`.
- `legacy_bridge` вЂ” СѓРїСЂР°РІР»РµРЅРёРµ dual-write (`set_expected_hash`, `clear_expected_hash`, `mirror_summary_admin`, `pending_expected_hashes`).
- РЎРєСЂРёРїС‚С‹ `SupraLottery/supra/scripts/history_backfill.sh`, `SupraLottery/supra/scripts/dual_write_control.sh` Рё Python-СѓС‚РёР»РёС‚Р° `supra.tools.history_backfill_dry_run`.

### РЎС†РµРЅР°СЂРёРё СЌРєСЃРїР»СѓР°С‚Р°С†РёРё
1. **РџРѕРґРіРѕС‚РѕРІРєР° РґР°РЅРЅС‹С….** `history_backfill.sh dry-run` СЂР°СЃСЃС‡РёС‚С‹РІР°РµС‚ `sha3-256` Рё hex-РїСЂРµРґСЃС‚Р°РІР»РµРЅРёРµ BCS СЃРІРѕРґРєРё.
   РўРµСЃС‚ `tests/test_history_backfill_dry_run.py` РіР°СЂР°РЅС‚РёСЂСѓРµС‚ РєРѕСЂСЂРµРєС‚РЅРѕСЃС‚СЊ СЂР°СЃС‡С‘С‚РѕРІ Рё С„РѕСЂРјРёСЂРѕРІР°РЅРёСЏ РіРѕС‚РѕРІРѕР№ РєРѕРјР°РЅРґС‹ `import`.
2. **РРјРїРѕСЂС‚ legacy.** `history_migration_tests::imports_summary_successfully` РїРѕРґС‚РІРµСЂР¶РґР°РµС‚ СѓСЃРїРµС€РЅСѓСЋ Р·Р°РїРёСЃСЊ Рё СЃРѕР±С‹С‚РёРµ
   `LegacySummaryImportedEvent`. РџСЂРё СЂР°СЃС…РѕР¶РґРµРЅРёРё С…СЌС€Р° `history_migration_tests::import_rejects_wrong_hash` Р»РѕРІРёС‚
   `E_HISTORY_HASH_MISMATCH`.
3. **РћС‚РєР°С‚ Рё РєР»Р°СЃСЃРёС„РёРєР°С‚РѕСЂС‹.** Р¤СѓРЅРєС†РёСЏ `rollback_legacy_summary_admin` РґРѕСЃС‚СѓРїРЅР° С‚РѕР»СЊРєРѕ РґР»СЏ legacy-Р·Р°РїРёСЃРµР№ вЂ” РѕС‚РєР°Р· РїРѕРєСЂС‹С‚ С‚РµСЃС‚РѕРј
   `history_migration_tests::cannot_rollback_new_summary`. РљРѕРјР°РЅРґР° `classify` РѕР±РЅРѕРІР»СЏРµС‚ `primary_type` Рё `tags_mask`,
   РїСѓР±Р»РёРєСѓСЏ `LegacySummaryClassificationUpdatedEvent`.
4. **Dual-write РѕР¶РёРґР°РЅРёСЏ.** РЎРїРёСЃРѕРє Р°РєС‚РёРІРЅС‹С… РѕР¶РёРґР°РЅРёР№ РґРѕСЃС‚СѓРїРµРЅ С‡РµСЂРµР· `legacy_bridge::pending_expected_hashes` Рё РѕРґРЅРѕРёРјС‘РЅРЅСѓСЋ
   РєРѕРјР°РЅРґСѓ СЃРєСЂРёРїС‚Р°. РўРµСЃС‚ `history_dual_write_tests::dual_write_pending_list` РїРѕРєР°Р·С‹РІР°РµС‚, С‡С‚Рѕ Р»РѕС‚РµСЂРµСЏ РёСЃС‡РµР·Р°РµС‚ РёР· СЃРїРёСЃРєР°
   РїРѕСЃР»Рµ `notify_summary_written`. РџСЂРё СЂР°Р·СЂРµС€С‘РЅРЅРѕРј mismatched-Р±Р°С‚С‡Рµ `dual_write_mismatch_requires_manual_clear` РїРѕРґС‚РІРµСЂР¶РґР°РµС‚,
   С‡С‚Рѕ С‚СЂРµР±СѓРµС‚СЃСЏ СЂСѓС‡РЅРѕР№ `clear_expected_hash`.
5. **Р”РѕРєСѓРјРµРЅС‚Р°С†РёСЏ РѕРїРµСЂР°С†РёР№.** Runbook Рё РјРѕРЅРёС‚РѕСЂРёРЅРі РІРєР»СЋС‡Р°СЋС‚ С€Р°РіРё РґР»СЏ dry-run, РёРјРїРѕСЂС‚Р°, РїСЂРѕРІРµСЂРєРё Р°Р»С‘СЂС‚РѕРІ `dual_write_pending`
   Рё Р·Р°РїРѕР»РЅРµРЅРёСЏ Р¶СѓСЂРЅР°Р»Р° РёРЅС†РёРґРµРЅС‚РѕРІ.

### РћРїРµСЂР°С†РёРѕРЅРЅС‹Рµ Р°СЂС‚РµС„Р°РєС‚С‹
- Runbook: СЂР°Р·РґРµР»С‹ В«Dual-write РјРёРіСЂР°С†РёСЏВ» Рё В«РђРґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂВ» РІ [operations/runbooks.md](../operations/runbooks.md).
- РњРѕРЅРёС‚РѕСЂРёРЅРі: С‚Р°Р±Р»РёС†Р° РјРµС‚СЂРёРє `dual_write_*` РІ [operations/monitoring.md](../operations/monitoring.md).
- РЎС‚Р°С‚СѓСЃРЅР°СЏ СЃС‚СЂР°РЅРёС†Р°: РїРѕРєР°Р·Р°С‚РµР»Рё `status_overview.pending_dual_write` Рё `status_overview.vrf_retry_blocked` РѕРїРёСЃР°РЅС‹ РІ
  [operations/status_page.md](../operations/status_page.md).

## Р­С‚Р°Рї 5. РђРґРјРёРЅРёСЃС‚СЂРёСЂСѓРµРјС‹Р№ Р·Р°РїСѓСЃРє

### РћСЃРЅРѕРІРЅС‹Рµ РјРѕРґСѓР»Рё Рё РјРµС…Р°РЅРёРєРё
- `roles` вЂ” СЂР°СЃС€РёСЂРµРЅРЅС‹Р№ `RoleStore`, СЃРѕР±С‹С‚РёСЏ РІС‹РґР°С‡Рё/РѕС‚Р·С‹РІР°, Р»РёСЃС‚РёРЅРіРё `list_partner_caps`, `list_premium_caps`, `event_counters`,
  `cleanup_expired_admin`.
- `automation` вЂ” РїСЂРѕС†РµРґСѓСЂС‹ dry-run, С‚Р°Р№РјР»РѕРєРё, РєРѕРЅС‚СЂРѕР»СЊ `max_failures` Рё СЃРѕР±С‹С‚РёР№ `AutomationTick`/`AutomationError`.
- `price_feed` вЂ” СЂСѓС‡РЅРѕР№ РєР»Р°РјРї, fallback Рё РІРѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёРµ (`clear_clamp`), СЃРѕР±С‹С‚РёСЏ `PriceFeedClampEvent`, `PriceFeedClampClearedEvent`.
- `views::status_overview` Рё `lottery_engine::automation::registry_snapshot` вЂ” Р°РіСЂРµРіРёСЂРѕРІР°РЅРЅС‹Рµ СЃС‡С‘С‚С‡РёРєРё СЃС‚Р°С‚СѓСЃРѕРІ, retry-РѕРєРѕРЅ, Р±СЌРєР»РѕРіР° РІС‹РїР»Р°С‚ Рё С‚РµРєСѓС‰РµРµ СЃРѕСЃС‚РѕСЏРЅРёРµ AutomationBot; РґР»СЏ СЂСѓС‡РЅС‹С… РїСЂРѕРІРµСЂРѕРє Рё РїРѕРґРіРѕС‚РѕРІРєРё РѕС‚С‡С‘С‚РѕРІ РёСЃРїРѕР»СЊР·СѓР№С‚Рµ CLI `./SupraLottery/supra/scripts/automation_status.sh`.
- CLI `SupraLottery/supra/scripts/incident_log.sh` вЂ” Р°РІС‚РѕРјР°С‚РёР·Р°С†РёСЏ Р¶СѓСЂРЅР°Р»РёСЂРѕРІР°РЅРёСЏ СЂРµС€РµРЅРёР№.
- `registry::cancel_lottery_admin` вЂ” РїРµСЂРµРІРѕРґ СЂРѕР·С‹РіСЂС‹С€Р° РІ `STATUS_CANCELED`, СЃРѕС…СЂР°РЅРµРЅРёРµ `CancellationRecord` Рё СЌРјРёСЃСЃРёСЏ `LotteryCanceledEvent`.

### РЎС†РµРЅР°СЂРёРё СЌРєСЃРїР»СѓР°С‚Р°С†РёРё
1. **РЈРїСЂР°РІР»РµРЅРёРµ СЂРѕР»СЏРјРё.** РђРґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂ РІС‹РґР°С‘С‚ РєР°РїР°Р±РёР»РёС‚Рё С‡РµСЂРµР· `roles::set_payout_batch_cap_admin`, `roles::upsert_partner_payout_cap_admin`,
   `roles::grant_premium_access_admin`. РўРµСЃС‚С‹ `roles_tests::{admin_can_list_and_track_partner_caps, cleanup_expired_removes_caps,
   premium_grant_and_revoke_updates_events}` РїРѕРґС‚РІРµСЂР¶РґР°СЋС‚ СЃРѕР±С‹С‚РёСЏ Рё Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєРёР№ РєР»РёРЅР°Рї.
2. **AutomationBot.** РљР°Р¶РґС‹Р№ dry-run Р·Р°РЅРѕСЃРёС‚СЃСЏ РІ Р¶СѓСЂРЅР°Р» С‡РµСЂРµР· `incident_log.sh --type "Dry-run"`. РџСЂРё РґРѕСЃС‚РёР¶РµРЅРёРё Р»РёРјРёС‚Р° РѕС‚РєР°Р·РѕРІ
   (`E_AUTOBOT_FAILURE_LIMIT`) РѕРїРµСЂР°С‚РѕСЂ РґРѕР»Р¶РµРЅ РІС‹РїРѕР»РЅРёС‚СЊ `rotate_bot` Рё РѕР±РЅРѕРІРёС‚СЊ cron-СЃРїРµРєСѓ. Runbook РѕРїРёСЃС‹РІР°РµС‚ С„РѕСЂРјР°С‚ Р·Р°РїРёСЃРё,
   РѕР±СЏР·Р°С‚РµР»СЊРЅСѓСЋ РїСЂРѕРІРµСЂРєСѓ `ensure_action` РїРµСЂРµРґ РІС‹Р·РѕРІРѕРј on-chain РѕРїРµСЂР°С†РёР№ Рё РёСЃРїРѕР»СЊР·РѕРІР°РЅРёРµ view `lottery_engine::automation::registry_snapshot`
   РґР»СЏ РєРѕРЅС‚СЂРѕР»СЏ pending-РґРµР№СЃС‚РІРёР№ Рё С‚Р°Р№РјР»РѕРєРѕРІ.
3. **РџСЂР°Р№СЃ-С„РёРґ.** РџСЂРё СЂРµР·РєРёС… СЃРєР°С‡РєР°С… С†РµРЅС‹ Р°РєС‚РёРІРёСЂСѓРµС‚СЃСЏ fallback/РєР»Р°РјРї. РўРµСЃС‚С‹ `price_feed_tests::{fallback_blocks_consumers,
   clamp_blocks_latest_price, clear_clamp_allows_recovery}` Рё Prover-СЃРїРµРєР° `spec/price_feed.move` РіР°СЂР°РЅС‚РёСЂСѓСЋС‚ РїРѕРІРµРґРµРЅРёРµ.
   РџРѕСЃР»Рµ СЂСѓС‡РЅРѕРіРѕ `clear_clamp` РѕР±СЏР·Р°С‚РµР»СЊРЅРѕ РѕР±РЅРѕРІРёС‚СЊ РјРѕРЅРёС‚РѕСЂРёРЅРі Рё Р¶СѓСЂРЅР°Р».
4. **РЎС‚Р°С‚СѓСЃРЅР°СЏ СЃС‚СЂР°РЅРёС†Р°.** `status_overview` Р°РіСЂРµРіРёСЂСѓРµС‚ СЃС‚Р°С‚СѓСЃС‹ СЂРѕР·С‹РіСЂС‹С€РµР№, retry-РѕРєРЅР° VRF, Р±СЌРєР»РѕРі РІС‹РїР»Р°С‚ Рё РѕСЃС‚Р°С‚РѕРє dual-write.
   React Query-С…СѓРє `features/dashboard/hooks/useLotteryMultiViews` Рё РєРѕРјРїРѕРЅРµРЅС‚ `components/Dashboard.tsx` РѕС‚РѕР±СЂР°Р¶Р°СЋС‚ Р°РєС‚РёРІРЅС‹Рµ
   СЂРѕР·С‹РіСЂС‹С€Рё, Р±Р»РѕРєРёСЂРѕРІРєРё VRF Рё РѕС‡РµСЂРµРґСЊ РІС‹РїР»Р°С‚. РџСЂРёРјРµСЂ РѕС‚РІРµС‚РѕРІ Рё JSON Schema РІР°Р»РёРґРёСЂСѓСЋС‚СЃСЏ С‚РµСЃС‚РѕРј
   `SupraLottery/tests/test_view_schema_examples.py`. Р СѓРєРѕРІРѕРґСЃС‚РІРѕ РїРѕ РїСѓР±Р»РёРєР°С†РёРё РіСЂР°С„РёРєРѕРІ СЃРј. РІ
   [operations/status_page.md](../operations/status_page.md).
5. **РРЅС†РёРґРµРЅС‚РЅС‹Р№ Р¶СѓСЂРЅР°Р».** РРЅСЃС‚СЂСѓРјРµРЅС‚ `supra/tools/incident_log.py` РѕР±РµСЃРїРµС‡РёРІР°РµС‚ СЃРѕСЂС‚РёСЂРѕРІРєСѓ РїРѕ СѓР±С‹РІР°РЅРёСЋ РґР°С‚С‹ Рё СѓРґР°Р»СЏРµС‚ С€Р°Р±Р»РѕРЅРЅС‹Рµ
   Р·Р°РіРѕР»РѕРІРєРё. РўРµСЃС‚ `tests/test_incident_log_tool.py` РїРѕРґС‚РІРµСЂР¶РґР°РµС‚ РєРѕСЂСЂРµРєС‚РЅРѕСЃС‚СЊ CLI. РСЃРїРѕР»СЊР·СѓР№С‚Рµ РµРіРѕ РґР»СЏ РїСЂРѕС‚РѕРєРѕР»РёСЂРѕРІР°РЅРёСЏ dry-run,
   СЂСѓС‡РЅС‹С… РІС‹РїР»Р°С‚, РєР»Р°РјРїРѕРІ РїСЂР°Р№СЃ-С„РёРґР° Рё РѕР±РЅРѕРІР»РµРЅРёР№ СЂРѕР»РµР№.
6. **РћС‚РјРµРЅР° С‚РёСЂР°Р¶Р°.** Р РµС€РµРЅРёРµ С„РёРєСЃРёСЂСѓРµС‚СЃСЏ С‡РµСЂРµР· `registry::cancel_lottery_admin(lottery_id, reason_code, now_ts)`, РїРѕСЃР»Рµ С‡РµРіРѕ
   РїСЂРѕРІРµСЂСЏРµС‚СЃСЏ `views::get_cancellation`. РўРµСЃС‚С‹ `config_tests::{cancel_requires_reason, cancel_records_reason}` РїРѕРґС‚РІРµСЂР¶РґР°СЋС‚
   РїСЂРѕРІРµСЂРєСѓ РєРѕРґР° Рё СЃРѕС…СЂР°РЅРµРЅРёРµ Р°РіСЂРµРіР°С‚РѕРІ, Р° `views_tests::cancellation_and_refund_views` вЂ” РґРѕСЃС‚СѓРїРЅРѕСЃС‚СЊ РґР°РЅРЅС‹С… РІРѕ view. РџРѕСЃР»Рµ РѕС‚РјРµРЅС‹
   Р·Р°РїСѓСЃРєР°СЋС‚СЃСЏ on-chain СЂРµС„Р°РЅРґС‹ `payouts::force_refund_batch_admin` (РєРѕРЅС‚СЂРѕР»СЊ `refund_round`, `tickets_refunded`, `RefundBatchEvent`)
   Рё РјРѕРЅРёС‚РѕСЂРёРЅРі `views::get_refund_progress`. Р—Р°РІРµСЂС€РµРЅРёРµ РїСЂРѕС†РµРґСѓСЂС‹ С„РёРєСЃРёСЂСѓРµС‚СЃСЏ РІС‹Р·РѕРІРѕРј `payouts::archive_canceled_lottery_admin`,
   РєРѕС‚РѕСЂС‹Р№ РїСЂРѕРІРµСЂСЏРµС‚ РїРѕР»РЅРѕС‚Сѓ РІРѕР·РІСЂР°С‚РѕРІ Рё Р·Р°РїРёСЃС‹РІР°РµС‚ `LotterySummary` СЃРѕ СЃС‚Р°С‚СѓСЃРѕРј `STATUS_CANCELED`; РїРѕРєСЂС‹С‚РёРµ РѕР±РµСЃРїРµС‡РёРІР°СЋС‚ С‚РµСЃС‚С‹
   `payouts_tests::{archive_canceled_requires_record, archive_canceled_requires_full_refund, archive_canceled_records_summary}`.
   Runbook [operations/refund.md](../operations/refund.md) РѕРїРёСЃС‹РІР°РµС‚ РІС‹Р±РѕСЂ `CANCEL_REASON_*`, С‚СЂРµР±РѕРІР°РЅРёСЏ Рє Р¶СѓСЂРЅР°Р»РёСЂРѕРІР°РЅРёСЋ, С‡РµРє-Р»РёСЃС‚
   Р±Р°С‚С‡РµР№ Рё С€Р°Рі Р°СЂС…РёРІРёСЂРѕРІР°РЅРёСЏ, Р° CLI `SupraLottery/supra/scripts/refund_control.sh` РѕР±РѕСЂР°С‡РёРІР°РµС‚ СЃС†РµРЅР°СЂРёРё `cancel`, `batch`, `progress`, `summary`, `archive`.

### РћРїРµСЂР°С†РёРѕРЅРЅС‹Рµ Р°СЂС‚РµС„Р°РєС‚С‹
- Release checklist: СЂР°Р·РґРµР»С‹ В«Р РѕР»Рё Рё РґРѕСЃС‚СѓРїС‹В», В«AutomationBotВ», В«РџСЂР°Р№СЃ-С„РёРґВ», В«Р–СѓСЂРЅР°Р» РѕРїРµСЂР°С†РёР№В».
- РњРѕРЅРёС‚РѕСЂРёРЅРі: РјРµС‚СЂРёРєРё `automation_failure_count`, `price_feed_*`, `status_overview.*`.
- Bug bounty Рё РїРѕРґРґРµСЂР¶РєР°: [operations/bug_bounty.md](../operations/bug_bounty.md) Рё [support/sla.md](../support/sla.md).

## Р­С‚Р°Рї 6. РџРѕСЃС‚СЂРµР»РёР·РЅР°СЏ РїРѕРґРґРµСЂР¶РєР°

### РћСЃРЅРѕРІРЅС‹Рµ Р·Р°РґР°С‡Рё
- РџРѕРґРґРµСЂР¶Р°РЅРёРµ РЅР°Р±Р»СЋРґР°РµРјРѕСЃС‚Рё: Р°РєС‚СѓР°Р»РёР·Р°С†РёСЏ РґР°С€Р±РѕСЂРґРѕРІ, Р°Р»С‘СЂС‚РѕРІ Рё СЃС‚Р°С‚СѓСЃР° РіРѕС‚РѕРІРЅРѕСЃС‚Рё (`docs/architecture/lottery_multi_readiness_review.md`).
- Р РµРіСѓР»СЏСЂРЅС‹Рµ СЂРµС‚СЂРѕСЃРїРµРєС‚РёРІС‹ РїРѕ AutomationBot Рё dual-write, РѕР±РЅРѕРІР»РµРЅРёРµ РїСЂРѕС†РµРґСѓСЂ РІ `operations/runbooks.md`, `operations/refund.md` Рё `incident_log.md`.
- РџРѕРґРіРѕС‚РѕРІРєР° Рє РїРµСЂРµС…РѕРґСѓ РЅР° on-chain governance (СЃРј. `docs/architecture/lottery_parallel_plan.md`).
- РђРєС‚СѓР°Р»РёР·Р°С†РёСЏ РїРѕР»СЊР·РѕРІР°С‚РµР»СЊСЃРєРѕР№ Рё РїР°СЂС‚РЅС‘СЂСЃРєРѕР№ РґРѕРєСѓРјРµРЅС‚Р°С†РёРё, РІРєР»СЋС‡Р°СЏ FAQ Рё С„СЂРѕРЅС‚РµРЅРґ-РіР°Р№РґС‹, a11y-РїР»РµР№Р±СѓРє (`frontend/a11y.md`) Рё СЂР°Р·РґРµР» РєРѕРјРїР»Р°РµРЅСЃР° (`governance/compliance.md`).
- РџРѕСЃС‚СЂРµР»РёР·РЅС‹Рµ Р°РєС‚РёРІРЅРѕСЃС‚Рё РґРѕРєСѓРјРµРЅС‚РёСЂСѓСЋС‚СЃСЏ РІ [operations/post_release_support.md](../operations/post_release_support.md), Р° РѕС‚С‡С‘С‚С‹ Рё СЂРµС‚СЂРѕСЃРїРµРєС‚РёРІС‹ Р·Р°РЅРѕСЃСЏС‚СЃСЏ РІ [operations/postmortems.md](../operations/postmortems.md) РІ С‚РµС‡РµРЅРёРµ 24 С‡Р°СЃРѕРІ РїРѕСЃР»Рµ СЃРѕР±С‹С‚РёСЏ.

### РњРµС‚СЂРёРєРё Р·СЂРµР»РѕСЃС‚Рё
- В«Р—РµР»С‘РЅС‹Р№В» СЃС‚Р°С‚СѓСЃ РІСЃРµС… Р°Р»С‘СЂС‚РѕРІ РІ Grafana/Alertmanager.
- SLA РїРѕ РѕР±СЂР°Р±РѕС‚РєРµ РёРЅС†РёРґРµРЅС‚РѕРІ в‰¤ 24 С‡Р°СЃРѕРІ РґР»СЏ РІС‹СЃРѕРєРёС… РїСЂРёРѕСЂРёС‚РµС‚РѕРІ, в‰¤ 72 С‡Р°СЃРѕРІ РґР»СЏ СЃСЂРµРґРЅРёС….
- Zero mismatches РІ dual-write > 7 РґРЅРµР№ РїРѕРґСЂСЏРґ РёР»Рё РґРѕРєСѓРјРµРЅС‚РёСЂРѕРІР°РЅРЅР°СЏ РїСЂРѕС†РµРґСѓСЂР° Р°РЅР°Р»РёР·Р° РѕС‚РєР»РѕРЅРµРЅРёР№.
- РћР±РЅРѕРІР»С‘РЅРЅС‹Рµ РїСЂРёРјРµСЂС‹ API Рё JSON Schema РїРѕСЃР»Рµ РєР°Р¶РґРѕРіРѕ СЂРµР»РёР·Р°.

### Р РµРєРѕРјРµРЅРґР°С†РёРё
- Р•Р¶РµРјРµСЃСЏС‡РЅРѕ СЃРІРµСЂСЏС‚СЊ РґРѕРєСѓРјРµРЅС‚Р°С†РёСЋ СЃ С„Р°РєС‚РёС‡РµСЃРєРёРјРё Prover-СЃРїРµРєР°РјРё Рё СЋРЅРёС‚-С‚РµСЃС‚Р°РјРё.
- РџРѕРґРґРµСЂР¶РёРІР°С‚СЊ СЃРёРЅС…СЂРѕРЅРёР·Р°С†РёСЋ РјРµР¶РґСѓ `docs/handbook/contracts/` Рё `docs/architecture/` вЂ” Р»СЋР±С‹Рµ РёР·РјРµРЅРµРЅРёСЏ РІ РєРѕРґРµ РґРѕР»Р¶РЅС‹ СЃРѕРїСЂРѕРІРѕР¶РґР°С‚СЊСЃСЏ
  РѕР±РЅРѕРІР»РµРЅРёРµРј РѕР±РѕРёС… РЅР°Р±РѕСЂРѕРІ РґРѕРєСѓРјРµРЅС‚РѕРІ.
- РСЃРїРѕР»СЊР·РѕРІР°С‚СЊ `incident_log.sh` РґР»СЏ РїСѓР±Р»РёРєР°С†РёРё РѕС‚С‡С‘С‚РѕРІ Рѕ СЂРµС‚СЂРѕСЃРїРµРєС‚РёРІР°С… Рё СЂРµР·СѓР»СЊС‚Р°С‚Р°С… Р±Р°Рі-Р±Р°СѓРЅС‚Рё.

## РќР°РІРёРіР°С†РёСЏ
- РљРѕРЅС‚СЂР°РєС‚РЅС‹Рµ РґРµС‚Р°Р»Рё: [lottery_multi.md](lottery_multi.md)
- РђСЂС…РёС‚РµРєС‚СѓСЂР°: [../architecture/overview.md](../architecture/overview.md)
- РџР»Р°РЅ СЌС‚Р°РїРѕРІ: [../../architecture/lottery_parallel_plan.md](../../architecture/lottery_parallel_plan.md)
- РћРїРµСЂР°С†РёРё: [../operations/runbooks.md](../operations/runbooks.md), [../operations/monitoring.md](../operations/monitoring.md),
  [../operations/status_page.md](../operations/status_page.md), [../operations/post_release_support.md](../operations/post_release_support.md), [../operations/postmortems.md](../operations/postmortems.md)
- РРЅСЃС‚СЂСѓРјРµРЅС‚С‹ CLI: `SupraLottery/supra/scripts/history_backfill.sh`, `SupraLottery/supra/scripts/dual_write_control.sh`, `SupraLottery/supra/scripts/incident_log.sh`, `SupraLottery/supra/scripts/refund_control.sh`


