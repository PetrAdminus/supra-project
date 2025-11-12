# РњРѕРЅРёС‚РѕСЂРёРЅРі lottery_multi

## 1. РћР±С‰РёРµ РїСЂРёРЅС†РёРїС‹
- Р’СЃРµ РјРµС‚СЂРёРєРё РїРѕРїР°РґР°СЋС‚ РІ Grafana-РґСЌС€Р±РѕСЂРґ `Lottery Multi Ops` (UID: lottery-multi-ops).
- РђР»С‘СЂС‚С‹ РЅР°СЃС‚СЂР°РёРІР°СЋС‚СЃСЏ С‡РµСЂРµР· Alertmanager, РѕС‚РІРµС‚СЃС‚РІРµРЅРЅС‹Р№ РєР°РЅР°Р» вЂ” `#lottery-ops`.
- РСЃС‚РѕС‡РЅРёРєРё: on-chain СЃРѕР±С‹С‚РёСЏ (С‡РµСЂРµР· РёРЅРґРµРєСЃР°С‚РѕСЂ), Supra CLI (`supra monitor`), Prometheus-СЌРєСЃРїРѕСЂС‚РµСЂ AutomationBot.

## 2. РљР»СЋС‡РµРІС‹Рµ РјРµС‚СЂРёРєРё
| Р”РѕРјРµРЅС‹ | РњРµС‚СЂРёРєР° | РћРїРёСЃР°РЅРёРµ | РџРѕСЂРѕРі |
|--------|---------|----------|-------|
| VRF | `vrf_effective_balance` | РўРµРєСѓС‰РёР№ `effective_balance` РёР· `views::get_vrf_deposit_status` | < `required_minimum` |
| VRF | `vrf_requests_paused` | Р¤Р»Р°Рі РїСЂРёРѕСЃС‚Р°РЅРѕРІРєРё Р·Р°РїСЂРѕСЃРѕРІ | `true` > 5 РјРёРЅ |
| Dual-write | `dual_write_mismatch` | РљРѕР»РёС‡РµСЃС‚РІРѕ Р»РѕС‚РµСЂРµР№ СЃ `expected_hash` Рё `actual_hash` != | > 0 |
| Dual-write | `dual_write_pending` | Р›РѕС‚РµСЂРµРё РІ СЃС‚Р°С‚СѓСЃРµ РѕР¶РёРґР°РЅРёСЏ Р±РѕР»РµРµ 2 С‡Р°СЃРѕРІ | > 0 |
| Status | `status_overview.vrf_retry_blocked` | РљРѕР»РёС‡РµСЃС‚РІРѕ Р»РѕС‚РµСЂРµР№, Р·Р°Р±Р»РѕРєРёСЂРѕРІР°РЅРЅС‹С… РѕРєРЅРѕРј РїРѕРІС‚РѕСЂРЅРѕРіРѕ VRF | > 0 РґРѕР»СЊС€Рµ 60 РјРёРЅ |
| Status | `status_overview.payout_backlog` | РќРµРІС‹РїР»Р°С‡РµРЅРЅС‹Рµ Р±Р°С‚С‡Рё (`payout_round < next_winner_batch_no`) | > 0 РґРѕР»СЊС€Рµ 60 РјРёРЅ |
| Status | `status_overview.canceled` | РљРѕР»РёС‡РµСЃС‚РІРѕ РѕС‚РјРµРЅС‘РЅРЅС‹С… Р»РѕС‚РµСЂРµР№ (РІ С‚.С‡. Р°РІС‚Рѕ-РѕС‚РјРµРЅС‹ РїРѕСЃР»Рµ `MAX_VRF_ATTEMPTS`) | > 0 Р±РµР· Р°РєС‚РёРІРЅРѕРіРѕ РїР»Р°РЅР° СЂРµС„Р°РЅРґР° |
| РџР»Р°С‚РµР¶Рё | `payout_round_gap` | `next_winner_batch_no - payout_round` | > 1 |
| РџР»Р°С‚РµР¶Рё | `operations_budget_remaining` | РћСЃС‚Р°С‚РѕРє РѕРїРµСЂР°С†РёР№ РїРѕ `PayoutBatchCap` | < 10% |
| Automation | `automation_failure_count` | РЎС‡С‘С‚С‡РёРє РїСЂРѕРІР°Р»РѕРІ РїРѕРґСЂСЏРґ | >= `max_failures` |
| Automation | `automation_pending_age` | Р’СЂРµРјСЏ СЃ РјРѕРјРµРЅС‚Р° `AutomationDryRunPlanned` | > `timelock_secs + 15 РјРёРЅ` |
| Automation | `automation_timelock_breach` | РљРѕР»РёС‡РµСЃС‚РІРѕ Р±РѕС‚РѕРІ СЃ `ACTION_UNPAUSE`/`ACTION_PAYOUT_BATCH`/`ACTION_CANCEL` Рё С‚Р°Р№РјР»РѕРєРѕРј < 900 СЃРµРєСѓРЅРґ | > 0 |
| Refund | `refund_active` | РљРѕР»РёС‡РµСЃС‚РІРѕ РѕС‚РјРµРЅС‘РЅРЅС‹С… Р»РѕС‚РµСЂРµР№ СЃ Р°РєС‚РёРІРЅС‹Рј СЂРµС„Р°РЅРґРѕРј (РїРѕ view `status_overview`) | > 0 Р±РµР· Р·Р°РїСѓС‰РµРЅРЅРѕР№ РїСЂРѕС†РµРґСѓСЂС‹ |
| Refund | `refund_batch_pending` | РљРѕР»РёС‡РµСЃС‚РІРѕ РѕСЃС‚Р°РІС€РёС…СЃСЏ Р±РёР»РµС‚РѕРІ Рє РІРѕР·РІСЂР°С‚Сѓ (РїРѕ view `status_overview`) | > 0 РґРѕР»СЊС€Рµ 4 С‡Р°СЃРѕРІ |
| Refund | `refund_progress.round` | РўРµРєСѓС‰РµРµ Р·РЅР°С‡РµРЅРёРµ `refund_round` РёР· `views::get_refund_progress` | РќРµ СЂР°СЃС‚С‘С‚ > 60 РјРёРЅ РїСЂРё Р°РєС‚РёРІРЅРѕРј `refund_batch_pending` |
| Refund | `refund_progress.remaining` | `tickets_sold - tickets_refunded` РёР· `views::get_refund_progress` | > 0 СЃРїСѓСЃС‚СЏ 12 С‡Р°СЃРѕРІ РїРѕСЃР»Рµ РѕС‚РјРµРЅС‹ |
| Refund | `refund_progress.last_ts` | РњРµС‚РєР° `last_refund_ts` РёР· `views::get_refund_progress` | Р Р°Р·РЅРёС†Р° СЃ `now()` > 120 РјРёРЅ РїСЂРё Р°РєС‚РёРІРЅРѕРј СЂРµС„Р°РЅРґРµ |
| Refund | `refund_sla_breach` | Р¤Р»Р°Рі РЅР°СЂСѓС€РµРЅРёСЏ SLA РІРѕР·РІСЂР°С‚Р° (РїРµСЂРІС‹Р№ Р±Р°С‚С‡ > 12С‡ РёР»Рё Р·Р°РІРµСЂС€РµРЅРёРµ > 24С‡) | `true` |
| Р РѕР»Рё | `partner_cap_expiring` | РљРѕР»РёС‡РµСЃС‚РІРѕ `PartnerPayoutCap` СЃ `expires_at` < 24С‡ РёР»Рё `remaining_payout = 0` (РїРѕ `roles::list_partner_caps`) | > 0 |
| Р РѕР»Рё | `premium_cap_expiring` | РљРѕР»РёС‡РµСЃС‚РІРѕ `PremiumAccessCap` СЃ `expires_at` < 24С‡ (РїРѕ `roles::list_premium_caps`) | > 0 |
| РџСЂРѕРґР°Р¶Рё | `sales_rate` | Р‘РёР»РµС‚С‹/РјРёРЅ РїРѕ СЃРѕР±С‹С‚РёСЋ `TicketPurchaseEvent` | РћС‚РєР»РѕРЅРµРЅРёРµ > 3Пѓ |
| РџСЂР°Р№СЃ-С„РёРґ | `price_feed_updates_total` | РљРѕР»РёС‡РµСЃС‚РІРѕ СЃРѕР±С‹С‚РёР№ `PriceFeedUpdatedEvent` Р·Р° 1С‡ | < 1 (РґР»СЏ Р°РєС‚РёРІРЅС‹С… Р°РєС‚РёРІРѕРІ) |
| РџСЂР°Р№СЃ-С„РёРґ | `price_feed_clamp_active` | РљРѕР»РёС‡РµСЃС‚РІРѕ Р°РєС‚РёРІРЅС‹С… РєР»Р°РјРїРѕРІ (РїРѕ `price_feed::get_price_view`) | > 0 РґРѕР»СЊС€Рµ 5 РјРёРЅ |
| РџСЂР°Р№СЃ-С„РёРґ | `price_feed_fallback_active` | РљРѕР»РёС‡РµСЃС‚РІРѕ Р°РєС‚РёРІРЅС‹С… fallback | > 0 РґРѕР»СЊС€Рµ 5 РјРёРЅ |

