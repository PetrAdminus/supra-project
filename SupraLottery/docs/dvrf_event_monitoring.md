# РњРѕРЅРёС‚РѕСЂРёРЅРі СЃРѕР±С‹С‚РёР№ Supra dVRF 3.0

Р­С‚РѕС‚ РґРѕРєСѓРјРµРЅС‚ РѕРїРёСЃС‹РІР°РµС‚, РєР°Рє РѕС‚СЃР»РµР¶РёРІР°С‚СЊ СЃРѕР±С‹С‚РёСЏ Supra dVRF 3.0 РІ СЃРµС‚Рё testnet
РїРѕСЃР»Рµ РЅР°СЃС‚СЂРѕР№РєРё РїРѕРґРїРёСЃРєРё Рё Р·Р°РїСѓСЃРєР° СЂРѕР·С‹РіСЂС‹С€Р°. Р’СЃРµ РїСЂРёРјРµСЂС‹ РїРѕРґСЂР°Р·СѓРјРµРІР°СЋС‚, С‡С‚Рѕ
РІС‹ СѓР¶Рµ РІС‹РїРѕР»РЅРёР»Рё РєРѕРјР°РЅРґС‹ РёР· [testnet_runbook](./testnet_runbook.md) Рё Р·РЅР°РµС‚Рµ
Р°РґСЂРµСЃ РєРѕРЅС‚СЂР°РєС‚Р° Р»РѕС‚РµСЂРµРё (`LOTTERY_ADDR`) Рё РїСЂРѕС„РёР»СЊ Supra CLI (`PROFILE`).

## РћСЃРЅРѕРІРЅС‹Рµ СЃРѕР±С‹С‚РёСЏ РєРѕРЅС‚СЂР°РєС‚Р° Р»РѕС‚РµСЂРµРё

| РЎРѕР±С‹С‚РёРµ | РљРѕРіРґР° СЌРјРёС‚РёС‚СЃСЏ | Р—Р°С‡РµРј РѕС‚СЃР»РµР¶РёРІР°С‚СЊ |
| --- | --- | --- |
| `SubscriptionConfiguredEvent` | РџРѕСЃР»Рµ СѓСЃРїРµС€РЅРѕРіРѕ `create_subscription` | РџРѕРґС‚РІРµСЂР¶РґР°РµС‚, С‡С‚Рѕ РґРµРїРѕР·РёС‚ РІРЅРµСЃС‘РЅ Рё whitelisting Р·Р°РІРµСЂС€С‘РЅ. |
| `DrawRequestedEvent` | РџСЂРё РІС‹Р·РѕРІРµ `manual_draw`/`request_draw` | Р¤РёРєСЃРёСЂСѓРµС‚ nonce Рё РїР°СЂР°РјРµС‚СЂС‹ Р·Р°РїСЂРѕСЃР° dVRF. |
| `DrawHandledEvent` | РџРѕСЃР»Рµ РєРѕР»Р±СЌРєР° Supra VRF | РџСѓР±Р»РёРєСѓРµС‚ `request_hash`, whitelisted `callback_sender`, `client_seed`, `rng_count`, `num_confirmations` Рё СЃРїРёСЃРѕРє `randomness`, РїРѕРґС‚РІРµСЂР¶РґР°СЏ, С‡С‚Рѕ СЃР»СѓС‡Р°Р№РЅРѕСЃС‚СЊ РѕР±СЂР°Р±РѕС‚Р°РЅР° РїСЂР°РІРёР»СЊРЅС‹Рј Р°РіСЂРµРіР°С‚РѕСЂРѕРј. |
| `RoundSnapshotUpdatedEvent` | РџРѕСЃР»Рµ `buy_ticket`, `schedule_draw`, `reset_round`, `request_randomness`, `fulfill_draw` | РџСѓР±Р»РёРєСѓРµС‚ Р°РіСЂРµРіРёСЂРѕРІР°РЅРЅС‹Р№ `RoundSnapshot` (С‡РёСЃР»Рѕ Р±РёР»РµС‚РѕРІ, СЃС‚Р°С‚СѓСЃ СЂР°СЃРїРёСЃР°РЅРёСЏ, `pending_request_id`, `next_ticket_id`) Рё РїРѕР·РІРѕР»СЏРµС‚ Supra РѕС‚СЃР»РµР¶РёРІР°С‚СЊ РіРѕС‚РѕРІРЅРѕСЃС‚СЊ СЂР°СѓРЅРґРѕРІ Р±РµР· С‡С‚РµРЅРёСЏ С‚Р°Р±Р»РёС†. |
| `AggregatorWhitelistedEvent`/`ConsumerWhitelistedEvent` | РџСЂРё РёР·РјРµРЅРµРЅРёРё whitelist | РџРѕР·РІРѕР»СЏСЋС‚ Р°СѓРґРёС‚РѕСЂР°Рј СѓР±РµРґРёС‚СЊСЃСЏ, С‡С‚Рѕ РґРѕСЃС‚СѓРї РІС‹РґР°РЅ РєРѕСЂСЂРµРєС‚РЅС‹Рј Р°РґСЂРµСЃР°Рј. |
| `WhitelistSnapshotUpdatedEvent` | РџРѕСЃР»Рµ `init`, `whitelist_callback_sender`, `revoke_callback_sender`, `whitelist_consumer`, `remove_consumer` | РџСѓР±Р»РёРєСѓРµС‚ whitelisted Р°РіСЂРµРіР°С‚РѕСЂ Рё РїРѕР»РЅС‹Р№ СЃРїРёСЃРѕРє РїРѕС‚СЂРµР±РёС‚РµР»РµР№ РѕРґРЅРёРј СЃРѕР±С‹С‚РёРµРј вЂ” РґРѕСЃС‚Р°С‚РѕС‡РЅРѕ СЃРјРѕС‚СЂРµС‚СЊ С‚РѕР»СЊРєРѕ СЌС‚РѕС‚ РїРѕС‚РѕРє, С‡С‚РѕР±С‹ РІРёРґРµС‚СЊ С‚РµРєСѓС‰РµРµ СЃРѕСЃС‚РѕСЏРЅРёРµ whitelist. |
| `JackpotSnapshotUpdatedEvent` | РџРѕСЃР»Рµ `init`, РІС‹РґР°С‡Рё Р±РёР»РµС‚РѕРІ, РїР»Р°РЅРёСЂРѕРІР°РЅРёСЏ РёР»Рё СЃР±СЂРѕСЃР° СЂРѕР·С‹РіСЂС‹С€Р°, Р·Р°РїСЂРѕСЃР° Рё fulfill РіР»РѕР±Р°Р»СЊРЅРѕРіРѕ РґР¶РµРєРїРѕС‚Р° | РџСѓР±Р»РёРєСѓРµС‚ СЃРЅРёРјРѕРє РіР»РѕР±Р°Р»СЊРЅРѕРіРѕ РґР¶РµРєРїРѕС‚Р°: Р°РґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂР°, `lottery_id`, РєРѕР»РёС‡РµСЃС‚РІРѕ Р±РёР»РµС‚РѕРІ, СЃС‚Р°С‚СѓСЃ СЂР°СЃРїРёСЃР°РЅРёСЏ Рё `pending_request_id`, С‡С‚Рѕ РїРѕР·РІРѕР»СЏРµС‚ Supra РѕС‚СЃР»РµР¶РёРІР°С‚СЊ РіРѕС‚РѕРІРЅРѕСЃС‚СЊ Р±РµР· С‡С‚РµРЅРёСЏ storage. |

## РЎРѕР±С‹С‚РёСЏ VRF Hub

| РЎРѕР±С‹С‚РёРµ | РљРѕРіРґР° СЌРјРёС‚РёС‚СЃСЏ | Р—Р°С‡РµРј РѕС‚СЃР»РµР¶РёРІР°С‚СЊ |
| --- | --- | --- |
| `CallbackSenderUpdatedEvent` (`@vrf_hub::hub`) | РџСЂРё РІС‹Р·РѕРІРµ `set_callback_sender` Р°РґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂРѕРј VRF Hub | Р¤РёРєСЃРёСЂСѓРµС‚ РїСЂРµРґС‹РґСѓС‰РёР№ Рё С‚РµРєСѓС‰РёР№ whitelisted Р°РіСЂРµРіР°С‚РѕСЂ Supra; Р¶СѓСЂРЅР°Р» РїСЂРёРіРѕРґРёС‚СЃСЏ РґР»СЏ Р°СѓРґРёС‚Р° РѕРїРµСЂР°С†РёР№ whitelisting РЅР° СѓСЂРѕРІРЅРµ hub РїРµСЂРµРґ РІС‹РґР°С‡РµР№ РґРѕСЃС‚СѓРїР° РєРѕРЅРєСЂРµС‚РЅС‹Рј Р»РѕС‚РµСЂРµСЏРј. |