## 3. РСЃС‚РѕС‡РЅРёРєРё РґР°РЅРЅС‹С…
- **On-chain СЃРѕР±С‹С‚РёСЏ:** РёРЅРґРµРєСЃР°С‚РѕСЂ `supra-indexer` РїСѓР±Р»РёРєСѓРµС‚ РІ Kafka (`topic: lottery_multi.events`).
- **AutomationBot Exporter:** `/metrics` endpoint СЃ `failure_count`, `pending_age`, `success_streak`.
- **Supra CLI:** `supra monitor dual-write --json` Рё `supra monitor vrf`.
- **Supra CLI (СѓС‡С‘С‚ РїСЂРѕРґР°Р¶):** `./SupraLottery/supra/scripts/accounting_check.sh <config> compare <lottery_id>` РІС‹РІРѕРґРёС‚ РѕС‚С‡С‘С‚ Рѕ СЃРѕРІРїР°РґРµРЅРёРё `total_*` РјРµР¶РґСѓ `sales::accounting_snapshot` Рё `LotterySummary`; РёСЃРїРѕР»СЊР·СѓР№С‚Рµ РґР»СЏ СЂСѓС‡РЅРѕРіРѕ РїРѕРґС‚РІРµСЂР¶РґРµРЅРёСЏ Р°РіСЂРµРіР°С‚РѕРІ РїСЂРё СЂР°СЃСЃР»РµРґРѕРІР°РЅРёСЏС… Р°РЅРѕРјР°Р»РёР№.
- **View `status_overview`:** РѕРїСЂРѕСЃ `lottery_multi::views::status_overview` (СЃРј. [status_page.md](status_page.md)) РєР°Р¶РґС‹Рµ 60 СЃРµРєСѓРЅРґ РґР»СЏ РІРЅСѓС‚СЂРµРЅРЅРёС… РїР°РЅРµР»РµР№ Рё РїСѓР±Р»РёРєР°С†РёРё СЃС‚Р°С‚СѓСЃРЅРѕР№ СЃС‚СЂР°РЅРёС†С‹.
- **View `get_refund_progress`:** РѕРїСЂРѕСЃ РїРѕ РІСЃРµРј РѕС‚РјРµРЅС‘РЅРЅС‹Рј Р»РѕС‚РµСЂРµСЏРј РєР°Р¶РґС‹Рµ 5 РјРёРЅСѓС‚. РњРµС‚СЂРёРєРё `refund_progress.round`, `refund_progress.remaining` Рё `refund_progress.last_ts` СЃС‚СЂРѕСЏС‚СЃСЏ РЅР° РѕСЃРЅРѕРІРµ СЌС‚РѕРіРѕ view, Р·РЅР°С‡РµРЅРёРµ `canceled_ts` Р±РµСЂС‘С‚СЃСЏ РёР· `views::get_cancellation`.
- **View `list_automation_bots`:** РїРµСЂРёРѕРґРёС‡РµСЃРєРёР№ РѕРїСЂРѕСЃ (РєР°Р¶РґС‹Рµ 60 СЃРµРєСѓРЅРґ РґР»СЏ РІРЅСѓС‚СЂРµРЅРЅРёС… РїР°РЅРµР»РµР№) РґР»СЏ РѕС‚РѕР±СЂР°Р¶РµРЅРёСЏ pending-РґРµР№СЃС‚РІРёР№, Р»РёРјРёС‚РѕРІ `max_failures` Рё С‚Р°Р№РјР»РѕРєРѕРІ AutomationBot; РїСЂРё СЂСѓС‡РЅС‹С… РїСЂРѕРІРµСЂРєР°С… РёСЃРїРѕР»СЊР·СѓР№С‚Рµ `./SupraLottery/supra/scripts/automation_status.sh <config> list|get` РґР»СЏ РѕРїРµСЂР°С‚РёРІРЅРѕРіРѕ СЃРЅРёРјРєР° С‡РµСЂРµР· Supra CLI. РќР° РѕСЃРЅРѕРІРµ СЌС‚РѕРіРѕ view СЂР°СЃСЃС‡РёС‚С‹РІР°РµС‚СЃСЏ РёРЅРґРёРєР°С‚РѕСЂ `automation_timelock_breach`, СЃСЂР°РІРЅРёРІР°СЋС‰РёР№ С‚Р°Р№РјР»РѕРє СЃ РїРѕСЂРѕРіРѕРј 900 СЃРµРєСѓРЅРґ РґР»СЏ С‡СѓРІСЃС‚РІРёС‚РµР»СЊРЅС‹С… РґРµР№СЃС‚РІРёР№.