## РЎРѕР±С‹С‚РёСЏ С„Р°Р±СЂРёРєРё Р»РѕС‚РµСЂРµР№

| РЎРѕР±С‹С‚РёРµ | РљРѕРіРґР° СЌРјРёС‚РёС‚СЃСЏ | Р—Р°С‡РµРј РѕС‚СЃР»РµР¶РёРІР°С‚СЊ |
| --- | --- | --- |
| `LotteryRegistrySnapshotUpdatedEvent` (`@lottery_factory::registry`) | РџРѕСЃР»Рµ `init`, `create_lottery`, `update_blueprint`, `set_admin` | РџСѓР±Р»РёРєСѓРµС‚ Р°РґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂР° С„Р°Р±СЂРёРєРё Рё РїРѕР»РЅС‹Р№ СЃРїРёСЃРѕРє Р»РѕС‚РµСЂРµР№ СЃ Р°РґСЂРµСЃР°РјРё, С†РµРЅРѕР№ Р±РёР»РµС‚Р° Рё РґРѕР»РµР№ РґР¶РµРєРїРѕС‚Р°; РїРѕР·РІРѕР»СЏРµС‚ Supra СЃРІРµСЂСЏС‚СЊ, РєР°РєРёРµ РїСЂРѕРµРєС‚С‹ Р·Р°СЂРµРіРёСЃС‚СЂРёСЂРѕРІР°РЅС‹ Рё РєС‚Рѕ СѓРїСЂР°РІР»СЏРµС‚ С„Р°Р±СЂРёРєРѕР№ Р±РµР· С‡С‚РµРЅРёСЏ РІСЃРµР№ РёСЃС‚РѕСЂРёРё СЃРѕР±С‹С‚РёР№. |

View-С„СѓРЅРєС†РёСЏ `@lottery_factory::registry::get_registry_snapshot` РІРѕР·РІСЂР°С‰Р°РµС‚ С‚Рµ Р¶Рµ РїРѕР»СЏ РІ JSON, Р° `list_lottery_ids` РїСЂРёРіРѕРґРёС‚СЃСЏ РґР»СЏ Р±С‹СЃС‚СЂРѕР№ РїСЂРѕРІРµСЂРєРё РєРѕР»РёС‡РµСЃС‚РІР° Р·Р°СЂРµРіРёСЃС‚СЂРёСЂРѕРІР°РЅРЅС‹С… Р»РѕС‚РµСЂРµР№:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move view \
  --profile $PROFILE \
  --function $LOTTERY_FACTORY_ADDR::registry::get_registry_snapshot"
```

Р”Р»СЏ РїРѕР»СѓС‡РµРЅРёСЏ С‚РѕР»СЊРєРѕ РёРґРµРЅС‚РёС„РёРєР°С‚РѕСЂРѕРІ РІС‹РїРѕР»РЅРёС‚Рµ:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move view \
  --profile $PROFILE \
  --function $LOTTERY_FACTORY_ADDR::registry::list_lottery_ids"
```

## Р‘С‹СЃС‚СЂС‹Р№ РїСЂРѕСЃРјРѕС‚СЂ РїРѕСЃР»РµРґРЅРёС… СЃРѕР±С‹С‚РёР№

Р§С‚РѕР±С‹ СѓРІРёРґРµС‚СЊ РїРѕСЃР»РµРґРЅРёРµ Р·Р°РїРёСЃРё РїРѕ РєР°Р¶РґРѕРјСѓ СЃРѕР±С‹С‚РёСЋ, РёСЃРїРѕР»СЊР·СѓР№С‚Рµ `move tool events list`. Р”Р»СЏ `DrawRequestedEvent` Рё `DrawHandledEvent` РїСЂРѕРІРµСЂСЊС‚Рµ, С‡С‚Рѕ СЃРѕРІРїР°РґР°СЋС‚ `request_hash`, `callback_sender` Рё РїР°СЂР°РјРµС‚СЂС‹ РіР°Р·Р°/РїРѕРґС‚РІРµСЂР¶РґРµРЅРёР№.
РљРѕРјР°РЅРґР° РІС‹РІРѕРґРёС‚ JSON; Р°СЂРіСѓРјРµРЅС‚ `--limit` Р·Р°РґР°С‘С‚ РєРѕР»РёС‡РµСЃС‚РІРѕ СЃРѕР±С‹С‚РёР№, РЅР°С‡РёРЅР°СЏ СЃ
РїРѕСЃР»РµРґРЅРёС… (РїРѕ СѓР±С‹РІР°РЅРёСЋ РЅРѕРјРµСЂР°).

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events list \
  --profile $PROFILE \
  --address $LOTTERY_ADDR \
  --event-type $LOTTERY_ADDR::main_v2::DrawHandledEvent \
  --limit 5"
```

## РќРµРїСЂРµСЂС‹РІРЅРѕРµ СЃР»РµР¶РµРЅРёРµ РІРѕ РІСЂРµРјСЏ С‚РµСЃС‚РѕРІ

Р”Р»СЏ live-РјРѕРЅРёС‚РѕСЂРёРЅРіР° РёСЃРїРѕР»СЊР·СѓР№С‚Рµ `events tail`. РљРѕРјР°РЅРґР° Р±СѓРґРµС‚ РІС‹РІРѕРґРёС‚СЊ РЅРѕРІС‹Рµ
Р·Р°РїРёСЃРё РІ СЂРµР¶РёРјРµ СЂРµР°Р»СЊРЅРѕРіРѕ РІСЂРµРјРµРЅРё, РїРѕРєР° РІС‹ РЅРµ РїСЂРµСЂРІС‘С‚Рµ РїСЂРѕС†РµСЃСЃ (`Ctrl+C`).

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events tail \
  --profile $PROFILE \
  --address $LOTTERY_ADDR \
  --event-type $LOTTERY_ADDR::main_v2::DrawRequestedEvent"
```

РџРѕРІС‚РѕСЂРёС‚Рµ РєРѕРјР°РЅРґСѓ РґР»СЏ `DrawHandledEvent`, С‡С‚РѕР±С‹ СѓРІРёРґРµС‚СЊ СѓСЃРїРµС€РЅРѕРµ Р·Р°РІРµСЂС€РµРЅРёРµ
СЂРѕР·С‹РіСЂС‹С€Р°. РђРЅР°Р»РѕРіРёС‡РЅРѕ РјРѕР¶РЅРѕ РѕС‚СЃР»РµР¶РёРІР°С‚СЊ СЃРѕР±С‹С‚РёСЏ whitelisting:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events tail \
  --profile $PROFILE \
  --address $LOTTERY_ADDR \
  --event-type $LOTTERY_ADDR::main_v2::WhitelistSnapshotUpdatedEvent"
```

## РџСЂРѕРІРµСЂРєР° СЃРѕР±С‹С‚РёР№ РјРѕРґСѓР»РµР№ Supra

РњРѕРґСѓР»СЊ `deposit` С‚Р°РєР¶Рµ РїСѓР±Р»РёРєСѓРµС‚ СЃРѕР±С‹С‚РёСЏ (РЅР°РїСЂРёРјРµСЂ, РїРѕРїРѕР»РЅРµРЅРёРµ РґРµРїРѕР·РёС‚Р°).
Р§С‚РѕР±С‹ РїРѕСЃРјРѕС‚СЂРµС‚СЊ РёС…, СѓРєР°Р¶РёС‚Рµ Р°РґСЂРµСЃ РјРѕРґСѓР»СЏ (РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ
`0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e`).

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events list \
  --profile $PROFILE \
  --address $DEPOSIT_ADDR \
  --limit 10"
```

`events tail` С‚Р°РєР¶Рµ СЂР°Р±РѕС‚Р°РµС‚ РґР»СЏ Р°РґСЂРµСЃРѕРІ РјРѕРґСѓР»РµР№ Supra, С‡С‚Рѕ РїРѕР»РµР·РЅРѕ РїСЂРё
СЂР°Р·Р±РѕСЂРµ РїСЂРѕР±Р»РµРј СЃ whitelisting РёР»Рё РґРµРїРѕР·РёС‚РѕРј.

## РСЃРїРѕР»СЊР·РѕРІР°РЅРёРµ jq РґР»СЏ Р°РіСЂРµРіР°С†РёРё

Р§С‚РѕР±С‹ Р±С‹СЃС‚СЂРѕ С„РёР»СЊС‚СЂРѕРІР°С‚СЊ РїРѕР»СЏ (РЅР°РїСЂРёРјРµСЂ, nonce РёР»Рё client seed), РјРѕР¶РЅРѕ
РёСЃРїРѕР»СЊР·РѕРІР°С‚СЊ `jq`:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events list \
  --profile $PROFILE \
  --address $LOTTERY_ADDR \
  --event-type $LOTTERY_ADDR::main_v2::DrawRequestedEvent \
  --limit 1" | jq '.result[0].data'