## 4. РђР»РµСЂС‚С‹ Рё СЂРµР°РіРёСЂРѕРІР°РЅРёРµ
- `VrfDepositLow`: `effective_balance < required_minimum` в†’ СѓРІРµРґРѕРјР»РµРЅРёРµ DevOps, Р·Р°РїСѓСЃРє runbook VRF.
- `DualWriteMismatch`: СЂР°СЃС…РѕР¶РґРµРЅРёРµ С…СЌС€РµР№ > 10 РјРёРЅСѓС‚ в†’ Р±Р»РѕРєРёСЂРѕРІРєР° С„РёРЅР°Р»РёР·Р°С†РёРё, Р·Р°РїСѓСЃРє runbook dual-write.
- `PayoutBacklog`: `payout_round_gap > 1` в†’ СѓРІРµРґРѕРјР»РµРЅРёРµ on-chain РєРѕРјР°РЅРґС‹, РїСЂРѕРІРµСЂРєР° AutomationBot.
- `AutomationDryRunStale`: dry-run СЃС‚Р°СЂС€Рµ С‚Р°Р№РјР»РѕРєР° в†’ РЅР°РїРѕРјРёРЅР°РЅРёРµ РѕРїРµСЂР°С‚РѕСЂСѓ Р±РѕС‚Р°.
- `AutomationTimelockBreach`: `automation_timelock_breach > 0` в†’ СЃСЂРѕС‡РЅРѕ РїРѕРґРЅСЏС‚СЊ С‚Р°Р№РјР»РѕРє РґРѕ в‰Ґ900 СЃРµРєСѓРЅРґ РёР»Рё РѕС‚РєР»СЋС‡РёС‚СЊ С‡СѓРІСЃС‚РІРёС‚РµР»СЊРЅС‹Рµ РґРµР№СЃС‚РІРёСЏ, РѕР±РЅРѕРІРёС‚СЊ Р¶СѓСЂРЅР°Р» dry-run.
- `SalesDrop`: РїР°РґРµРЅРёРµ `sales_rate` > 50% Р±РµР· РїР»Р°РЅРѕРІС‹С… РёР·РјРµРЅРµРЅРёР№ в†’ СЂР°СЃСЃР»РµРґРѕРІР°РЅРёРµ РјР°СЂРєРµС‚РёРЅРіР°/РїРѕРґРґРµСЂР¶РєРё.
- `PriceFeedFallback`: `price_feed_fallback_active > 0` > 5 РјРёРЅ в†’ СѓРІРµРґРѕРјР»РµРЅРёРµ RootAdmin, РІС‹РїРѕР»РЅРёС‚СЊ С€Р°РіРё runbook РїСЂР°Р№СЃ-С„РёРґР°.
- `PriceFeedClamp`: `price_feed_clamp_active > 0` > 5 РјРёРЅ в†’ РїСЂРѕРІРµСЂРёС‚СЊ РїРѕСЃС‚Р°РІС‰РёРєР° С†РµРЅС‹, Р·Р°РґРѕРєСѓРјРµРЅС‚РёСЂРѕРІР°С‚СЊ `clear_clamp` Рё РѕР±РЅРѕРІРёС‚СЊ РєРѕС‚РёСЂРѕРІРєСѓ.
- `RoleCapExpiring`: `partner_cap_expiring` РёР»Рё `premium_cap_expiring` > 0 в†’ СѓРІРµРґРѕРјР»РµРЅРёРµ RootAdmin, РІС‹РїРѕР»РЅРёС‚СЊ `roles::cleanup_expired_admin`/`revoke_*`, РѕР±РЅРѕРІРёС‚СЊ `incident_log.md` Рё СѓРґРѕСЃС‚РѕРІРµСЂРёС‚СЊСЃСЏ, С‡С‚Рѕ СЃРѕР±С‹С‚РёСЏ `PartnerPayoutCapRevoked`/`PremiumAccessRevoked` Р·Р°С„РёРєСЃРёСЂРѕРІР°РЅС‹.
- `RefundBacklog`: `refund_batch_pending > 0` > 4 С‡Р°СЃРѕРІ в†’ СѓРІРµРґРѕРјР»РµРЅРёРµ RootAdmin Рё Treasury, СЃР»РµРґРѕРІР°С‚СЊ РїСЂРѕС†РµРґСѓСЂРµ [refund.md](refund.md).
- `RefundRoundStalled`: `refund_progress.round` РЅРµ РјРµРЅСЏРµС‚СЃСЏ > 60 РјРёРЅСѓС‚ РїСЂРё Р°РєС‚РёРІРЅРѕРј `refund_batch_pending` в†’ РїСЂРѕРІРµСЂРёС‚СЊ, С‡С‚Рѕ Р±Р°С‚С‡ РѕРїСѓР±Р»РёРєРѕРІР°РЅ Рё РЅРµС‚ РѕС€РёР±РѕРє Supra CLI.
- `RefundAging`: `refund_progress.last_ts` СЃС‚Р°СЂС€Рµ 120 РјРёРЅСѓС‚ РїСЂРё Р°РєС‚РёРІРЅРѕРј СЂРµС„Р°РЅРґРµ в†’ СЌСЃРєР°Р»РёСЂРѕРІР°С‚СЊ РІ Treasury, СЃРІРµСЂРёС‚СЊ СЂСѓС‡РЅС‹Рµ Р±Р°С‚С‡Рё.
- `RefundSlaBreach`: `refund_sla_breach = true` в†’ СЃСЂРѕС‡РЅРѕРµ СѓРІРµРґРѕРјР»РµРЅРёРµ РїРѕРґРґРµСЂР¶РєРё, РѕР±РЅРѕРІР»РµРЅРёРµ С„СЂРѕРЅС‚РµРЅРґ-Р±Р°РЅРЅРµСЂРѕРІ Рё РєРѕРјРјСѓРЅРёРєР°С†РёР№ СЃ РёРіСЂРѕРєР°РјРё.