```

## РџСЂРѕСЃРјРѕС‚СЂ pending-Р·Р°СЏРІРєРё С‡РµСЂРµР· view

РЎРѕР±С‹С‚РёР№ РґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РґР»СЏ Р°СѓРґРёС‚Р°, РЅРѕ Supra С‚Р°РєР¶Рµ СЂРµРєРѕРјРµРЅРґСѓРµС‚ СЃРІРµСЂСЏС‚СЊ СЃРѕСЃС‚РѕСЏРЅРёРµ
РєРѕРЅС‚СЂР°РєС‚Р°. Р”Р»СЏ СЌС‚РѕРіРѕ РІ `Lottery.move` РґРѕР±Р°РІР»РµРЅР° view-С„СѓРЅРєС†РёСЏ
`get_pending_request_view`, РІРѕР·РІСЂР°С‰Р°СЋС‰Р°СЏ СЃС‚СЂСѓРєС‚СѓСЂСѓ `PendingRequestView` СЃ nonce,
Р°РґСЂРµСЃРѕРј `requester`, С…РµС€РµРј `request_hash`, РїР°СЂР°РјРµС‚СЂР°РјРё РіР°Р·Р° Рё РїРѕРґС‚РІРµСЂР¶РґРµРЅРёР№.

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move view \
  --profile $PROFILE \
  --function $LOTTERY_ADDR::main_v2::get_pending_request_view"
```

Р РµР·СѓР»СЊС‚Р°С‚ РїСЂРёС…РѕРґРёС‚ РІ JSON: РїРѕР»Рµ `Some` СЃРѕРґРµСЂР¶РёС‚ РІСЃРµ Р·РЅР°С‡РµРЅРёСЏ, РєРѕС‚РѕСЂС‹Рµ Supra
РѕР¶РёРґР°РµС‚ РІРёРґРµС‚СЊ РІ `CallbackRequest`. Р­С‚Рѕ СѓРґРѕР±РЅРѕ РїСЂРё РѕС‚Р»Р°РґРєРµ CLI РёР»Рё СЃСЂР°РІРЅРµРЅРёРё СЃ
РґР°РЅРЅС‹РјРё VRF Hub (`payload_hash`).

Р”Р»СЏ РєРѕРЅС‚СЂРѕР»СЏ РіР»РѕР±Р°Р»СЊРЅРѕРіРѕ РґР¶РµРєРїРѕС‚Р° РІС‹Р·РѕРІРёС‚Рµ view `lottery::jackpot::get_snapshot` вЂ” СЃС‚СЂСѓРєС‚СѓСЂР° СЃРѕРІРїР°РґР°РµС‚ СЃ СЃРѕР±С‹С‚РёРµРј `JackpotSnapshotUpdatedEvent` Рё СЃРѕРґРµСЂР¶РёС‚ `pending_request_id`, РµСЃР»Рё Р·Р°СЏРІРєР° Р°РєС‚РёРІРЅР°:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move view \
  --profile $PROFILE \
  --function $LOTTERY_ADDR::jackpot::get_snapshot"
```

РћС‚РІРµС‚ `None` РѕР·РЅР°С‡Р°РµС‚, С‡С‚Рѕ РјРѕРґСѓР»СЊ РµС‰С‘ РЅРµ РёРЅРёС†РёР°Р»РёР·РёСЂРѕРІР°РЅ; `Some` РІРѕР·РІСЂР°С‰Р°РµС‚ РїРѕР»СЏ `admin`, `lottery_id`, `ticket_count`, `draw_scheduled`, `has_pending_request` Рё `pending_request_id`.

Р”Р»СЏ СЂР°СѓРЅРґРѕРІ РѕСЃРЅРѕРІРЅРѕР№ Р»РѕС‚РµСЂРµРё РёСЃРїРѕР»СЊР·СѓР№С‚Рµ view `lottery::core_rounds::get_round_snapshot`: СЂРµР·СѓР»СЊС‚Р°С‚ СЃРѕРґРµСЂР¶РёС‚ С‚РѕС‚ Р¶Рµ `RoundSnapshot`, С‡С‚Рѕ РїСѓР±Р»РёРєСѓРµС‚ СЃРѕР±С‹С‚РёРµ `RoundSnapshotUpdatedEvent`.

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move view \
  --profile $PROFILE \
  --function $LOTTERY_ADDR::rounds::get_round_snapshot \
  --arg u64:$LOTTERY_ID"
```

РџСЂРё Р°РєС‚РёРІРЅРѕР№ Р·Р°СЏРІРєРµ РїРѕР»Рµ `pending_request_id` РІРµСЂРЅС‘С‚ РёРґРµРЅС‚РёС„РёРєР°С‚РѕСЂ VRF-Р·Р°РїСЂРѕСЃР°; РІ РѕСЃС‚Р°Р»СЊРЅС‹С… СЃР»СѓС‡Р°СЏС… Р·РЅР°С‡РµРЅРёРµ Р±СѓРґРµС‚ `None`, С‡С‚Рѕ СЃРѕРІРїР°РґР°РµС‚ СЃ СЃРѕР±С‹С‚РёСЏРјРё СЃРЅР°РїС€РѕС‚РѕРІ Рё СѓРїСЂРѕС‰Р°РµС‚ СЃРІРµСЂРєСѓ РјРѕРЅРёС‚РѕСЂРёРЅРіР° Supra.

Р”Р»СЏ РїСЂРѕРІРµСЂРєРё whitelisted Р°РіСЂРµРіР°С‚РѕСЂР° VRF Hub РІС‹Р·РѕРІРёС‚Рµ view `@vrf_hub::hub::get_callback_sender_status`:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move view \
  --profile $PROFILE \
  --function $VRF_HUB_ADDR::hub::get_callback_sender_status"
```

Р•СЃР»Рё Р°РіСЂРµРіР°С‚РѕСЂ РЅР°Р·РЅР°С‡РµРЅ, JSON РІРµСЂРЅС‘С‚ `"Some": "0xвЂ¦"`; Р·РЅР°С‡РµРЅРёРµ `None` РѕР·РЅР°С‡Р°РµС‚,
С‡С‚Рѕ VRF Hub РЅРµ РіРѕС‚РѕРІ Рє РѕР±СЂР°Р±РѕС‚РєРµ РєРѕР»Р±СЌРєРѕРІ Supra Рё РЅРµРѕР±С…РѕРґРёРјРѕ РїРѕРІС‚РѕСЂРЅРѕ РІС‹Р·РІР°С‚СЊ
`set_callback_sender`.

## РРЅС‚РµРіСЂР°С†РёСЏ РІ РїСЂРѕС†РµСЃСЃС‹ QA

- Р¤РёРєСЃРёСЂСѓР№С‚Рµ С…СЌС€Рё С‚СЂР°РЅР·Р°РєС†РёР№ Рё СЃРѕР±С‹С‚РёСЏ `DrawRequestedEvent`/`DrawHandledEvent`
  РІ РѕС‚С‡С‘С‚Р°С… QA.
- РџСЂРё РјРёРіСЂР°С†РёРё РЅР° РЅРѕРІС‹Рµ Р»РёРјРёС‚С‹ РіР°Р·Р° Р·Р°РїСѓСЃРєР°С‚СЊ `events list` РїРµСЂРµРґ Рё РїРѕСЃР»Рµ
  РёР·РјРµРЅРµРЅРёР№, С‡С‚РѕР±С‹ СЃСЂР°РІРЅРёС‚СЊ, РєР°РєРёРµ РїР°СЂР°РјРµС‚СЂС‹ Р·Р°РєСЂРµРїР»РµРЅС‹ РІ `SubscriptionConfiguredEvent`.
- Р”Р»СЏ Р°СѓРґРёС‚Р° whitelisting РІС‹РіСЂСѓР¶Р°Р№С‚Рµ СЃРѕР±С‹С‚РёСЏ РІ С„Р°Р№Р»: `... events list --limit 50 > whitelist_events.json`.

Р”РѕРєСѓРјРµРЅС‚ РѕР±РЅРѕРІР»СЏРµС‚СЃСЏ РїРѕ РјРµСЂРµ РїРѕСЏРІР»РµРЅРёСЏ РЅРѕРІС‹С… С‚СЂРµР±РѕРІР°РЅРёР№ Supra Рё РІРЅСѓС‚СЂРµРЅРЅРёС…
РїСЂРѕС†РµСЃСЃРѕРІ QA.