## 5. РџСЂРѕС†РµРґСѓСЂС‹ РѕР±РЅРѕРІР»РµРЅРёСЏ
- Р Р°Р· РІ СЂРµР»РёР· РїСЂРѕРІРµСЂСЏС‚СЊ СЃРѕРѕС‚РІРµС‚СЃС‚РІРёРµ РјРµС‚СЂРёРє РґРѕРєСѓРјРµРЅС‚Р°С†РёРё (`lottery_multi_readiness_review.md`) Рё РѕР±РЅРѕРІР»СЏС‚СЊ [status_page.md](status_page.md).
- Р•Р¶РµРЅРµРґРµР»СЊРЅРѕ СЃРІРµСЂСЏС‚СЊ РґР°С€Р±РѕСЂРґС‹ СЃ РєРѕРЅС‚СЂРѕР»СЊРЅС‹Рј СЃРїРёСЃРєРѕРј [post_release_support.md](post_release_support.md) Рё С„РёРєСЃРёСЂРѕРІР°С‚СЊ РёС‚РѕРіРё РІ [postmortems.md](postmortems.md).
- РџСЂРё РґРѕР±Р°РІР»РµРЅРёРё РЅРѕРІС‹С… СЃРѕР±С‹С‚РёР№ РѕР±РЅРѕРІРёС‚СЊ СЃС…РµРјС‹ РІ `docs/handbook/architecture/json/` Рё Р°Р»С‘СЂС‚С‹.
- Р’СЃРµ РёР·РјРµРЅРµРЅРёСЏ Р°Р»С‘СЂС‚РѕРІ Р·Р°РЅРѕСЃСЏС‚СЃСЏ РІ `incident_log.md`.

## 6. SLA РјРѕРЅРёС‚РѕСЂРёРЅРіР°
- Р’СЂРµРјСЏ СЂРµР°РєС†РёРё РЅР° РєСЂРёС‚РёС‡РµСЃРєРёР№ Р°Р»С‘СЂС‚ вЂ” в‰¤ 15 РјРёРЅСѓС‚.
- Р’СЂРµРјСЏ СЂРµР°РєС†РёРё РЅР° РІС‹СЃРѕРєРёР№ Р°Р»С‘СЂС‚ вЂ” в‰¤ 30 РјРёРЅСѓС‚.
- Weekly review РјРµС‚СЂРёРє СЃ РїСЂРѕРґСѓРєС‚РѕРІРѕР№ Рё Р±РµР·РѕРїР°СЃРЅРѕСЃС‚СЊСЋ (СЃРј. СЂР°СЃРїРёСЃР°РЅРёРµ РІ [post_release_support.md](post_release_support.md)).

## 7. РљРѕРЅС‚Р°РєС‚С‹
- **On-call DevOps:** @ops-oncall
- **Automation Owner:** @automation-lead
- **Security:** @asecurity

