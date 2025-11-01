# Supra Lottery вЂ” Testnet Runbook

## 1. РџСЂРµРґРІР°СЂРёС‚РµР»СЊРЅС‹Рµ С‚СЂРµР±РѕРІР°РЅРёСЏ
- Р Р°Р±РѕС‡Р°СЏ РІРµС‚РєР° `Test`: РІСЃРµ РёР·РјРµРЅРµРЅРёСЏ РІРЅРѕСЃСЏС‚СЃСЏ С‚РѕР»СЊРєРѕ СЃСЋРґР°, РЅРѕРІС‹Рµ РІРµС‚РєРё РЅРµ СЃРѕР·РґР°С‘Рј; СЂРµР»РёР·РЅС‹Рµ СЃР»РёСЏРЅРёСЏ РІС‹РїРѕР»РЅСЏСЋС‚СЃСЏ РІ `master` РїРѕСЃР»Рµ Р·Р°РІРµСЂС€РµРЅРёСЏ РєР»СЋС‡РµРІС‹С… СЌС‚Р°РїРѕРІ.
- РђРєРєР°СѓРЅС‚ Supra СЃ РґРѕСЃС‚СѓРїРѕРј Рє testnet Рё РїСЂРёРІР°С‚РЅС‹Рј РєР»СЋС‡РѕРј StarKey.
- РћР·РЅР°РєРѕРјСЊС‚РµСЃСЊ СЃ РѕС„РёС†РёР°Р»СЊРЅС‹РјРё РіР°Р№РґР°РјРё Supra: [token-standards](https://docs.supra.com/network/move/token-standards), [fungible_asset module](https://docs.supra.com/network/move/supra-fungible-asset-fa-module), [Supra CLI СЃ Docker](https://docs.supra.com/network/move/getting-started/supra-cli-with-docker).
- RPC endpoint Supra testnet: `https://rpc-testnet.supra.com` (chain id 6).
- Mainnet (РґР»СЏ СЃРїСЂР°РІРєРё): `https://rpc-mainnet.supra.com` (chain id 8).
- РђРґСЂРµСЃР° РєРѕРЅС‚СЂР°РєС‚РѕРІ: РґРµРїРѕР·РёС‚ dVRF v3 Рё `lottery` (СЃРј. РѕС„РёС†РёР°Р»СЊРЅСѓСЋ РґРѕРєСѓРјРµРЅС‚Р°С†РёСЋ).
- Р—РЅР°С‡РµРЅРёСЏ РіР°Р·Р°: `maxGasPrice`, `maxGasLimit`, `callbackGasPrice`, `callbackGasLimit`, РєРѕСЌС„С„РёС†РёРµРЅС‚ Р±РµР·РѕРїР°СЃРЅРѕСЃС‚Рё РґР»СЏ РґРµРїРѕР·РёС‚Р°.
- РЈСЃС‚Р°РЅРѕРІР»РµРЅРЅС‹Р№ Docker Рё РїРѕРґРіРѕС‚РѕРІР»РµРЅРЅС‹Р№ `supra_cli` (СЃРј. `docker-compose.yml`).

> Р‘С‹СЃС‚СЂС‹Р№ РєРѕРЅС‚СЂРѕР»СЊ РїРµСЂРµРґ СЂРµР»РёР·РѕРј: РІРѕСЃРїРѕР»СЊР·СѓР№С‚РµСЃСЊ [С‡РµРє-Р»РёСЃС‚РѕРј РґРµРїР»РѕСЏ](./testnet_deployment_checklist.md), РіРґРµ СЃРѕР±СЂР°РЅС‹ Р°РґСЂРµСЃР°, Р·РЅР°С‡РµРЅРёСЏ РіР°Р·Р° Рё РѕР±СЏР·Р°С‚РµР»СЊРЅС‹Рµ РєРѕРјР°РЅРґС‹.
>
> РџРѕСЃР»Рµ РІС‹РїРѕР»РЅРµРЅРёСЏ РІСЃРµС… С€Р°РіРѕРІ runbook РїСЂРѕР№РґРёС‚Рµ [РІРЅСѓС‚СЂРµРЅРЅРёР№ С‡РµРє-Р»РёСЃС‚ Р°СѓРґРёС‚Р°](./audit/internal_audit_checklist.md), С‡С‚РѕР±С‹ СЃРІРµСЂРёС‚СЊ РєРѕРЅС„РёРіСѓСЂР°С†РёСЋ, С‚РµСЃС‚С‹ Рё РґРѕРєСѓРјРµРЅС‚Р°С†РёСЋ РїРµСЂРµРґ РїРµСЂРµРґР°С‡РµР№ СЃС‚Р°С‚СѓСЃР° Supra.
> Р”Р»СЏ РґРёРЅР°РјРёС‡РµСЃРєРёС… РїСЂРѕРІРµСЂРѕРє (Supra CLI, Move-С‚РµСЃС‚С‹, Python-С‚РµСЃС‚С‹, СЃРјРѕСѓРє-РїСЂРѕРіРѕРЅ) РёСЃРїРѕР»СЊР·СѓР№С‚Рµ [СЃС†РµРЅР°СЂРёР№ G1](./audit/internal_audit_dynamic_runbook.md).

## 2. РќР°СЃС‚СЂРѕР№РєР° Supra CLI РїСЂРѕС„РёР»СЏ
Supra CLI РЅР°С‡РёРЅР°СЏ СЃ СЂРµР»РёР·Р° 2025.05 С…СЂР°РЅРёС‚ РєР»СЋС‡Рё Рё РїР°СЂР°РјРµС‚СЂС‹ СЃРµС‚Рё РІ РїСЂРѕС„РёР»СЏС…. РџРµСЂРµРґ Р·Р°РїСѓСЃРєРѕРј РѕСЃС‚Р°Р»СЊРЅС‹С… РєРѕРјР°РЅРґ СЃРѕР·РґР°Р№С‚Рµ Рё Р°РєС‚РёРІРёСЂСѓР№С‚Рµ РїСЂРѕС„РёР»СЊ Р°РґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂР° (РІ РїСЂРёРјРµСЂР°С… РёСЃРїРѕР»СЊР·СѓРµС‚СЃСЏ РёРјСЏ `lottery_admin`). РџСЂРёРІР°С‚РЅС‹Р№ РєР»СЋС‡ РїРµСЂРµРґР°С‘С‚СЃСЏ **Р±РµР· РїСЂРµС„РёРєСЃР° `0x`**.

1. РЎРѕР·РґР°Р№С‚Рµ РїСЂРѕС„РёР»СЊ testnet:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra profile new lottery_admin <PRIVATE_KEY_HEX> --network testnet"
   ```
2. РџСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё Р°РєС‚РёРІРёСЂСѓР№С‚Рµ РµРіРѕ (РµСЃР»Рё РЅРµСЃРєРѕР»СЊРєРѕ РїСЂРѕС„РёР»РµР№):
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra profile activate lottery_admin"
   ```
3. РџСЂРѕРІРµСЂСЊС‚Рµ СЃРїРёСЃРѕРє РїСЂРѕС„РёР»РµР№ Рё СѓР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ `lottery_admin` РїРѕРјРµС‡РµРЅ `*`:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra profile -l"
   ```

> Р•СЃР»Рё РІС‹ РїСЂРѕРґРѕР»Р¶Р°РµС‚Рµ РІРµСЃС‚Рё РѕР±С‰РёРµ РїР°СЂР°РјРµС‚СЂС‹ (RPC, Р»РёРјРёС‚С‹ РіР°Р·Р°) РІ YAML, Р·Р°РґР°Р№С‚Рµ `SUPRA_CONFIG=/supra/configs/testnet.yaml` РїРµСЂРµРґ РєРѕРјР°РЅРґР°РјРё. Р­С‚РѕС‚ С„Р°Р№Р» РјРѕР¶РµС‚ Р±С‹С‚СЊ СЃРѕР·РґР°РЅ РёР· С€Р°Р±Р»РѕРЅР° `profile_template.yaml`, РЅРѕ РєРѕРјР°РЅРґС‹ РЅРёР¶Рµ РІСЃРµРіРґР° РёСЃРїРѕР»СЊР·СѓСЋС‚ `--profile`, С‡С‚РѕР±С‹ СЃРѕРѕС‚РІРµС‚СЃС‚РІРѕРІР°С‚СЊ РЅРѕРІРѕР№ CLI.

## 3. РњРёРіСЂР°С†РёСЏ РЅР° dVRF v3
> Р’СЃРµ РєРѕРјР°РЅРґС‹ РЅРёР¶Рµ Р·Р°РїСѓСЃРєР°СЋС‚СЃСЏ РѕРґРЅРѕР№ СЃС‚СЂРѕРєРѕР№ С‡РµСЂРµР· Docker. РџРѕРґСЃС‚Р°РІР»СЏР№С‚Рµ СЃРІРѕС‘ РёРјСЏ РїСЂРѕС„РёР»СЏ (РЅР°РїСЂРёРјРµСЂ, `lottery_admin`) Рё РїСЂРё РЅРµРѕР±С…
РѕРґРёРјРѕСЃС‚Рё СЌРєСЃРїРѕСЂС‚РёСЂСѓР№С‚Рµ `SUPRA_CONFIG=/supra/configs/testnet.yaml`, С‡С‚РѕР±С‹ CLI РїРѕРґС…РІР°С‚РёР» РѕР±С‰РёР№ YAML.
> РџСЂРёРјРµСЂС‹ РёСЃРїРѕР»СЊР·СѓСЋС‚ Р°Р»РёР°СЃ `lottery::` РёР· `Move.toml`; РїСЂРё Р·Р°РїСѓСЃРєРµ РІРЅРµ СЂРµРїРѕР·РёС‚РѕСЂРёСЏ СѓРєР°Р·С‹РІР°Р№С‚Рµ РїРѕР»РЅС‹Р№ Р°РґСЂРµСЃ, РЅР°РїСЂРёРјРµСЂ `0xbc95вЂ¦::main_v2::configure_vrf_gas`.

### 3.1 РРЅРёС†РёР°Р»РёР·Р°С†РёСЏ Fungible Asset РґР»СЏ РєР°Р·РЅР°С‡РµР№СЃС‚РІР°
> РћСЂРёРµРЅС‚РёСЂСѓРµРјСЃСЏ РЅР° РѕС„РёС†РёР°Р»СЊРЅС‹Рµ СЃС‚Р°РЅРґР°СЂС‚С‹ Supra: [token-standards](https://docs.supra.com/network/move/token-standards) Рё [РѕРїРёСЃР°РЅРёРµ `fungible_asset`](https://docs.supra.com/network/move/supra-fungible-asset-fa-module).

1. РџСЂРѕРІРµСЂСЏРµРј, СЂР°Р·РІС‘СЂРЅСѓС‚ Р»Рё С‚РѕРєРµРЅ РєР°Р·РЅР°С‡РµР№СЃС‚РІР°:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::core_treasury_v1::is_initialized"
   ```
2. Р•СЃР»Рё РѕС‚РІРµС‚ `false`, РёРЅРёС†РёР°Р»РёР·РёСЂСѓРµРј Metadata (Р·РЅР°С‡РµРЅРёСЏ hex СЃРѕРѕС‚РІРµС‚СЃС‚РІСѓСЋС‚ ASCII-СЃС‚СЂРѕРєР°Рј `Lottery Ticket`, `LOT` Рё СЃРёРґ `lottery_fa_seed`):
   ```bash
   docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli -lc "/supra/supra move tool run --profile <PROFILE> --function-id 0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::core_treasury_v1::init_token --args hex:0x6c6f74746572795f66615f73656564 hex:0x4c6f7474657279205469636b6574 hex:0x4c4f54 u8:9 hex:0x hex:0x"
   ```
   > Если команда возвращает `EOBJECT_EXISTS`, значит metadata уже создана. В этом случае переходите к шагу регистрации primary store (ниже) или запускайте `init_token` с новым seed (например, `lottery_fa_seed2`).
   ```
3. Р—Р°СЂРµРіРёСЃС‚СЂРёСЂСѓР№С‚Рµ primary store РґР»СЏ РІСЃРµС… Р°РєРєР°СѓРЅС‚РѕРІ, РєРѕС‚РѕСЂС‹Рµ Р±СѓРґСѓС‚ РїРѕР»СѓС‡Р°С‚СЊ С‚РѕРєРµРЅС‹:
   ```bash
   docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli -lc "/supra/supra move tool run --profile <PROFILE> --function-id 0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0::core_treasury_v1::register_store_for --args address:<ACCOUNT>"
   ```
   РџРѕР»СЊР·РѕРІР°С‚РµР»Рё С‚Р°РєР¶Рµ РјРѕРіСѓС‚ РІС‹Р·РІР°С‚СЊ `lottery::core_treasury_v1::register_store` СЃР°РјРѕСЃС‚РѕСЏС‚РµР»СЊРЅРѕ С‡РµСЂРµР· СЃРІРѕР№ РєРѕС€РµР»С‘Рє.
   Р”Р»СЏ РјР°СЃСЃРѕРІРѕР№ РїРѕРґРіРѕС‚РѕРІРєРё РјРѕР¶РЅРѕ РёСЃРїРѕР»СЊР·РѕРІР°С‚СЊ Р±Р°С‚С‡-С„СѓРЅРєС†РёСЋ Р°РґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂР°:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::core_treasury_v1::register_stores_for --args address_vector:<ADDR1,ADDR2,...>"
   ```
   > РџРѕРґСЂРѕР±РЅРµРµ РѕР± Р°СЂРіСѓРјРµРЅС‚Рµ `address_vector` СЃРј. СЂР°Р·РґРµР» "Vector arguments" РІ [Supra CLI with Docker](https://docs.supra.com/network/move/getting-started/supra-cli-with-docker).
   > вљ пёЏ РџРµСЂРµРґ Р·Р°РїСѓСЃРєРѕРј `lottery::treasury_multi::init` СѓР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ Р°РґСЂРµСЃР° РґР¶РµРєРїРѕС‚Р° Рё РѕРїРµСЂР°С†РёРѕРЅРЅРѕРіРѕ РїСѓР»Р° СѓР¶Рµ Р·Р°СЂРµРіРёСЃС‚СЂРёСЂРѕРІР°РЅС‹ РєР°Рє primary store; РєРѕРЅС‚СЂР°РєС‚ РІР°Р»РёРґРёСЂСѓРµС‚ СѓСЃР»РѕРІРёРµ Рё РїСЂРё РЅР°СЂСѓС€РµРЅРёРё РІРµСЂРЅС‘С‚ РєРѕРґС‹ `E_TREASURY_NOT_READY`, `E_JACKPOT_RECIPIENT_UNREGISTERED` РёР»Рё `E_OPERATIONS_RECIPIENT_UNREGISTERED`.
4. Р”Р»СЏ С‚РµСЃС‚РѕРІС‹С… Р°РєРєР°СѓРЅС‚РѕРІ РјРѕР¶РЅРѕ Р·Р°СЂР°РЅРµРµ РјРёРЅС‚РёС‚СЊ Р±Р°Р»Р°РЅСЃ, С‡С‚РѕР±С‹ РѕРЅРё СЃРјРѕРіР»Рё РєСѓРїРёС‚СЊ Р±РёР»РµС‚С‹ (РїРѕСЃР»Рµ СЂРµРіРёСЃС‚СЂР°С†РёРё store):
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::core_treasury_v1::mint_to --args address:<PLAYER_ADDR> u64:<AMOUNT>"
   ```
5. РџСЂРѕРІРµСЂСЏРµРј РјРµС‚Р°РґР°РЅРЅС‹Рµ Рё Р°РґСЂРµСЃР° store С‡РµСЂРµР· view-С„СѓРЅРєС†РёРё (РєР°Р¶РґР°СЏ РєРѕРјР°РЅРґР° вЂ” РѕС‚РґРµР»СЊРЅС‹Р№ Р·Р°РїСѓСЃРє):
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::core_treasury_v1::metadata_summary"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::core_treasury_v1::primary_store_address --args address:<ACCOUNT>"

    Р¤СѓРЅРєС†РёСЏ РІРѕР·РІСЂР°С‰Р°РµС‚ РґРµС‚РµСЂРјРёРЅРёСЂРѕРІР°РЅРЅС‹Р№ Р°РґСЂРµСЃ РѕР±СЉРµРєС‚Р° primary store РёР· `supra_framework::primary_fungible_store`. Р—РЅР°С‡РµРЅРёРµ РјРѕР¶РЅРѕ
    СЃСЂР°РІРЅРёС‚СЊ СЃ `object::create_user_derived_object_address` РЅР° Р±СЌРєРµРЅРґРµ Рё РёСЃРїРѕР»СЊР·РѕРІР°С‚СЊ РІ РјРѕРЅРёС‚РѕСЂРёРЅРіРµ РґР»СЏ СЃРІРµСЂРєРё freeze-СЃС‚Р°С‚СѓСЃР° Рё
    Р±Р°Р»Р°РЅСЃР°.
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::core_treasury_v1::get_config"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::core_treasury_v1::account_status --args address:<ACCOUNT>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::core_treasury_v1::account_extended_status --args address:<ACCOUNT>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::core_treasury_v1::store_frozen --args address:<ACCOUNT>"
   ```

   РЎ РјРёРіСЂР°С†РёРµР№ РЅР° MoveВ 1 РІСЃРµ СЃРѕР±С‹С‚РёСЏ РєР°Р·РЅР°С‡РµР№СЃС‚РІР° СЃРѕР·РґР°СЋС‚СЃСЏ С‡РµСЂРµР· `supra_framework::account::new_event_handle`, РїРѕСЌС‚РѕРјСѓ GUID РѕРїСЂРµРґРµР»СЏРµС‚СЃСЏ Р°РґСЂРµСЃРѕРј Р»РѕС‚РµСЂРµРё Рё `creation_num`. РЎРІРµСЂРёС‚СЊ Р·РЅР°С‡РµРЅРёСЏ РјРѕР¶РЅРѕ РєРѕРјР°РЅРґРѕР№:

   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool resource --profile <PROFILE> --account <LOTTERY_ADDR> --resource-id lottery::core_treasury_v1::TreasuryState"
   ```

   РџРѕР»СЏ `*_events.guid.id.creation_num` РІ РІС‹РІРѕРґРµ РїРѕРґСЃРєР°Р¶СѓС‚, РєР°РєРёРµ GUID РїРµСЂРµРґР°РІР°С‚СЊ РІ `supra move tool event --start <seq>` РїСЂРё РІС‹РіСЂСѓР·РєРµ Р»РѕРіРѕРІ. РђРґСЂРµСЃ Р»РѕС‚РµСЂРµРё РІРѕР·СЊРјРёС‚Рµ РёР· `.move/config` РёР»Рё С‡РµРє-Р»РёСЃС‚Р° РґРµРїР»РѕСЏ. Р‘Р»Р°РіРѕРґР°СЂСЏ РЅР°С‡Р°Р»СЊРЅРѕРјСѓ `event::emit_event` СЃСЂР°Р·Сѓ РїРѕСЃР»Рµ `move_to` (СЃРј. РјРѕРґСѓР»Рё `LotteryRounds`, `TreasuryMulti`, `Autopurchase`) СЃС‡С‘С‚С‡РёРє РЅР°С‡РёРЅР°РµС‚СЃСЏ СЃ `0`, С‚Р°Рє С‡С‚Рѕ РјРѕРЅРёС‚РѕСЂРёРЅРі РЅРµ РїСЂРѕРїСѓСЃРєР°РµС‚ РїРµСЂРІС‹Рµ СЃРѕР±С‹С‚РёСЏ.
6. РџСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё РјРѕР¶РЅРѕ РІСЂРµРјРµРЅРЅРѕ Р·Р°РјРѕСЂРѕР·РёС‚СЊ primary store (РЅР°РїСЂРёРјРµСЂ, РЅР° РІСЂРµРјСЏ СЂР°СЃСЃР»РµРґРѕРІР°РЅРёСЏ РёРЅС†РёРґРµРЅС‚Р°) Рё Р·Р°С‚РµРј СЃРЅСЏС‚СЊ Р±Р»РѕРєРёСЂРѕРІРєСѓ:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::core_treasury_v1::set_store_frozen --args address:<ACCOUNT> bool:true"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::core_treasury_v1::set_store_frozen --args address:<ACCOUNT> bool:false"
   ```

7. РџРµСЂРµРґ РЅР°Р·РЅР°С‡РµРЅРёРµРј РїРѕР»СѓС‡Р°С‚РµР»РµР№ СЂР°СЃРїСЂРµРґРµР»РµРЅРёСЏ СѓР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ РЅР° РєР°Р¶РґРѕРј Р°РґСЂРµСЃРµ СЃРѕР·РґР°РЅ primary store С‡РµСЂРµР· `register_store_for` РёР»Рё `register_stores_for` Рё store РЅРµ Р·Р°РјРѕСЂРѕР¶РµРЅ (РїСЂРѕРІРµСЂСЊС‚Рµ `treasury_v1::account_extended_status`/`store_frozen`); Р·Р°С‚РµРј РІС‹РїРѕР»РЅРёС‚Рµ:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::core_treasury_v1::set_recipients --args address:<TREASURY_ADDR> address:<MARKETING_ADDR> address:<COMMUNITY_ADDR> address:<TEAM_ADDR> address:<PARTNERS_ADDR>"
   ```
   Р•СЃР»Рё РєР°РєРѕР№-С‚Рѕ Р°РґСЂРµСЃ РЅРµ РёРјРµРµС‚ Р·Р°СЂРµРіРёСЃС‚СЂРёСЂРѕРІР°РЅРЅРѕРіРѕ store, РєРѕРјР°РЅРґР° Р·Р°РІРµСЂС€РёС‚СЃСЏ РѕС€РёР±РєРѕР№ `E_RECIPIENT_STORE_NOT_REGISTERED`; РїСЂРё Р·Р°РјРѕСЂРѕР¶РµРЅРЅРѕРј store РІРµСЂРЅС‘С‚СЃСЏ СЃС‚Р°РЅРґР°СЂС‚РЅС‹Р№ `E_STORE_FROZEN` вЂ” РѕР±Р° С‚СЂРµР±РѕРІР°РЅРёСЏ СЃРѕРѕС‚РІРµС‚СЃС‚РІСѓСЋС‚ РїСЂР°РІРёР»Р°Рј Supra FA Рѕ РїРµСЂРµРІРѕРґР°С… С‚РѕР»СЊРєРѕ РјРµР¶РґСѓ РіРѕС‚РѕРІС‹РјРё С…СЂР°РЅРёР»РёС‰Р°РјРё.

8. РћР±РЅРѕРІРёС‚СЊ РґРѕР»Рё СЂР°СЃРїСЂРµРґРµР»РµРЅРёСЏ (СЃСѓРјРјР° basis points РґРѕР»Р¶РЅР° СЂР°РІРЅСЏС‚СЊСЃСЏ 10вЂЇ000):
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::core_treasury_v1::set_config --args u64:<BP_JACKPOT> u64:<BP_PRIZE> u64:<BP_TREASURY> u64:<BP_MARKETING> u64:<BP_COMMUNITY> u64:<BP_TEAM> u64:<BP_PARTNERS>"
   ```

### 3.2 РќР°СЃС‚СЂРѕР№РєР° РїРѕРґРїРёСЃРєРё Supra dVRF 3.0
> РњРѕРґСѓР»СЊ РґРµРїРѕР·РёС‚Р° Supra dVRF 3.0 СЂР°Р·РјРµС‰С‘РЅ РїРѕ Р°РґСЂРµСЃСѓ `0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit` Рё РёСЃРїРѕР»СЊР·СѓРµС‚ camelCase РёР· РѕС„РёС†РёР°Р»СЊРЅРѕР№ РґРѕРєСѓРјРµРЅС‚Р°С†РёРё Supra (`migrateClient`, `addClientToWhitelist`, `clientSettingMinimumBalance`, `depositFundClient`, ...). РћС€РёР±РєР° `FUNCTION_RESOLUTION_FAILURE` РѕР·РЅР°С‡Р°РµС‚, С‡С‚Рѕ СѓРєР°Р·Р°РЅ РЅРµРІРµСЂРЅС‹Р№ РёРґРµРЅС‚РёС„РёРєР°С‚РѕСЂ С„СѓРЅРєС†РёРё РёР»Рё Р°РґСЂРµСЃ РјРѕРґСѓР»СЏ. Р•СЃР»Рё Supra CLI РїСЂРѕРґРѕР»Р¶Р°РµС‚ РёСЃРєР°С‚СЊ `~/.aptos/config.yaml`, СЃРєРѕРїРёСЂСѓР№С‚Рµ РёСЃРїРѕР»СЊР·СѓРµРјС‹Р№ YAML-РїСЂРѕС„РёР»СЊ (РЅР°РїСЂРёРјРµСЂ, `/supra/configs/testnet.yaml`) РІ РєРѕРЅС‚РµР№РЅРµСЂ: `docker compose run --rm --entrypoint bash supra_cli -lc "mkdir -p /supra/.aptos && cp /supra/configs/testnet.yaml /supra/.aptos/config.yaml"`.
>
> РџРѕР»РЅС‹Р№ СЃРїСЂР°РІРѕС‡РЅРёРє РєРѕРјР°РЅРґ РјРѕРґСѓР»СЏ `deposit` РїСЂРёРІРµРґС‘РЅ РІ РѕС‚РґРµР»СЊРЅРѕРј РґРѕРєСѓРјРµРЅС‚Рµ [dvrf_deposit_cli_reference.md](./dvrf_deposit_cli_reference.md) вЂ” РёСЃРїРѕР»СЊР·СѓР№С‚Рµ РµРіРѕ, РµСЃР»Рё С‚СЂРµР±СѓРµС‚СЃСЏ РЅР°СЃС‚СЂРѕРёС‚СЊ Р»РёРјРёС‚С‹ РІСЂСѓС‡РЅСѓСЋ РёР»Рё РїСЂРѕРІРµСЂРёС‚СЊ СЃРѕС…СЂР°РЅС‘РЅРЅС‹Рµ Р·РЅР°С‡РµРЅРёСЏ РЅР° СЃС‚РѕСЂРѕРЅРµ Supra.
>
> Р’СЃРµ Python-СѓС‚РёР»РёС‚С‹ РїСЂРѕРµРєС‚Р° РјРѕР¶РЅРѕ Р·Р°РїСѓСЃРєР°С‚СЊ С‡РµСЂРµР· РµРґРёРЅС‹Р№ CLI: `python -m supra.scripts --list` РїРѕРєР°Р¶РµС‚ РґРѕСЃС‚СѓРїРЅС‹Рµ РїРѕРґРєРѕРјР°РЅРґС‹, Р° `python -m supra.scripts calc-min-balance ...`/`python -m supra.scripts manual-draw ...` СѓРїСЂРѕСЃС‚СЏС‚ РІС‹Р·РѕРІ СЂР°СЃС‡С‘С‚РѕРІ Рё Р°РІС‚РѕРјР°С‚РёР·Р°С†РёРё Р±РµР· РїСЂСЏРјРѕРіРѕ РѕР±СЂР°С‰РµРЅРёСЏ Рє С„Р°Р№Р»Р°Рј.

1. **РЎРєРѕРЅС„РёРіСѓСЂРёСЂСѓР№С‚Рµ Р»РёРјРёС‚С‹ РіР°Р·Р° РґР»СЏ VRF.** РџР°СЂР°РјРµС‚СЂС‹ СѓС‡Р°СЃС‚РІСѓСЋС‚ РІ СЂР°СЃС‡С‘С‚Рµ РґРµРїРѕР·РёС‚Р° Рё РїСЂРѕРІРµСЂРєР°С… whitelisting.
   ```bash
   docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli -lc 'cd /supra/SupraLottery && export SUPRA_PROFILE=<PROFILE> && PYTHONPATH=/supra/SupraLottery python3 -m supra.scripts.configure_vrf_gas --cli /supra/supra --profile $SUPRA_PROFILE --max-gas-price <MAX_GAS_PRICE> --max-gas-limit <MAX_GAS_LIMIT> --callback-gas-price <CALLBACK_GAS_PRICE> --callback-gas-limit <CALLBACK_GAS_LIMIT> --verification-gas-value <VERIFICATION_GAS_VALUE> --verbose'

   > РћРіСЂР°РЅРёС‡РµРЅРёСЏ Supra VRF subscription: `callback_gas_price` Рё `callback_gas_limit` РєРѕРЅС‚СЂР°РєС‚Р° РґРѕР»Р¶РЅС‹ Р±С‹С‚СЊ в‰¤ `max_gas_price`/`max_gas_limit` РїРѕРґРїРёСЃРєРё. РљРѕРЅС‚СЂР°РєС‚ Рё CLI РїСЂРѕРІРµСЂСЏСЋС‚ СЌС‚Рё РЅРµСЂР°РІРµРЅСЃС‚РІР° РїРµСЂРµРґ РІС‹РїРѕР»РЅРµРЅРёРµРј РєРѕРјР°РЅРґС‹.гЂђF:SupraLottery/supra/move_workspace/lottery/sources/Lottery.moveвЂ L700-L711гЂ‘гЂђF:SupraLottery/supra/scripts/configure_vrf_gas.pyвЂ L52-L65гЂ‘гЂђF:SupraLottery/docs/dvrf_reference_snapshot.mdвЂ L53-L60гЂ‘
   ```
   Р”РѕР¶РґРёС‚РµСЃСЊ СЃРѕР±С‹С‚РёСЏ `GasConfigUpdatedEvent`.

2. **Р Р°СЃСЃС‡РёС‚Р°Р№С‚Рµ РјРёРЅРёРјР°Р»СЊРЅС‹Р№ РґРµРїРѕР·РёС‚.** Р¤РѕСЂРјСѓР»Р° РёР· `lottery::core_main_v2::calculate_min_balance`:
   ```bash
   python - <<'PY'
   max_gas_price = <MAX_GAS_PRICE>
   max_gas_limit = <MAX_GAS_LIMIT>
   verification_gas = <VERIFICATION_GAS_VALUE>
   print(30 * max_gas_price * (max_gas_limit + verification_gas))
   PY
   ```
   РёР»Рё РІРѕСЃРїРѕР»СЊР·СѓР№С‚РµСЃСЊ СЃРєСЂРёРїС‚РѕРј `supra/scripts/calc_min_balance.py`, РєРѕС‚РѕСЂС‹Р№ РґРѕРїРѕР»РЅРёС‚РµР»СЊРЅРѕ РїРѕРєР°Р·С‹РІР°РµС‚ СЂРµРєРѕРјРµРЅРґРѕРІР°РЅРЅС‹Р№ РґРµРїРѕР·РёС‚ СЃ СѓС‡С‘С‚РѕРј Р·Р°РїР°СЃР°:
   ```bash
   python supra/scripts/calc_min_balance.py \
     --max-gas-price <MAX_GAS_PRICE> \
     --max-gas-limit <MAX_GAS_LIMIT> \
     --verification-gas <VERIFICATION_GAS_VALUE> \
     --margin 0.2
   ```
   Р РµРєРѕРјРµРЅРґСѓРµС‚СЃСЏ РґРѕР±Р°РІРёС‚СЊ 10вЂ“20вЂЇ% Р·Р°РїР°СЃР°, С‡С‚РѕР±С‹ РёСЃРєР»СЋС‡РёС‚СЊ `E_INITIAL_DEPOSIT_TOO_LOW` РїСЂРё СЂРѕСЃС‚Рµ РєРѕРјРёСЃСЃРёР№. РЎРѕР·РґР°РІР°СЏ РїРѕРґРїРёСЃРєСѓ, РїСЂРѕРІРµСЂСЏР№С‚Рµ, С‡С‚Рѕ РїРµСЂРµРґР°РІР°РµРјС‹Р№ РґРµРїРѕР·РёС‚ РЅРµ РјРµРЅСЊС€Рµ СЂР°СЃС‡С‘С‚РЅРѕРіРѕ Р·РЅР°С‡РµРЅРёСЏ вЂ” СЃРєСЂРёРїС‚ `testnet_migration.sh` РїСЂРµСЂС‹РІР°РµС‚ РІС‹РїРѕР»РЅРµРЅРёРµ, РµСЃР»Рё `INITIAL_DEPOSIT < MIN_BALANCE_LIMIT`.

3. **РЎРєРѕРїРёСЂСѓР№С‚Рµ CLI-РєРѕРЅС„РёРі РІРЅСѓС‚СЂСЊ РєРѕРЅС‚РµР№РЅРµСЂР° (РѕРґРЅРѕРєСЂР°С‚РЅРѕ Р·Р° СЃРµСЃСЃРёСЋ).** Supra CLI РёС‰РµС‚ `config.yaml` РІ `/supra/.aptos`. РЎРєРѕРїРёСЂСѓР№С‚Рµ РёСЃРїРѕР»СЊР·СѓРµРјС‹Р№ YAML-РїСЂРѕС„РёР»СЊ (РЅР°РїСЂРёРјРµСЂ, `supra/configs/testnet.yaml`) РІ РЅСѓР¶РЅРѕРµ РјРµСЃС‚Рѕ:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "mkdir -p /supra/.aptos && cp /supra/configs/testnet.yaml /supra/.aptos/config.yaml"
   ```
   РџРѕСЃР»Рµ РєРѕРїРёСЂРѕРІР°РЅРёСЏ РјРѕР¶РЅРѕ Р·Р°РїСѓСЃРєР°С‚СЊ РѕСЃС‚Р°Р»СЊРЅС‹Рµ РєРѕРјР°РЅРґС‹ Р±РµР· РїРѕРІС‚РѕСЂРЅРѕРіРѕ С€Р°РіР° (РґРѕ РїРµСЂРµР·Р°РїСѓСЃРєР° РєРѕРЅС‚РµР№РЅРµСЂР°).

4. **Р’С‹РїРѕР»РЅРёС‚Рµ СЂРµРіРёСЃС‚СЂР°С†РёСЋ РєР»РёРµРЅС‚Р° (`migrateClient`).** Supra С‚СЂРµР±СѓРµС‚, С‡С‚РѕР±С‹ РєР°Р¶РґС‹Р№ РєР»РёРµРЅС‚ РїСЂРѕС€С‘Р» РѕРЅР±РѕСЂРґРёРЅРі РґРѕ whitelisting вЂ” С„СѓРЅРєС†РёСЏ СЃРѕС…СЂР°РЅСЏРµС‚ Р»РёРјРёС‚С‹ РіР°Р·Р° Рё РІРѕР·РІСЂР°С‰Р°РµС‚ РѕС€РёР±РєСѓ `ECLIENT_ALREADY_EXIST`, РµСЃР»Рё РїСЂРѕС„РёР»СЊ СѓР¶Рµ РјРёРіСЂРёСЂРѕРІР°РЅ.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::migrateClient --args u128:<MAX_GAS_PRICE> u128:<MAX_GAS_LIMIT> --assume-yes"
   ```
   РЈР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ РІ РІС‹РІРѕРґРµ РїСЂРёСЃСѓС‚СЃС‚РІСѓРµС‚ `"status": "Success"`; РїСЂРё `FUNCTION_RESOLUTION_FAILURE` РїСЂРѕРІРµСЂСЊС‚Рµ Р°РґСЂРµСЃ РјРѕРґСѓР»СЏ Рё camelCase-РёРјСЏ С„СѓРЅРєС†РёРё.

5. **Р”РѕР±Р°РІСЊС‚Рµ РєР»РёРµРЅС‚Р° РІ whitelist РґРµРїРѕР·РёС‚Р°.** Р­С‚РѕС‚ С€Р°Рі Р°РєС‚РёРІРёСЂСѓРµС‚ РїРѕРґРїРёСЃРєСѓ РЅР° СЃС‚РѕСЂРѕРЅРµ Supra Рё РїРѕР·РІРѕР»СЏРµС‚ СЃРІСЏР·С‹РІР°С‚СЊ РєРѕРЅС‚СЂР°РєС‚С‹.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::addClientToWhitelist --args u128:<MAX_GAS_PRICE> u128:<MAX_GAS_LIMIT> --assume-yes"
   ```
   Р•СЃР»Рё РєРѕРјР°РЅРґР° РІРѕР·РІСЂР°С‰Р°РµС‚ `ECLIENT_NOT_EXIST`, РїРѕРІС‚РѕСЂРёС‚Рµ `migrateClient` Рё СЃРІРµСЂСЊС‚Рµ Р»РёРјРёС‚С‹ РіР°Р·Р°; РёРЅРѕРіРґР° Supra Р°РєС‚РёРІРёСЂСѓРµС‚ Р°РґСЂРµСЃ СЃ Р·Р°РґРµСЂР¶РєРѕР№ вЂ” РІ С‚Р°РєРѕРј СЃР»СѓС‡Р°Рµ РґРѕР¶РґРёС‚РµСЃСЊ РїРѕРґС‚РІРµСЂР¶РґРµРЅРёСЏ РѕС‚ РїРѕРґРґРµСЂР¶РєРё.

6. **РЎРѕР·РґР°Р№С‚Рµ РїРѕРґРїРёСЃРєСѓ Рё РїРѕРїРѕР»РЅРёС‚Рµ РґРµРїРѕР·РёС‚.** Р—РЅР°С‡РµРЅРёРµ `<INITIAL_DEPOSIT>` РґРѕР»Р¶РЅРѕ Р±С‹С‚СЊ в‰Ґ СЂР°СЃСЃС‡РёС‚Р°РЅРЅРѕРіРѕ РјРёРЅРёРјСѓРјР°.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id lottery::core_main_v2::create_subscription --args u64:<INITIAL_DEPOSIT> --assume-yes"
   ```
   Р¤СѓРЅРєС†РёСЏ РІС‹Р·С‹РІР°РµС‚ `deposit::clientSettingMinimumBalance`, `deposit::depositFundClient` Рё `deposit::addContractToWhitelist`, Р° СЃРѕР±С‹С‚РёРµ `SubscriptionConfiguredEvent` С„РёРєСЃРёСЂСѓРµС‚ РїР°СЂР°РјРµС‚СЂС‹.

   > Р•СЃР»Рё `create_subscription` Р·Р°РІРµСЂС€РёР»Р°СЃСЊ РѕС€РёР±РєРѕР№ `ECLIENT_NOT_EXIST`, Р·РЅР°С‡РёС‚ Supra РµС‰С‘ РЅРµ Р·Р°С„РёРєСЃРёСЂРѕРІР°Р»Р° РІР°С€ РєР»РёРµРЅС‚. РџРѕРІС‚РѕСЂРёС‚Рµ С€Р°РіРё 4вЂ“5 РїРѕР·РґРЅРµРµ; РјРµР¶РґСѓ РѕРЅР±РѕСЂРґРёРЅРіРѕРј Рё whitelisting РјРѕР¶РµС‚ РїРѕС‚СЂРµР±РѕРІР°С‚СЊСЃСЏ РґРѕ РЅРµСЃРєРѕР»СЊРєРёС… РјРёРЅСѓС‚.

   РљРѕРЅС‚СЂР°РєС‚ РїСЂРё СЌС‚РѕРј СЃРѕС…СЂР°РЅСЏРµС‚ client/consumer snapshots, РїРѕСЌС‚РѕРјСѓ РїРѕРІС‚РѕСЂРЅС‹Рµ РІС‹Р·РѕРІС‹ `lottery::core_main_v2::configure_vrf_gas` Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєРё РІС‹Р·С‹РІР°СЋС‚ `deposit::updateMaxGasPrice/Limit` Рё `deposit::updateCallbackGasPrice/Limit`, РєРѕРіРґР° СЃРЅР°РїС€РѕС‚С‹ РїСЂРёСЃСѓС‚СЃС‚РІСѓСЋС‚.

7. **(РћРїС†РёРѕРЅР°Р»СЊРЅРѕ) СЃРёРЅС…СЂРѕРЅРёР·РёСЂСѓР№С‚Рµ РјРёРЅРёРјР°Р»СЊРЅС‹Р№ Р±Р°Р»Р°РЅСЃ РІСЂСѓС‡РЅСѓСЋ.** РСЃРїРѕР»СЊР·СѓР№С‚Рµ РїСЂРё РёР·РјРµРЅРµРЅРёРё Р»РёРјРёС‚РѕРІ РіР°Р·Р° РЅР° СЃС‚РѕСЂРѕРЅРµ Supra.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id lottery::core_main_v2::set_minimum_balance --assume-yes"
   ```

8. **Р—Р°С„РёРєСЃРёСЂСѓР№С‚Рµ СЃРЅР°РїС€РѕС‚С‹ whitelisting РґР»СЏ Р°СѓРґРёС‚Р°.**
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id lottery::core_main_v2::record_client_whitelist_snapshot --args u128:<MAX_GAS_PRICE> u128:<MAX_GAS_LIMIT> u128:<MIN_BALANCE_LIMIT>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id lottery::core_main_v2::record_consumer_whitelist_snapshot --args u128:<CALLBACK_GAS_PRICE> u128:<CALLBACK_GAS_LIMIT>"
   ```

9. **РЈРїСЂР°РІР»РµРЅРёРµ РґРµРїРѕР·РёС‚РѕРј РЅР°РїСЂСЏРјСѓСЋ (РїСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё).** Р’СЃРµ С„СѓРЅРєС†РёРё РїСЂРёРЅРёРјР°СЋС‚ camelCase-РёРјРµРЅР° РїСЂРё РІС‹Р·РѕРІРµ С‡РµСЂРµР· Supra CLI. РџРѕСЃР»Рµ С‚РѕРіРѕ РєР°Рє СЃРЅР°РїС€РѕС‚С‹ whitelisting Р·Р°С„РёРєСЃРёСЂРѕРІР°РЅС‹, РєРѕРЅС‚СЂР°РєС‚ СЃР°Рј СЃРёРЅС…СЂРѕРЅРёР·РёСЂСѓРµС‚ `deposit::update*` РїСЂРё РёР·РјРµРЅРµРЅРёРё РєРѕРЅС„РёРіСѓСЂР°С†РёРё, РїРѕСЌС‚РѕРјСѓ СЌС‚Рё РєРѕРјР°РЅРґС‹ РЅСѓР¶РЅС‹ С‚РѕР»СЊРєРѕ РєР°Рє СЂРµР·РµСЂРІРЅС‹Р№ СЃС†РµРЅР°СЂРёР№.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::clientSettingMinimumBalance --args u128:<MIN_BALANCE> --assume-yes"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::depositFundClient --args u64:<DEPOSIT> --assume-yes"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::addContractToWhitelist --args address:<LOTTERY_ADDR> u128:<CALLBACK_GAS_PRICE> u128:<CALLBACK_GAS_LIMIT> --assume-yes"
   ```
   Р­С‚Рё РєРѕРјР°РЅРґС‹ РїСЂРёРіРѕРґСЏС‚СЃСЏ РїСЂРё РєРѕСЂСЂРµРєС‚РёСЂРѕРІРєРµ РїР°СЂР°РјРµС‚СЂРѕРІ РЅР°РїСЂСЏРјСѓСЋ РІ РјРѕРґСѓР»Рµ РґРµРїРѕР·РёС‚Р°.

10. **РџСЂРѕРІРµСЂСЊС‚Рµ РЅР°СЃС‚СЂРѕР№РєРё РґРµРїРѕР·РёС‚Р° РїРѕСЃР»Рµ РѕРЅР±РѕСЂРґРёРЅРіР°.** РњРѕРґСѓР»СЊ `deposit` РїСЂРµРґРѕСЃС‚Р°РІР»СЏРµС‚ view-С„СѓРЅРєС†РёРё РґР»СЏ Р°СѓРґРёС‚Р° Р»РёРјРёС‚РѕРІ РіР°Р·Р° Рё РјРёРЅРёРјР°Р»СЊРЅРѕРіРѕ Р±Р°Р»Р°РЅСЃР°. РљРѕРјР°РЅРґС‹ РІРѕР·РІСЂР°С‰Р°СЋС‚ JSON-СЃС‚СЂСѓРєС‚СѓСЂСѓ; РїСЂРё РѕС€РёР±РєРµ `FUNCTION_RESOLUTION_FAILURE` СѓР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ РёСЃРїРѕР»СЊР·СѓРµС‚Рµ camelCase Рё Р°РєС‚СѓР°Р»СЊРЅС‹Р№ Р°РґСЂРµСЃ РјРѕРґСѓР»СЏ.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::checkMinBalanceClient --args address:<CLIENT_ADDR>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::checkMaxGasPriceClient --args address:<CLIENT_ADDR>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::checkMaxGasLimitClient --args address:<CLIENT_ADDR>"
   ```
   Р”Р»СЏ РїСЂРѕРІРµСЂРєРё РєРѕРЅРєСЂРµС‚РЅРѕРіРѕ РєРѕРЅС‚СЂР°РєС‚Р° РёСЃРїРѕР»СЊР·СѓР№С‚Рµ `deposit::getContractDetails`:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::getContractDetails --args address:<LOTTERY_ADDR>"
   ```
   Р§С‚РѕР±С‹ РѕС†РµРЅРёС‚СЊ С‚РµРєСѓС‰РёР№ Р±Р°Р»Р°РЅСЃ РґРµРїРѕР·РёС‚Р° Рё whitelisting, РІС‹РїРѕР»РЅРёС‚Рµ РґРѕРїРѕР»РЅРёС‚РµР»СЊРЅС‹Рµ view-РєРѕРјР°РЅРґС‹:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::checkClientFund --args address:<CLIENT_ADDR>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::isMinimumBalanceReached --args address:<CLIENT_ADDR>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::countTotalWhitelistedContractByClient --args address:<CLIENT_ADDR>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::listAllWhitelistedContractByClient --args address:<CLIENT_ADDR>"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id 0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit::getSubscriptionInfoByClient --args address:<CLIENT_ADDR>"
   ```
   РћС‚РІРµС‚С‹ РїРѕРєР°Р¶СѓС‚ С‚РµРєСѓС‰РёР№ Р±Р°Р»Р°РЅСЃ, РґРѕСЃС‚РёР¶РµРЅРёРµ РјРёРЅРёРјР°Р»СЊРЅРѕРіРѕ Р»РёРјРёС‚Р° Рё СЃРїРёСЃРѕРє whitelisted РєРѕРЅС‚СЂР°РєС‚РѕРІ Supra.

   РџРѕСЃР»Рµ РЅР°Р·РЅР°С‡РµРЅРёСЏ Р°РіСЂРµРіР°С‚РѕСЂР° Supra РїСЂРѕРІРµСЂСЊС‚Рµ, С‡С‚Рѕ VRF-С…Р°Р± Р·Р°С„РёРєСЃРёСЂРѕРІР°Р» СЃРѕР±С‹С‚РёРµ Рё view:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events list --profile <PROFILE> --address @vrf_hub --event-type @vrf_hub::hub::CallbackSenderUpdatedEvent --limit 5"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id @vrf_hub::hub::get_callback_sender_status"
   ```
   JSON-РѕС‚РІРµС‚ РґРѕР»Р¶РµРЅ СЃРѕРґРµСЂР¶Р°С‚СЊ `"current": "Some(<AGGREGATOR_ADDR>)"`; РµСЃР»Рё РїСЂРёС…РѕРґРёС‚ `None`, РїРѕРІС‚РѕСЂРЅРѕ РІС‹Р·РѕРІРёС‚Рµ `hub::set_callback_sender` Рё СѓР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ С‚СЂР°РЅР·Р°РєС†РёСЏ РїСЂРѕС€Р»Р° Р±РµР· РѕС€РёР±РѕРє.

11. **РЈРґР°Р»РµРЅРёРµ РєРѕРЅС‚СЂР°РєС‚Р° РёР· РїРѕРґРїРёСЃРєРё.** РџРµСЂРµРґ СѓРґР°Р»РµРЅРёРµРј СѓР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ РІ Р»РѕС‚РµСЂРµРµ РЅРµС‚ Р°РєС‚РёРІРЅРѕРіРѕ `pending_request` (СЃРєСЂРёРїС‚ РїСЂРѕРІРµСЂРёС‚ СЌС‚Рѕ Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєРё). Р‘С‹СЃС‚СЂС‹Р№ РїСѓС‚СЊ вЂ” РёСЃРїРѕР»СЊР·РѕРІР°С‚СЊ СѓРЅРёС„РёС†РёСЂРѕРІР°РЅРЅС‹Р№ CLI:
    ```bash
    python -m supra.scripts remove-subscription \
      --profile $PROFILE \
      --lottery-addr $LOTTERY_ADDR \
      --deposit-addr $DEPOSIT_ADDR \
      --supra-cli-bin /supra/supra \
      --supra-config $SUPRA_CONFIG
    ```
    РЎРєСЂРёРїС‚ РІС‹Р·С‹РІР°РµС‚ `lottery::core_main_v2::remove_subscription`, РїСѓР±Р»РёРєСѓРµС‚ СЃРѕР±С‹С‚РёРµ `SubscriptionContractRemovedEvent` Рё РїСЂРѕРєСЃРёСЂСѓРµС‚ `deposit::removeContractFromWhitelist`. РџРѕСЃР»Рµ СѓРґР°Р»РµРЅРёСЏ СЃРЅР°РїС€РѕС‚С‹ client/consumer СЃР±С€РёРІР°СЋС‚СЃСЏ, С‚Р°Рє С‡С‚Рѕ РїРѕСЃР»РµРґСѓСЋС‰РёРµ `configure_vrf_gas` РЅРµ С‚СЂРѕРіР°СЋС‚ РґРµРїРѕР·РёС‚ РґРѕ РЅРѕРІРѕР№ РїРѕРґРїРёСЃРєРё. РџСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё РјРѕР¶РЅРѕ РІС‹РїРѕР»РЅРёС‚СЊ РєРѕРјР°РЅРґСѓ РЅР°РїСЂСЏРјСѓСЋ С‡РµСЂРµР· Supra CLI:
    ```bash
    docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id lottery::core_main_v2::remove_subscription --assume-yes"
    ```
    РСЃРїРѕР»СЊР·СѓР№С‚Рµ РѕРїС†РёСЋ `--allow-pending-request`, С‚РѕР»СЊРєРѕ РµСЃР»Рё РѕСЃРѕР·РЅР°РЅРЅРѕ Р·Р°РІРµСЂС€Р°РµС‚Рµ РєРѕРЅС‚СЂР°РєС‚ СЃ Р°РєС‚РёРІРЅС‹РјРё Р·Р°РїСЂРѕСЃР°РјРё (РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ РѕРїРµСЂР°С†РёСЏ Р±Р»РѕРєРёСЂСѓРµС‚СЃСЏ).
12. **РџСЂРѕРІРµСЂРєР° Р°РґСЂРµСЃРѕРІ Рё СЃС‚Р°С‚СѓСЃР° РїСѓР»РѕРІ `treasury_multi`.** РџРѕСЃР»Рµ РёРЅРёС†РёР°Р»РёР·Р°С†РёРё РєР°Р·РЅР°С‡РµР№СЃС‚РІР° РІС‹РїРѕР»РЅРёС‚Рµ view-РєРѕРјР°РЅРґС‹, С‡С‚РѕР±С‹ СѓР±РµРґРёС‚СЊСЃСЏ, С‡С‚Рѕ РёСЃРїРѕР»СЊР·СѓСЋС‚СЃСЏ РѕР¶РёРґР°РµРјС‹Рµ Р°РґСЂРµСЃР° РґР¶РµРєРїРѕС‚Р°/РѕРїРµСЂР°С†РёРѕРЅРЅРѕРіРѕ РїСѓР»Р° Рё С‡С‚Рѕ РґР»СЏ РЅРёС… Р·Р°СЂРµРіРёСЃС‚СЂРёСЂРѕРІР°РЅС‹ primary store Р±РµР· freeze:
    ```bash
    docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::treasury_multi::get_recipients"
    docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::treasury_multi::get_recipient_statuses"
    ```
    РџРѕР»Рµ `recipient` РґРѕР»Р¶РЅРѕ СЃРѕРІРїР°РґР°С‚СЊ СЃ РѕР¶РёРґР°РµРјС‹РјРё Р°РґСЂРµСЃР°РјРё, Р° С„Р»Р°РіРё `registered=true` Рё `frozen=false` РїРѕРґС‚РІРµСЂР¶РґР°СЋС‚ РіРѕС‚РѕРІРЅРѕСЃС‚СЊ primary store. Р—РЅР°С‡РµРЅРёРµ `balance` РѕС‚СЂР°Р¶Р°РµС‚ Р°РєС‚СѓР°Р»СЊРЅС‹Рµ РІС‹РїР»Р°С‚С‹ Supra FA РґР»СЏ РєР°Р¶РґРѕРіРѕ РїСѓР»Р°. Р”РѕРїРѕР»РЅРёС‚РµР»СЊРЅРѕ РѕС‚СЃР»РµР¶РёРІР°Р№С‚Рµ СЃРѕР±С‹С‚РёСЏ `lottery::core_treasury_v1::RecipientsUpdatedEvent` Рё `lottery::treasury_multi::RecipientsUpdatedEvent` РІ Supra Explorer РёР»Рё Р»РѕРіР°С… CLI вЂ” РѕР±Р° СЃРѕР±С‹С‚РёСЏ РїСѓР±Р»РёРєСѓСЋС‚ СЃРЅР°РїС€РѕС‚С‹ `RecipientStatus` РїСЂРё РёРЅРёС†РёР°Р»РёР·Р°С†РёРё Рё РєР°Р¶РґРѕР№ СЃРјРµРЅРµ РїРѕР»СѓС‡Р°С‚РµР»РµР№, РїСЂРёС‡С‘Рј `treasury_v1` С‚РµРїРµСЂСЊ РІС‹РІРѕРґРёС‚ РїР°СЂС‹ В«РїСЂРµРґС‹РґСѓС‰РµРµ в†’ С‚РµРєСѓС‰РµРµВ» СЃРѕСЃС‚РѕСЏРЅРёСЏ РЅР°РїСЂР°РІР»РµРЅРёР№, С‡С‚РѕР±С‹ РјРѕР¶РЅРѕ Р±С‹Р»Рѕ СЃСЂР°РІРЅРёС‚СЊ СЃС‚Р°СЂС‹Р№ Рё РЅРѕРІС‹Р№ РєРѕРЅС„РёРі РїРѕ freeze-С„Р»Р°РіР°Рј Рё Р±Р°Р»Р°РЅСЃР°Рј.
    Р•СЃР»Рё `withdraw_operations`, `pay_operations_bonus_internal` РёР»Рё `distribute_jackpot` Р·Р°РІРµСЂС€Р°СЋС‚СЃСЏ СЃ РєРѕРґР°РјРё `14`, `15`, `16`, `17` РёР»Рё `18`, РїРѕРІС‚РѕСЂРЅРѕ Р·Р°СЂРµРіРёСЃС‚СЂРёСЂСѓР№С‚Рµ store С‡РµСЂРµР· `treasury_v1::register_store_for` Рё СЃРЅРёРјРёС‚Рµ freeze (`treasury_v1::set_store_frozen`), Р·Р°С‚РµРј РїРѕРІС‚РѕСЂРёС‚Рµ РІС‹РїР»Р°С‚Сѓ.

**РЎРЅР°РїС€РѕС‚ С„Р°Р±СЂРёРєРё Р»РѕС‚РµСЂРµР№.** Р”Р»СЏ Р°СѓРґРёС‚Р° Supra РІС‹РіСЂСѓР·РёС‚Рµ С‚РµРєСѓС‰РµРµ СЃРѕСЃС‚РѕСЏРЅРёРµ С„Р°Р±СЂРёРєРё: СЃРЅР°РїС€РѕС‚ `lottery_factory::registry::get_registry_snapshot` РІРѕР·РІСЂР°С‰Р°РµС‚ Р°РґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂР° Рё РІСЃРµ Р·Р°СЂРµРіРёСЃС‚СЂРёСЂРѕРІР°РЅРЅС‹Рµ Р»РѕС‚РµСЂРµРё СЃ С†РµРЅРѕР№ Р±РёР»РµС‚Р° Рё РґРѕР»РµР№ РґР¶РµРєРїРѕС‚Р°, Р° `list_lottery_ids` РїРѕРєР°Р·С‹РІР°РµС‚ С‚РѕР»СЊРєРѕ РёРґРµРЅС‚РёС„РёРєР°С‚РѕСЂС‹.

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery_factory::registry::get_registry_snapshot"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery_factory::registry::list_lottery_ids"
```

**РЎРЅР°РїС€РѕС‚ СЌРєР·РµРјРїР»СЏСЂРѕРІ Р»РѕС‚РµСЂРµР№.** РџРѕСЃР»Рµ СЃРѕР·РґР°РЅРёСЏ РёР»Рё РѕР±РЅРѕРІР»РµРЅРёСЏ СЌРєР·РµРјРїР»СЏСЂРѕРІ РїСЂРѕРІРµСЂСЊС‚Рµ Р°РіСЂРµРіРёСЂРѕРІР°РЅРЅРѕРµ СЃРѕР±С‹С‚РёРµ Рё view, С‡С‚РѕР±С‹ Supra РІРёРґРµР»Р° Р°РєС‚СѓР°Р»СЊРЅС‹Рµ РїР°СЂР°РјРµС‚СЂС‹ (Р°РґСЂРµСЃР° РєРѕРЅС‚СЂР°РєС‚РѕРІ, РІР»Р°РґРµР»СЊС†С‹, С†РµРЅС‹ Р±РёР»РµС‚РѕРІ, РґРѕР»Рё РґР¶РµРєРїРѕС‚Р°, РїСЂРѕРґР°Р¶Рё Рё СЃС‚Р°С‚СѓСЃ Р°РєС‚РёРІРЅРѕСЃС‚Рё):

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events list --profile <PROFILE> --address @lottery --event-type lottery::instances::LotteryInstancesSnapshotUpdatedEvent --limit 5"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::instances::get_instances_snapshot"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::instances::get_instance_snapshot --args u64:<LOTTERY_ID>"
```

РЈР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ РІ СЃРѕР±С‹С‚РёРё/JSON СѓРєР°Р·Р°РЅС‹ `admin` (Р°РґСЂРµСЃ СѓРїСЂР°РІР»СЏСЋС‰РµРіРѕ @lottery), `hub` (С‚РµРєСѓС‰РёР№ VRF-С…Р°Р±), Р° С‚Р°РєР¶Рµ РјР°СЃСЃРёРІ `instances`, РіРґРµ РґР»СЏ РєР°Р¶РґРѕРіРѕ `lottery_id` РѕС‚РѕР±СЂР°Р¶Р°СЋС‚СЃСЏ `owner`, Р°РґСЂРµСЃ РєРѕРЅС‚СЂР°РєС‚Р° `lottery`, `ticket_price`, `jackpot_share_bps`, РЅР°РєРѕРїР»РµРЅРЅС‹Рµ `tickets_sold`, `jackpot_accumulated` Рё С„Р»Р°Рі `active`. Р•СЃР»Рё РґР°РЅРЅС‹Рµ РЅРµ РѕР±РЅРѕРІРёР»РёСЃСЊ, РїРѕРІС‚РѕСЂРёС‚Рµ `create_instance`, `sync_blueprint` РёР»Рё СЃРёРЅС…СЂРѕРЅРёР·Р°С†РёСЋ СЃС‚Р°С‚СѓСЃР° (`set_instance_active`), С‡С‚РѕР±С‹ РјРѕРґСѓР»СЊ РѕРїСѓР±Р»РёРєРѕРІР°Р» СЃРІРµР¶РёР№ `LotteryInstancesSnapshotUpdatedEvent`.

**РЎРЅР°РїС€РѕС‚ РІРёС‚СЂРёРЅРЅС‹С… РјРµС‚Р°РґР°РЅРЅС‹С….** РџРѕСЃР»Рµ Р·Р°РіСЂСѓР·РєРё РѕРїРёСЃР°РЅРёР№ РІС‹Р·РѕРІРёС‚Рµ view `lottery::metadata::get_metadata_snapshot`, С‡С‚РѕР±С‹ СѓР±РµРґРёС‚СЊСЃСЏ, С‡С‚Рѕ Supra CLI Рё РїР°РЅРµР»Рё РјРѕРЅРёС‚РѕСЂРёРЅРіР° СѓРІРёРґСЏС‚ Р°РєС‚СѓР°Р»СЊРЅРѕРіРѕ Р°РґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂР° Рё СЃРїРёСЃРѕРє `MetadataEntry`:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::metadata::get_metadata_snapshot"
```

РљРѕРјР°РЅРґР° РІРµСЂРЅС‘С‚ JSON СЃ РїРѕР»СЏРјРё `admin` Рё `entries`; РєР°Р¶РґС‹Р№ СЌР»РµРјРµРЅС‚ `entries[i]` СЃРѕРґРµСЂР¶РёС‚ `lottery_id` Рё РІСЃРµ С‚РµРєСЃС‚РѕРІС‹Рµ РїРѕР»СЏ (`title`, `description`, `image_uri`, `website_uri`, `rules_uri`). РџСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё СЃСЂР°РІРЅРёС‚Рµ СЂРµР·СѓР»СЊС‚Р°С‚ СЃ СЃРѕР±С‹С‚РёРµРј `MetadataSnapshotUpdatedEvent`, РёСЃРїРѕР»СЊР·СѓСЏ `move tool events list` РґР»СЏ Р°РґСЂРµСЃР° Р»РѕС‚РµСЂРµРё.

**РЎРЅР°РїС€РѕС‚ РёСЃС‚РѕСЂРёРё СЂРѕР·С‹РіСЂС‹С€РµР№.** Supra РѕР¶РёРґР°РµС‚ Р°РіСЂРµРіРёСЂРѕРІР°РЅРЅС‹Р№ Р¶СѓСЂРЅР°Р» draw, РїРѕСЌС‚РѕРјСѓ РїРѕСЃР»Рµ fulfill РёР»Рё РѕС‡РёСЃС‚РєРё РёСЃС‚РѕСЂРёРё СЃСЂР°РІРЅРёС‚Рµ СЃРѕР±С‹С‚РёРµ Рё view:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events list --profile <PROFILE> --address @lottery --event-type lottery::history::HistorySnapshotUpdatedEvent --limit 5"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::history::get_history_snapshot"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::history::get_lottery_snapshot --args u64:<LOTTERY_ID>"
```

РЈР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ РІ СЃРѕР±С‹С‚РёРё Рё JSON СѓРєР°Р·Р°РЅС‹ `admin`, РїРѕР»РЅС‹Р№ СЃРїРёСЃРѕРє `lottery_ids` Рё РјР°СЃСЃРёРІ `histories`, РіРґРµ РєР°Р¶РґР°СЏ Р·Р°РїРёСЃСЊ СЃРѕРґРµСЂР¶РёС‚ `lottery_id` Рё РјР°СЃСЃРёРІ `records` СЃ `request_id`, `winner`, `ticket_index`, `prize_amount`, `random_bytes` Рё `timestamp_seconds`. Р•СЃР»Рё СЃРЅР°РїС€РѕС‚ РѕС‚СЃСѓС‚СЃС‚РІСѓРµС‚, РёРЅРёС†РёРёСЂСѓР№С‚Рµ `lottery::core_rounds::fulfill_draw` РёР»Рё РІС‹Р·РѕРІРёС‚Рµ `history::clear_history`, С‡С‚РѕР±С‹ РјРѕРґСѓР»СЊ РѕРїСѓР±Р»РёРєРѕРІР°Р» Р°РєС‚СѓР°Р»СЊРЅРѕРµ СЃРѕСЃС‚РѕСЏРЅРёРµ.

**РЎРЅР°РїС€РѕС‚ Р°РІС‚РѕРїРѕРєСѓРїРєРё Р±РёР»РµС‚РѕРІ.** Р”Р»СЏ РєРѕРЅС‚СЂРѕР»СЏ Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєРёС… РїР»Р°РЅРѕРІ Supra С‚СЂРµР±СѓРµС‚ Р°РіСЂРµРіРёСЂРѕРІР°РЅРЅРѕРіРѕ СЃРѕР±С‹С‚РёСЏ Рё view:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events list --profile <PROFILE> --address @lottery --event-type lottery::autopurchase::AutopurchaseSnapshotUpdatedEvent --limit 5"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::autopurchase::get_autopurchase_snapshot"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::autopurchase::get_lottery_snapshot --args u64:<LOTTERY_ID>"
```

Р’ СЃРѕР±С‹С‚РёРё Рё РѕС‚РІРµС‚Рµ view РїСЂРѕРІРµСЂСЊС‚Рµ РїРѕР»Рµ `admin`, СЃСѓРјРјР°СЂРЅС‹Р№ `total_balance`, РєРѕР»РёС‡РµСЃС‚РІРѕ РёРіСЂРѕРєРѕРІ Рё РјР°СЃСЃРёРІ `players`: РєР°Р¶РґС‹Р№ СЌР»РµРјРµРЅС‚ СЃРѕРґРµСЂР¶РёС‚ Р°РґСЂРµСЃ, Р±Р°Р»Р°РЅСЃ, `tickets_per_draw` Рё С„Р»Р°Рі `active`. Р•СЃР»Рё СЃРЅР°РїС€РѕС‚ РѕС‚СЃСѓС‚СЃС‚РІСѓРµС‚, РІС‹РїРѕР»РЅРёС‚Рµ `configure_plan`/`deposit` РёР»Рё С‚РµСЃС‚РѕРІРѕРµ `execute`, С‡С‚РѕР±С‹ РјРѕРґСѓР»СЊ РѕРїСѓР±Р»РёРєРѕРІР°Р» Р°РєС‚СѓР°Р»СЊРЅС‹Рµ РґР°РЅРЅС‹Рµ.

**РЎРЅР°РїС€РѕС‚ NFT-Р±РµР№РґР¶РµР№.** Supra РїСЂРѕСЃРёР»Р° РїСѓР±Р»РёРєРѕРІР°С‚СЊ Р°РіСЂРµРіРёСЂРѕРІР°РЅРЅРѕРµ СЃРѕСЃС‚РѕСЏРЅРёРµ РЅР°РіСЂР°Рґ, РїРѕСЌС‚РѕРјСѓ РїСЂРѕРІРµСЂСЏР№С‚Рµ РєР°Рє view, С‚Р°Рє Рё РїРѕС‚РѕРє СЃРѕР±С‹С‚РёР№:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery_rewards::rewards_nft::get_snapshot"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery_rewards::rewards_nft::get_owner_snapshot --args address:<PLAYER_ADDR>"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events list --profile <PROFILE> --address @lottery --event-type lottery_rewards::rewards_nft::NftRewardsSnapshotUpdatedEvent --limit 5"
```

View `get_snapshot` РІРѕР·РІСЂР°С‰Р°РµС‚ Р°РґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂР°, `next_badge_id` Рё РјР°СЃСЃРёРІ РІР»Р°РґРµР»СЊС†РµРІ СЃ РёС… `BadgeSnapshot` (Р»РѕС‚РµСЂРµСЏ, СЂРѕР·С‹РіСЂС‹С€, URI РјРµС‚Р°РґР°РЅРЅС‹С…, Р°РґСЂРµСЃ РјРёРЅС‚РµСЂР°). `get_owner_snapshot` РїРѕР·РІРѕР»СЏРµС‚ РїСЂРѕРІРµСЂСЏС‚СЊ РєРѕРЅРєСЂРµС‚РЅРѕРіРѕ РёРіСЂРѕРєР°, Р° СЃРѕР±С‹С‚РёРµ `NftRewardsSnapshotUpdatedEvent` РїСѓР±Р»РёРєСѓРµС‚СЃСЏ РїРѕСЃР»Рµ `init`, `mint_badge` Рё `burn_badge`. Р•СЃР»Рё РїРѕСЃР»Рµ Р±С‘СЂРЅР° РІР»Р°РґРµР»РµС† РїРѕ-РїСЂРµР¶РЅРµРјСѓ С‡РёСЃР»РёС‚СЃСЏ СЃ Р±РµР№РґР¶Р°РјРё, СѓР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ С‚СЂР°РЅР·Р°РєС†РёСЏ Р·Р°РІРµСЂС€РёР»Р°СЃСЊ СѓСЃРїРµС€РЅРѕ Рё РїРѕРІС‚РѕСЂРёС‚Рµ РєРѕРјР°РЅРґСѓ РґР»СЏ РѕС‡РёСЃС‚РєРё СЃРѕСЃС‚РѕСЏРЅРёСЏ.

**РЎРЅР°РїС€РѕС‚ РіР»РѕР±Р°Р»СЊРЅРѕРіРѕ РґР¶РµРєРїРѕС‚Р°.** РџРѕСЃР»Рµ РІС‹РґР°С‡Рё Р±РёР»РµС‚РѕРІ, РїР»Р°РЅРёСЂРѕРІР°РЅРёСЏ СЂРѕР·С‹РіСЂС‹С€Р° РёР»Рё РІС‹РїРѕР»РЅРµРЅРёСЏ РєРѕР»Р±СЌРєР° РїСЂРѕРІРµСЂСЊС‚Рµ, С‡С‚Рѕ Supra С„РёРєСЃРёСЂСѓРµС‚ Р°РіСЂРµРіРёСЂРѕРІР°РЅРЅС‹Р№ СЃРЅРёРјРѕРє Рё view РІРѕР·РІСЂР°С‰Р°РµС‚ С‚Рµ Р¶Рµ Р·РЅР°С‡РµРЅРёСЏ:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events list --profile <PROFILE> --address @lottery --event-type lottery::jackpot::JackpotSnapshotUpdatedEvent --limit 5"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::jackpot::get_snapshot"
```

РЈР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ РІ СЃРѕР±С‹С‚РёРё Рё JSON РїРѕР»СЏ `admin` Рё `lottery_id` СЃРѕРІРїР°РґР°СЋС‚ СЃ РѕР¶РёРґР°РЅРёСЏРјРё, `ticket_count` РѕС‚СЂР°Р¶Р°РµС‚ РєРѕР»РёС‡РµСЃС‚РІРѕ РІС‹РґР°РЅРЅС‹С… Р±РёР»РµС‚РѕРІ, `draw_scheduled` СЃРѕРѕС‚РІРµС‚СЃС‚РІСѓРµС‚ С‚РµРєСѓС‰РµРјСѓ СЃС‚Р°С‚СѓСЃСѓ РїРѕРґРіРѕС‚РѕРІРєРё, Р° `pending_request_id` РїРѕСЏРІР»СЏРµС‚СЃСЏ С‚РѕР»СЊРєРѕ РїРѕСЃР»Рµ `request_randomness` Рё РѕР±РЅСѓР»СЏРµС‚СЃСЏ РїРѕСЃР»Рµ `fulfill_draw`.

**РЎРЅР°РїС€РѕС‚ VIP-РїРѕРґРїРёСЃРѕРє.** РџРѕСЃР»Рµ РѕР±РЅРѕРІР»РµРЅРёСЏ РєРѕРЅС„РёРіСѓСЂР°С†РёР№ РёР»Рё РѕРїРµСЂР°С†РёР№ СѓР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ Supra CLI РІРёРґРёС‚ Р°РіСЂРµРіРёСЂРѕРІР°РЅРЅС‹Рµ РґР°РЅРЅС‹Рµ:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events list --profile <PROFILE> --address @lottery --event-type lottery::vip::VipSnapshotUpdatedEvent --limit 5"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::vip::get_vip_snapshot"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::vip::get_lottery_snapshot --args u64:<LOTTERY_ID>"
```

РџСЂРѕРІРµСЂСЊС‚Рµ, С‡С‚Рѕ РІ СЃРѕР±С‹С‚РёРё/РІСЊСЋ РєРѕСЂСЂРµРєС‚РЅРѕ СѓРєР°Р·Р°РЅС‹ `admin`, СЃРїРёСЃРѕРє Р»РѕС‚РµСЂРµР№ (`lotteries`) СЃ РїРѕР»СЏРјРё `config`, `total_members`, `active_members`, `total_revenue` Рё `bonus_tickets_issued`. РџСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё РІС‹Р·РѕРІРёС‚Рµ `upsert_config`, РІС‹РїРѕР»РЅРёС‚Рµ `subscribe`/`subscribe_for` Рё СЃРѕРІРµСЂС€РёС‚Рµ РїРѕРєСѓРїРєСѓ Р±РёР»РµС‚Р°, С‡С‚РѕР±С‹ `record_bonus_usage` РѕР±РЅРѕРІРёР» СЃС‡С‘С‚С‡РёРєРё Рё РѕРїСѓР±Р»РёРєРѕРІР°Р» СЃРІРµР¶РёР№ `VipSnapshotUpdatedEvent`.

**РЎРЅР°РїС€РѕС‚ СЂРµС„РµСЂР°Р»СЊРЅС‹С… Р±РѕРЅСѓСЃРѕРІ.** РџРѕСЃР»Рµ РЅР°СЃС‚СЂРѕР№РєРё РєРѕРЅС„РёРіСѓСЂР°С†РёР№ Рё С‚РµСЃС‚РѕРІС‹С… РІС‹РїР»Р°С‚ СѓР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ СЃРѕР±С‹С‚РёРµ Рё view РїСѓР±Р»РёРєСѓСЋС‚ Р°РіСЂРµРіРёСЂРѕРІР°РЅРЅС‹Р№ СЃРЅРёРјРѕРє:

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool events list --profile <PROFILE> --address @lottery --event-type lottery::referrals::ReferralSnapshotUpdatedEvent --limit 5"
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile <PROFILE> --function-id lottery::referrals::get_referral_snapshot"
```

Р’ РѕС‚РІРµС‚Рµ РїСЂРѕРІРµСЂСЊС‚Рµ РїРѕР»Рµ `admin`, Р·РЅР°С‡РµРЅРёРµ `total_registered` Рё РјР°СЃСЃРёРІ `lotteries`: РєР°Р¶РґС‹Р№ СЌР»РµРјРµРЅС‚ СЃРѕРґРµСЂР¶РёС‚ `lottery_id`, РґРѕР»Рё `referrer/referee_bps`, СЃС‡С‘С‚С‡РёРє `rewarded_purchases` Рё СЃСѓРјРјС‹ РІС‹РїР»Р°С‚. Р•СЃР»Рё СЃРѕР±С‹С‚РёРµ РѕС‚СЃСѓС‚СЃС‚РІСѓРµС‚, РїРѕРІС‚РѕСЂРЅРѕ РІС‹Р·РѕРІРёС‚Рµ `set_lottery_config` Рё РІС‹РїРѕР»РЅРёС‚Рµ С‚РµСЃС‚РѕРІСѓСЋ РїРѕРєСѓРїРєСѓ Р±РёР»РµС‚Р°, С‡С‚РѕР±С‹ РјРѕРґСѓР»СЊ `lottery::referrals` РѕРїСѓР±Р»РёРєРѕРІР°Р» Р°РєС‚СѓР°Р»СЊРЅС‹Р№ СЃРЅРёРјРѕРє.

#### Р‘С‹СЃС‚СЂР°СЏ РїРѕСЃР»РµРґРѕРІР°С‚РµР»СЊРЅРѕСЃС‚СЊ (РїСЂРёРјРµСЂ)
РќРёР¶Рµ РїСЂРёРІРµРґС‘РЅ РїСЂРёРјРµСЂ Р·Р°РїСѓСЃРєР° РІСЃРµС… РєР»СЋС‡РµРІС‹С… РєРѕРјР°РЅРґ. РЎРЅР°С‡Р°Р»Р° Р·Р°РїРѕР»РЅРёС‚Рµ Р·РЅР°С‡РµРЅРёСЏ РїРµСЂРµРјРµРЅРЅС‹С… РІ РїРµСЂРІС‹С… СЃС‚СЂРѕРєР°С… (Р°РґСЂРµСЃР°, Р»РёРјРёС‚С‹ РіР°Р·Р°, РїСЂРѕС„РёР»Рё), Р·Р°С‚РµРј РІС‹РїРѕР»РЅРёС‚Рµ Р±Р»РѕРє С†РµР»РёРєРѕРј. Р’РјРµСЃС‚Рѕ СЂСѓС‡РЅРѕРіРѕ СЂРµРґР°РєС‚РёСЂРѕРІР°РЅРёСЏ СЌРєСЃРїРѕСЂС‚РѕРІ РјРѕР¶РЅРѕ СЃРєРѕРїРёСЂРѕРІР°С‚СЊ С„Р°Р№Р» [`supra/scripts/testnet_env.example`](../supra/scripts/testnet_env.example) РІ `testnet_env.local`, РїРѕРґСЃС‚Р°РІРёС‚СЊ Р·РЅР°С‡РµРЅРёСЏ Рё РІС‹РїРѕР»РЅРёС‚СЊ `set -a; source supra/scripts/testnet_env.local; set +a`.
Р”Р»СЏ РіРѕС‚РѕРІРѕРіРѕ РЅР°Р±РѕСЂР° РєРѕРјР°РЅРґ РїРѕРґ РїСЂРѕС„РёР»СЊ `my_new_profile` СЃРј. [dVRF walkthrough](./dvrf_testnet_my_new_profile_walkthrough.md).

```bash
export SUPRA_CONFIG=/supra/configs/testnet.yaml
PROFILE=my_new_profile
DEPOSIT_ADDR=0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e
LOTTERY_ADDR=0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0
export MAX_GAS_PRICE=1000
export MAX_GAS_LIMIT=500000
export CALLBACK_GAS_PRICE=100
export CALLBACK_GAS_LIMIT=150000
export VERIFICATION_GAS_VALUE=25000
export INITIAL_DEPOSIT=20000000000
export RNG_COUNT=1
export NUM_CONFIRMATIONS=1 # РґРѕРїСѓСЃС‚РёРјС‹Р№ РґРёР°РїР°Р·РѕРЅ Supra dVRF: 1..20
export CLIENT_SEED=1234567890
AGGREGATOR_ADDR=""   # Р·Р°РїРѕР»РЅРёС‚Рµ С„Р°РєС‚РёС‡РµСЃРєРёРј Р°РґСЂРµСЃРѕРј Р°РіСЂРµРіР°С‚РѕСЂР° Supra testnet
PLAYER_PROFILE=player1
PLAYER_CONFIG=/supra/configs/player1.yaml   # РїСЂРѕС„РёР»СЊ/YAML РёРіСЂРѕРєР°, РїРѕРІС‚РѕСЂРёС‚Рµ РґР»СЏ РґСЂСѓРіРёС… Р°РєРєР°СѓРЅС‚РѕРІ

docker compose run --rm --entrypoint bash supra_cli -lc "mkdir -p /supra/.aptos && cp $SUPRA_CONFIG /supra/.aptos/config.yaml"

docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli -lc 'cd /supra/SupraLottery && export SUPRA_PROFILE=$PROFILE && PYTHONPATH=/supra/SupraLottery python3 -m supra.scripts.configure_vrf_gas --cli /supra/supra --profile $SUPRA_PROFILE --max-gas-price $MAX_GAS_PRICE --max-gas-limit $MAX_GAS_LIMIT --callback-gas-price $CALLBACK_GAS_PRICE --callback-gas-limit $CALLBACK_GAS_LIMIT --verification-gas-value $VERIFICATION_GAS_VALUE --verbose'

docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::migrateClient --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT --assume-yes"

docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::addClientToWhitelist --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT --assume-yes"

MIN_BALANCE_LIMIT=$(python - <<'PY'
import os
max_gas_price = int(os.environ["MAX_GAS_PRICE"])
max_gas_limit = int(os.environ["MAX_GAS_LIMIT"])
verification_gas = int(os.environ["VERIFICATION_GAS_VALUE"])
print(30 * max_gas_price * (max_gas_limit + verification_gas))
PY
)
echo "Calculated MIN_BALANCE_LIMIT=$MIN_BALANCE_LIMIT"

docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id lottery::core_main_v2::create_subscription --args u64:$INITIAL_DEPOSIT --assume-yes"

if [[ -n "$AGGREGATOR_ADDR" ]]; then
  docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id lottery::core_main_v2::whitelist_callback_sender --args address:$AGGREGATOR_ADDR --assume-yes"
fi
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id lottery::core_main_v2::whitelist_consumer --args address:$LOTTERY_ADDR --assume-yes"

docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id lottery::core_main_v2::record_client_whitelist_snapshot --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT u128:$MIN_BALANCE_LIMIT --assume-yes"
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id lottery::core_main_v2::record_consumer_whitelist_snapshot --args u128:$CALLBACK_GAS_PRICE u128:$CALLBACK_GAS_LIMIT --assume-yes"

docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli -lc 'cd /supra/SupraLottery && export SUPRA_PROFILE=$PROFILE && PYTHONPATH=/supra/SupraLottery python3 -m supra.scripts.configure_vrf_request --cli /supra/supra --profile $SUPRA_PROFILE --verbose'

docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$PLAYER_CONFIG /supra/supra move tool run --profile $PLAYER_PROFILE --function-id lottery::core_main_v2::buy_ticket"
# РџРѕРІС‚РѕСЂРёС‚Рµ РєРѕРјР°РЅРґСѓ РґР»СЏ РѕСЃС‚Р°Р»СЊРЅС‹С… РёРіСЂРѕРєРѕРІ, С‡С‚РѕР±С‹ СЃСѓРјРјР°СЂРЅРѕ РїСЂРѕРґР°С‚СЊ в‰Ґ5 Р±РёР»РµС‚РѕРІ

docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool view --profile $PROFILE --function-id lottery::core_main_v2::get_lottery_status"

PROFILE=$PROFILE LOTTERY_ADDR=$LOTTERY_ADDR DEPOSIT_ADDR=$DEPOSIT_ADDR \
  MAX_GAS_PRICE=$MAX_GAS_PRICE MAX_GAS_LIMIT=$MAX_GAS_LIMIT VERIFICATION_GAS_VALUE=$VERIFICATION_GAS_VALUE \
  SUPRA_CONFIG=$SUPRA_CONFIG CLIENT_ADDR=$LOTTERY_ADDR \
  python supra/scripts/testnet_draw_readiness.py

docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool run --profile $PROFILE --function-id lottery::core_main_v2::manual_draw --assume-yes"
docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=$SUPRA_CONFIG /supra/supra move tool events tail --profile $PROFILE --address $LOTTERY_ADDR --event-type lottery::core_main_v2::DrawHandledEvent"

# РџСЂРѕРІРµСЂРєР° РґРµРїРѕР·РёС‚Р° Рё РјРёРЅРёРјР°Р»СЊРЅРѕРіРѕ Р±Р°Р»Р°РЅСЃР° (Р·Р°РІРµСЂС€РёС‚СЃСЏ exit=1 РїСЂРё СЃСЂР°Р±Р°С‚С‹РІР°РЅРёРё РїРѕСЂРѕРіР°)
MONITOR_MARGIN=0.2 PROFILE=$PROFILE LOTTERY_ADDR=$LOTTERY_ADDR DEPOSIT_ADDR=$DEPOSIT_ADDR \
  MAX_GAS_PRICE=$MAX_GAS_PRICE MAX_GAS_LIMIT=$MAX_GAS_LIMIT VERIFICATION_GAS_VALUE=$VERIFICATION_GAS_VALUE \
  SUPRA_CONFIG=$SUPRA_CONFIG CLIENT_ADDR=$LOTTERY_ADDR \
  supra/scripts/testnet_monitor_check.sh

# РњР°С€РёРЅРѕС‡РёС‚Р°РµРјС‹Р№ JSON-РѕС‚С‡С‘С‚ (РјРѕР¶РЅРѕ СЃРѕС…СЂР°РЅСЏС‚СЊ РІ CI/AutoFi Р°СЂС‚РµС„Р°РєС‚С‹)
PROFILE=$PROFILE LOTTERY_ADDR=$LOTTERY_ADDR DEPOSIT_ADDR=$DEPOSIT_ADDR \
  MAX_GAS_PRICE=$MAX_GAS_PRICE MAX_GAS_LIMIT=$MAX_GAS_LIMIT VERIFICATION_GAS_VALUE=$VERIFICATION_GAS_VALUE \
  SUPRA_CONFIG=$SUPRA_CONFIG CLIENT_ADDR=$LOTTERY_ADDR \
  python supra/scripts/testnet_monitor_json.py --pretty

# РћС‚РїСЂР°РІРєР° СѓРІРµРґРѕРјР»РµРЅРёСЏ РІ Slack/Teams (РёСЃРїРѕР»СЊР·СѓРµС‚ С‚Рµ Р¶Рµ РїРµСЂРµРјРµРЅРЅС‹Рµ + MONITOR_WEBHOOK_URL)
PROFILE=$PROFILE LOTTERY_ADDR=$LOTTERY_ADDR DEPOSIT_ADDR=$DEPOSIT_ADDR \
  MAX_GAS_PRICE=$MAX_GAS_PRICE MAX_GAS_LIMIT=$MAX_GAS_LIMIT VERIFICATION_GAS_VALUE=$VERIFICATION_GAS_VALUE \
  SUPRA_CONFIG=$SUPRA_CONFIG CLIENT_ADDR=$LOTTERY_ADDR MONITOR_WEBHOOK_URL=$MONITOR_WEBHOOK_URL \
  ./supra/scripts/testnet_monitor_slack.py --fail-on-low
```

> Р•СЃР»Рё РїРµСЂРµРјРµРЅРЅР°СЏ `AGGREGATOR_ADDR` РѕСЃС‚Р°РІР»РµРЅР° РїСѓСЃС‚РѕР№ (`""`), С€Р°Рі whitelisting Р°РіСЂРµРіР°С‚РѕСЂР° Р±СѓРґРµС‚ РїСЂРѕРїСѓС‰РµРЅ вЂ” РїРѕРґСЃС‚Р°РІСЊС‚Рµ С„Р°РєС‚РёС‡РµСЃРєРёР№ Р°РґСЂРµСЃ Supra testnet, С‡С‚РѕР±С‹ СЂР°Р·СЂРµС€РёС‚СЊ callback-СѓР·РµР».

РџРѕСЃР»Рµ РІС‹РїРѕР»РЅРµРЅРёСЏ Р±Р»РѕРєРѕРІ РїСЂРѕРІРµСЂСЊС‚Рµ СЃРѕР±С‹С‚РёСЏ `SubscriptionConfiguredEvent` Рё СѓР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ РѕС€РёР±РѕРє `ECLIENT_NOT_EXIST` РЅРµС‚.

### 3.3 Whitelisting Р°РіСЂРµРіР°С‚РѕСЂР° Рё РїРѕС‚СЂРµР±РёС‚РµР»РµР№
> РћСЃРЅРѕРІР°РЅРѕ РЅР° [Supra VRF Subscription FAQ](https://raw.githubusercontent.com/Supra-Labs/documentation/main/dvrf/build-with-supra-dvrf/vrf-subscription-model.md) Рё СЂРµРєРѕРјРµРЅРґР°С†РёСЏС… Supra Рѕ РєРѕРЅС‚СЂРѕР»Рµ РґРѕСЃС‚СѓРїР°.

1. **Whitelisting Р°РіСЂРµРіР°С‚РѕСЂР° РєРѕР»Р±СЌРєРѕРІ** вЂ” РІС‹РїРѕР»РЅСЏРµС‚СЃСЏ С‚РѕР»СЊРєРѕ Р°РґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂРѕРј Р»РѕС‚РµСЂРµРё (`@lottery`) РїРѕСЃР»Рµ СѓСЃРїРµС€РЅРѕРіРѕ РґРµРїРѕР·РёС‚Р° Рё РЅР°СЃС‚СЂРѕР№РєРё РіР°Р·Р°. РљРѕРјР°РЅРґР° Р·Р°РїСЂРµС‰РµРЅР°, РїРѕРєР° Р°РєС‚РёРІРµРЅ РЅРµР·Р°РІРµСЂС€С‘РЅРЅС‹Р№ VRF-Р·Р°РїСЂРѕСЃ (`E_REQUEST_STILL_PENDING`).
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::core_main_v2::whitelist_callback_sender --args address:<AGGREGATOR_ADDR>"
   ```
   - Р—Р°С„РёРєСЃРёСЂСѓР№С‚Рµ tx hash Рё СЃРѕР±С‹С‚РёРµ `WhitelistSnapshotUpdatedEvent` (РїРѕСЃР»РµРґРЅСЏСЏ Р·Р°РїРёСЃСЊ РїРѕРєР°Р¶РµС‚ Р°РіСЂРµРіР°С‚РѕСЂР° Рё РІРµСЃСЊ СЃРїРёСЃРѕРє РїРѕС‚СЂРµР±РёС‚РµР»РµР№). РџСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё СЃРѕС…СЂР°РЅСЏР№С‚Рµ С‚Р°РєР¶Рµ `AggregatorWhitelistedEvent` РґР»СЏ РёСЃС‚РѕСЂРёРё РґРѕСЃС‚СѓРїР°.
   - РџСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё СЃРјРµРЅРёС‚СЊ Р°РіСЂРµРіР°С‚РѕСЂ СЃРЅР°С‡Р°Р»Р° СѓР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ `pending_request` РїСѓСЃС‚ (РїСЂРѕРІРµСЂСЊС‚Рµ `lottery::core_main_v2::get_whitelist_status`).
   - Р”Р»СЏ РІСЂРµРјРµРЅРЅРѕРіРѕ РѕС‚РєР»СЋС‡РµРЅРёСЏ Р°РіСЂРµРіР°С‚РѕСЂР° РёСЃРїРѕР»СЊР·СѓР№С‚Рµ `lottery::core_main_v2::revoke_callback_sender`, РЅРѕ С‚РѕР»СЊРєРѕ РєРѕРіРґР° РЅРµС‚ Р°РєС‚РёРІРЅРѕРіРѕ Р·Р°РїСЂРѕСЃР°.

2. **Whitelisting РїРѕС‚СЂРµР±РёС‚РµР»РµР№ VRF** вЂ” Supra VRF Subscription FAQ С‚СЂРµР±СѓРµС‚ СЏРІРЅРѕ СЂР°Р·СЂРµС€Р°С‚СЊ РєР°Р¶РґРѕРјСѓ РєРѕРЅС‚СЂР°РєС‚Сѓ РѕС‚РїСЂР°РІРєСѓ Р·Р°РїСЂРѕСЃРѕРІ.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::core_main_v2::whitelist_consumer --args address:<CONSUMER_ADDR>"
   ```
   - РџРѕРІС‚РѕСЂРёС‚Рµ РґР»СЏ РІСЃРµС… РІСЃРїРѕРјРѕРіР°С‚РµР»СЊРЅС‹С… РєРѕРЅС‚СЂР°РєС‚РѕРІ (РѕРїРµСЂР°С‚РѕСЂСЃРєРёС… РёР»Рё Р±СѓРґСѓС‰РёС… РёРЅС‚РµРіСЂР°С†РёР№).
   - РџСЂРѕРІРµСЂСЏР№С‚Рµ РЅР°Р»РёС‡РёРµ Р°РґСЂРµСЃР° РІ СЃРїРёСЃРєРµ С‡РµСЂРµР· `lottery::core_main_v2::get_whitelist_status` РёР»Рё РїРѕ СЃРѕР±С‹С‚РёСЋ `WhitelistSnapshotUpdatedEvent`.

3. **РЈРґР°Р»РµРЅРёРµ РїРѕС‚СЂРµР±РёС‚РµР»СЏ** РїСЂРё РѕС‚Р·С‹РІРµ РґРѕСЃС‚СѓРїР° РёР»Рё РєРѕРјРїСЂРѕРјРµС‚Р°С†РёРё РєР»СЋС‡Р°:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::core_main_v2::remove_consumer --args address:<CONSUMER_ADDR>"
   ```
   - РљРѕРјР°РЅРґР° Р°РІР°СЂРёР№РЅРѕ Р·Р°РІРµСЂС€РёС‚СЃСЏ `E_CONSUMER_NOT_WHITELISTED`, РµСЃР»Рё Р°РґСЂРµСЃ РѕС‚СЃСѓС‚СЃС‚РІСѓРµС‚ РІ whitelist.
   - РџРѕСЃР»Рµ СЂРµРІРѕРєР° РїСЂРѕРІРµСЂСЏР№С‚Рµ СЃРѕР±С‹С‚РёРµ `ConsumerRemovedEvent` Рё СѓР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ СЃРІРµР¶РёР№ `WhitelistSnapshotUpdatedEvent` СЃРѕРґРµСЂР¶РёС‚ С‚РѕР»СЊРєРѕ РІР°Р»РёРґРЅС‹С… РїРѕС‚СЂРµР±РёС‚РµР»РµР№.

4. **РљРѕРЅС‚СЂРѕР»СЊ whitelisting С‡РµСЂРµР· СЃРѕР±С‹С‚РёСЏ**. Р”Р»СЏ Р°СѓРґРёС‚Р° РёСЃРїРѕР»СЊР·СѓР№С‚Рµ CLI:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events tail --profile <PROFILE> --address <LOTTERY_ADDR> --event-type lottery::core_main_v2::WhitelistSnapshotUpdatedEvent"
   ```
   ```bash
   # РџСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё РґРѕРїРѕР»РЅРёС‚РµР»СЊРЅРѕ РѕС‚СЃР»РµР¶РёРІР°Р№С‚Рµ РѕС‚РґРµР»СЊРЅС‹Рµ СЃРѕР±С‹С‚РёСЏ grant/revoke
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events tail --profile <PROFILE> --address <LOTTERY_ADDR> --event-type lottery::core_main_v2::AggregatorWhitelistedEvent"
   ```
   РЎРѕС…СЂР°РЅСЏР№С‚Рµ timestamp, tx hash Рё payload СЃРѕР±С‹С‚РёР№ РІ runbook Р¶СѓСЂРЅР°Р»Р°С….

5. **РЎРЅРёРјРѕРє РґРµР»РµРіР°С‚РѕРІ РѕРїРµСЂР°С‚РѕСЂРѕРІ** вЂ” РїРѕСЃР»Рµ whitelisting/СЂРµРІРѕРєР°С†РёРё СѓР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ СЃРїРёСЃРѕРє РѕРїРµСЂР°С‚РѕСЂРѕРІ СЃРёРЅС…СЂРѕРЅРёР·РёСЂРѕРІР°РЅ:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move view --profile <PROFILE> --function-id $LOTTERY_ADDR::operators::get_operator_snapshot --args u64:<LOTTERY_ID>"
   ```
   - РљРѕРјР°РЅРґР° РІРѕР·РІСЂР°С‰Р°РµС‚ С‚РµРєСѓС‰РµРіРѕ РІР»Р°РґРµР»СЊС†Р° Рё РјР°СЃСЃРёРІ РґРµР»РµРіР°С‚РѕРІ; С…СЂР°РЅРёС‚Рµ JSON-РѕС‚РІРµС‚ РІ РєРѕРЅС‚СЂРѕР»СЊРЅРѕРј РѕС‚С‡С‘С‚Рµ.
   - Р”Р»СЏ live-РјРѕРЅРёС‚РѕСЂРёРЅРіР° РёСЃС‚РѕСЂРёРё РёСЃРїРѕР»СЊР·СѓР№С‚Рµ СЃРѕР±С‹С‚РёРµ `operators::OperatorSnapshotUpdatedEvent`:
     ```bash
     docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events tail --profile <PROFILE> --address $LOTTERY_ADDR --event-type $LOTTERY_ADDR::operators::OperatorSnapshotUpdatedEvent"
     ```


### 3.4 РњРёРіСЂР°С†РёСЏ legacy-Р»РѕС‚РµСЂРµР№
> РћСЃРЅРѕРІР°РЅРѕ РЅР° СЂСѓРєРѕРІРѕРґСЃС‚РІРµ Supra *Migration to dVRF 3.0* Рё С‚СЂРµР±РѕРІР°РЅРёСЏС… Рє РЅР°Р±Р»СЋРґР°РµРјРѕСЃС‚Рё РїСЂРё РїРµСЂРµРЅРѕСЃРµ РґР°РЅРЅС‹С….

1. **РџРѕРґРіРѕС‚РѕРІРєР°** вЂ” СѓР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ:
   - РґР»СЏ РЅСѓР¶РЅРѕР№ Р»РѕС‚РµСЂРµРё РЅРµС‚ Р°РєС‚РёРІРЅРѕРіРѕ VRF-Р·Р°РїСЂРѕСЃР° (`lottery::core_main_v2::get_pending_request_view` в†’ `option::none`),
   - РєРѕРЅС„РёРіСѓСЂР°С†РёСЏ РґРѕР»РµР№ (`prize_bps`, `jackpot_bps`, `operations_bps`) СЃРѕРіР»Р°СЃРѕРІР°РЅР° СЃ РЅРѕРІС‹Рј РєР°Р·РЅР°С‡РµР№СЃС‚РІРѕРј,
   - `treasury_multi::get_pool(<LOTTERY_ID>)` РІРѕР·РІСЂР°С‰Р°РµС‚ `option::none` (Р»РѕС‚РµСЂРµСЏ РµС‰С‘ РЅРµ РјРёРіСЂРёСЂРѕРІР°РЅР°).

2. **Р—Р°РїСѓСЃРє РјРёРіСЂР°С†РёРё**
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::migration::migrate_from_legacy --args u64:<LOTTERY_ID> u64:<PRIZE_BPS> u64:<JACKPOT_BPS> u64:<OPERATIONS_BPS> --assume-yes"
   ```
   - РџСЂРё РЅР°Р»РёС‡РёРё РЅРµР·Р°РІРµСЂС€С‘РЅРЅРѕРіРѕ Р·Р°РїСЂРѕСЃР° С„СѓРЅРєС†РёСЏ Р·Р°РІРµСЂС€РёС‚СЃСЏ `E_PENDING_REQUEST`.
   - РџРѕРІС‚РѕСЂРЅС‹Р№ Р·Р°РїСѓСЃРє РґР»СЏ СѓР¶Рµ РїРµСЂРµРЅРµСЃС‘РЅРЅРѕР№ Р»РѕС‚РµСЂРµРё РїСЂРёРІРµРґС‘С‚ Рє `E_ALREADY_MIGRATED`.

3. **РџСЂРѕРІРµСЂРєР° СЃРѕР±С‹С‚РёСЏ** вЂ” РјРёРіСЂР°С†РёСЏ РїСѓР±Р»РёРєСѓРµС‚ Р°РіСЂРµРіРёСЂРѕРІР°РЅРЅС‹Р№ СЃРЅР°РїС€РѕС‚ СЃ Р±РёР»РµС‚Р°РјРё, `next_ticket_id` Рё РґРѕР»СЏРјРё СЂР°СЃРїСЂРµРґРµР»РµРЅРёСЏ:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events tail --profile <PROFILE> --address $LOTTERY_ADDR --event-type lottery::migration::MigrationSnapshotUpdatedEvent"
   ```
   РЎРѕС…СЂР°РЅРёС‚Рµ payload СЃРѕР±С‹С‚РёСЏ РІ Р¶СѓСЂРЅР°Р» Р°СѓРґРёС‚Р° (РІРєР»СЋС‡Р°РµС‚ `ticket_count`, `legacy_next_ticket_id`, `migrated_next_ticket_id`, `jackpot_amount_migrated`, `prize_bps`, `jackpot_bps`, `operations_bps`).

4. **View-С„СѓРЅРєС†РёРё РґР»СЏ РѕС‚С‡С‘С‚РѕРІ**
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::migration::list_migrated_lottery_ids"
   ```
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::migration::get_migration_snapshot --args u64:<LOTTERY_ID>"
   ```
   Р РµР·СѓР»СЊС‚Р°С‚ `get_migration_snapshot` СЃРѕРґРµСЂР¶РёС‚ СЃС‚СЂСѓРєС‚СѓСЂСѓ `MigrationSnapshot`; СЃРѕС…СЂР°РЅРёС‚Рµ JSON РґР»СЏ СЃРІРµСЂРєРё СЃ off-chain РѕС‚С‡С‘С‚Р°РјРё.

5. **РљСЂРѕСЃСЃ-РїСЂРѕРІРµСЂРєР°** вЂ” РїРѕСЃР»Рµ РјРёРіСЂР°С†РёРё РІС‹РїРѕР»РЅРёС‚Рµ `treasury_multi::get_pool(<LOTTERY_ID>)` Рё `lottery::core_rounds::get_round_snapshot(<LOTTERY_ID>)`, С‡С‚РѕР±С‹ СѓР±РµРґРёС‚СЊСЃСЏ, С‡С‚Рѕ Р±РёР»РµС‚С‹ Рё РґР¶РµРєРїРѕС‚ РїРµСЂРµРЅРµСЃРµРЅС‹, `pending_request_id` РѕС‚СЃСѓС‚СЃС‚РІСѓРµС‚ Рё `draw_scheduled` СЃРѕРѕС‚РІРµС‚СЃС‚РІСѓРµС‚ РѕР¶РёРґР°РЅРёСЏРј. Р”РѕРїРѕР»РЅРёС‚РµР»СЊРЅРѕ РїСЂРѕСЃРјРѕС‚СЂРёС‚Рµ СЃРѕР±С‹С‚РёСЏ `RoundSnapshotUpdatedEvent` (`events list ... --event-type $LOTTERY_ADDR::rounds::RoundSnapshotUpdatedEvent`), С‡С‚РѕР±С‹ СЃРІРµСЂРёС‚СЊ, С‡С‚Рѕ РїРѕСЃР»РµРґРЅРёРµ СЃРЅР°РїС€РѕС‚С‹ СЃРѕРІРїР°РґР°СЋС‚ СЃ РґР°РЅРЅС‹РјРё view.


## 4. РќР°СЃС‚СЂРѕР№РєР° РїР°СЂР°РјРµС‚СЂРѕРІ VRF-Р·Р°РїСЂРѕСЃР°

```bash
docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli -lc 'cd /supra/SupraLottery && export SUPRA_PROFILE=<PROFILE> && PYTHONPATH=/supra/SupraLottery python3 -m supra.scripts.configure_vrf_request --cli /supra/supra --profile $SUPRA_PROFILE --rng-count <RNG_COUNT> --confirmations <NUM_CONFIRMATIONS> --client-seed <CLIENT_SEED> --verbose'
```
РЈР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ `RNG_COUNT > 0`, Р° `NUM_CONFIRMATIONS` РЅР°С…РѕРґРёС‚СЃСЏ РІ РґРёР°РїР°Р·РѕРЅРµ `1..20` (РѕРіСЂР°РЅРёС‡РµРЅРёРµ Supra dVRF). РЎРѕР±С‹С‚РёРµ `VrfRequestConfigUpdatedEvent` С„РёРєСЃРёСЂСѓРµС‚ Р·РЅР°С‡РµРЅРёСЏ.

## 5. РџСѓР±Р»РёРєР°С†РёСЏ РїР°РєРµС‚Р° Рё РІР·Р°РёРјРѕРґРµР№СЃС‚РІРёРµ
1. РџСѓР±Р»РёРєСѓРµРј РєРѕРЅС‚СЂР°РєС‚:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool publish --profile <PROFILE> --package-dir /supra/move_workspace/lottery"
   ```
2. РџРѕРїРѕР»РЅСЏРµРј Р±Р°РЅРє (РїСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё) Рё РїСЂРѕРґР°С‘Рј Р±РёР»РµС‚С‹ (РґР»СЏ РЅРµСЃРєРѕР»СЊРєРёС… Р°РґСЂРµСЃРѕРІ, РёСЃРїРѕР»СЊР·СѓР№С‚Рµ faucet testnet Рё РѕС‚РґРµР»СЊРЅС‹Р№ РїСЂРѕС„Р°Р№Р» РґР»СЏ РєР°Р¶РґРѕРіРѕ РёРіСЂРѕРєР°). **Р РѕР·С‹РіСЂС‹С€ РїР»Р°РЅРёСЂСѓРµС‚СЃСЏ Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєРё, С‚РѕР»СЊРєРѕ РєРѕРіРґР° РІ РїСѓР»Рµ в‰ҐвЂЇ5 Р±РёР»РµС‚РѕРІ** вЂ” РёРЅР°С‡Рµ `manual_draw`/`request_draw` Р·Р°РІРµСЂС€Р°С‚СЃСЏ РѕС€РёР±РєРѕР№.
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/player1.yaml /supra/supra move tool run --profile <PLAYER_PROFILE> --function-id lottery::core_main_v2::buy_ticket"
   ```
   > Р’С‹Р·РѕРІ С‚СЂРµР±СѓРµС‚ РїРѕРґРїРёСЃРё СЃР°РјРѕРіРѕ РёРіСЂРѕРєР°, РїРѕСЌС‚РѕРјСѓ СѓРєР°Р·С‹РІР°Р№С‚Рµ РїСЂРѕС„РёР»СЊ СЃ РµРіРѕ РїСЂРёРІР°С‚РЅС‹Рј РєР»СЋС‡РѕРј (`--profile <PLAYER_PROFILE>` Рё СЃРѕРѕС‚РІРµС‚СЃС‚РІСѓСЋС‰РёР№ `SUPRA_CONFIG`, РµСЃР»Рё РёСЃРїРѕР»СЊР·СѓРµС‚Рµ YAML). РђРЅР°Р»РѕРіРёС‡РЅРѕ Р·Р°РїСѓСЃРєР°РµРј РєРѕРјР°РЅРґСѓ РґР»СЏ РґСЂСѓРіРёС… СѓС‡Р°СЃС‚РЅРёРєРѕРІ (player2, player3 Рё С‚.Рґ.).
   РџРѕСЃР»Рµ РїСЂРѕРґР°Р¶Рё РїСЏС‚РѕРіРѕ Р±РёР»РµС‚Р° РїСЂРѕРІРµСЂСЊС‚Рµ СЃС‚Р°С‚СѓСЃ:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::core_main_v2::get_lottery_status"
   ```
   Р’ РѕС‚РІРµС‚Рµ РїРѕР»Рµ `draw_scheduled` РґРѕР»Р¶РЅРѕ Р±С‹С‚СЊ `true`, Р° `pending_request` вЂ” `false`.
   Р”Р»СЏ Р°РІС‚РѕРјР°С‚РёР·РёСЂРѕРІР°РЅРЅРѕР№ РїСЂРѕРІРµСЂРєРё РїРµСЂРµРґ Р·Р°РїСѓСЃРєРѕРј VRF РјРѕР¶РЅРѕ РІС‹РїРѕР»РЅРёС‚СЊ СЃРєСЂРёРїС‚ `python supra/scripts/testnet_draw_readiness.py` (СЃРј. СЂР°Р·РґРµР» 6) вЂ” РѕРЅ РїСЂРѕРІРµСЂРёС‚ РєРѕР»РёС‡РµСЃС‚РІРѕ Р±РёР»РµС‚РѕРІ, whitelisting Р°РіСЂРµРіР°С‚РѕСЂРѕРІ Рё РґРѕСЃС‚РёР¶РµРЅРёРµ РјРёРЅРёРјР°Р»СЊРЅРѕРіРѕ РґРµРїРѕР·РёС‚Р°.
3. Р”РµР»Р°РµРј Р·Р°РїСЂРѕСЃ VRF:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool run --profile <PROFILE> --function-id lottery::core_main_v2::manual_draw"
   ```
   Р¤СѓРЅРєС†РёСЏ РїСЂРѕРІРµСЂСЏРµС‚ whitelisting Р°РіСЂРµРіР°С‚РѕСЂР° Рё РїРѕС‚СЂРµР±РёС‚РµР»РµР№, СѓР±РµР¶РґР°РµС‚СЃСЏ, С‡С‚Рѕ `draw_scheduled = true` Рё РЅРµС‚ Р°РєС‚РёРІРЅРѕРіРѕ `pending_request`. РџСЂРё РЅРµСЃРѕР±Р»СЋРґРµРЅРёРё СѓСЃР»РѕРІРёР№ РІРµСЂРЅС‘С‚ `Move abort вЂ¦ manual_draw at code offset 11` вЂ” Р·РЅР°С‡РёС‚, РЅРµРѕР±С…РѕРґРёРјРѕ РїСЂРѕРґР°С‚СЊ РЅРµРґРѕСЃС‚Р°СЋС‰РёРµ Р±РёР»РµС‚С‹ РёР»Рё РґРѕР¶РґР°С‚СЊСЃСЏ РѕР±СЂР°Р±РѕС‚РєРё РїСЂРµРґС‹РґСѓС‰РµРіРѕ Р·Р°РїСЂРѕСЃР°.
4. РћР¶РёРґР°РµРј callback `on_random_received`. РџСЂРѕРІРµСЂСЏРµРј СЃРѕР±С‹С‚РёСЏ:
   ```bash
   docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool events tail --profile <PROFILE> --address <LOTTERY_ADDR> --event-type lottery::core_main_v2::DrawHandledEvent"
   ```

## 6. Р’РµСЂРёС„РёРєР°С†РёСЏ Рё РјРѕРЅРёС‚РѕСЂРёРЅРі
- Р‘С‹СЃС‚СЂС‹Р№ СЃРїРѕСЃРѕР± СЃРѕР±СЂР°С‚СЊ РѕСЃРЅРѕРІРЅС‹Рµ view-РєРѕРјР°РЅРґС‹ вЂ” СЃРєСЂРёРїС‚ [`supra/scripts/testnet_status_report.sh`](../supra/scripts/testnet_status_report.sh). РћРЅ РїСЂРёРЅРёРјР°РµС‚ РїРµСЂРµРјРµРЅРЅС‹Рµ `PROFILE`, `LOTTERY_ADDR`, `DEPOSIT_ADDR` (Рё РѕРїС†РёРѕРЅР°Р»СЊРЅРѕ `CLIENT_ADDR`/`SUPRA_CONFIG`) Рё РІС‹РІРѕРґРёС‚ СЃРѕСЃС‚РѕСЏРЅРёРµ РєРѕРЅС‚СЂР°РєС‚Р° Рё РґРµРїРѕР·РёС‚Р° РІ РѕРґРЅРѕРј РѕС‚С‡С‘С‚Рµ.
- РџРµСЂРµРґ Р·Р°РїСѓСЃРєРѕРј `manual_draw` РјРѕР¶РЅРѕ РёСЃРїРѕР»СЊР·РѕРІР°С‚СЊ [`supra/scripts/testnet_draw_readiness.py`](../supra/scripts/testnet_draw_readiness.py). РЎРєСЂРёРїС‚ Р·Р°РїСѓСЃРєР°РµС‚ `testnet_monitor_json.py`, РїСЂРѕРІРµСЂСЏРµС‚ РєРѕР»РёС‡РµСЃС‚РІРѕ Р±РёР»РµС‚РѕРІ, РѕС‚СЃСѓС‚СЃС‚РІРёРµ `pending_request`, whitelisting Р°РіСЂРµРіР°С‚РѕСЂРѕРІ Рё РґРѕСЃС‚РёР¶РµРЅРёРµ РјРёРЅРёРјР°Р»СЊРЅРѕРіРѕ РґРµРїРѕР·РёС‚Р°, РІРѕР·РІСЂР°С‰Р°СЏ РєРѕРґ 0/1.
- Р”Р»СЏ РїРѕР»РЅРѕРіРѕ Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєРѕРіРѕ Р·Р°РїСѓСЃРєР° РїСЂРµРґСѓСЃРјРѕС‚СЂРµРЅ [`supra/scripts/testnet_manual_draw.py`](../supra/scripts/testnet_manual_draw.py) вЂ” РѕРЅ РїРѕРІС‚РѕСЂСЏРµС‚ РїСЂРѕРІРµСЂРєСѓ РіРѕС‚РѕРІРЅРѕСЃС‚Рё (РјРѕР¶РЅРѕ РІС‹РєР»СЋС‡РёС‚СЊ С„Р»Р°РіРѕРј `--skip-readiness`), РІС‹РІРѕРґРёС‚ С„Р°РєС‚РёС‡РµСЃРєСѓСЋ РєРѕРјР°РЅРґСѓ Supra CLI Рё РїСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё РІС‹РїРѕР»РЅСЏРµС‚ `manual_draw`.
- Р”Р»СЏ Р°РІС‚РѕРјР°С‚РёР·РёСЂРѕРІР°РЅРЅРѕРіРѕ РјРѕРЅРёС‚РѕСЂРёРЅРіР° РјРёРЅРёРјР°Р»СЊРЅРѕРіРѕ Р±Р°Р»Р°РЅСЃР° РёСЃРїРѕР»СЊР·СѓР№С‚Рµ [`supra/scripts/testnet_monitor_check.sh`](../supra/scripts/testnet_monitor_check.sh). РЎРєСЂРёРїС‚ СЂР°СЃСЃС‡РёС‚С‹РІР°РµС‚ `min_balance` РїРѕ С‚РµРєСѓС‰РёРј Р»РёРјРёС‚Р°Рј РіР°Р·Р°, СЃСЂР°РІРЅРёРІР°РµС‚ СЃ on-chain-РѕСЃС‚Р°С‚РєРѕРј `deposit::checkClientFund` Рё Р·Р°РІРµСЂС€Р°РµС‚ СЂР°Р±РѕС‚Сѓ СЃ РєРѕРґРѕРј 1, РµСЃР»Рё РґРµРїРѕР·РёС‚ РѕРїСѓСЃС‚РёР»СЃСЏ РґРѕ РїРѕСЂРѕРіР° (`isMinimumBalanceReached = true`) РёР»Рё РЅРёР¶Рµ РѕР¶РёРґР°РµРјРѕРіРѕ Р·РЅР°С‡РµРЅРёСЏ. Р РµРєРѕРјРµРЅРґР°С†РёРё РїРѕ Р·Р°РїСѓСЃРєСѓ СЃРєСЂРёРїС‚РѕРІ РїРѕ СЂР°СЃРїРёСЃР°РЅРёСЋ, РІ CI Рё Supra AutoFi СЃРѕР±СЂР°РЅС‹ РІ [РѕС‚РґРµР»СЊРЅРѕРј СЂСѓРєРѕРІРѕРґСЃС‚РІРµ](./dvrf_monitoring_automation.md).
- Р”Р»СЏ РїРѕР»СѓС‡РµРЅРёСЏ РјР°С€РёРЅРѕС‡РёС‚Р°РµРјРѕРіРѕ СЃС‚Р°С‚СѓСЃР° РїРѕРґРїРёСЃРєРё (Р±Р°Р»Р°РЅСЃ, whitelisting, РєРѕРЅС„РёРіСѓСЂР°С†РёСЏ VRF) РІРѕСЃРїРѕР»СЊР·СѓР№С‚РµСЃСЊ [`supra/scripts/testnet_monitor_json.py`](../supra/scripts/testnet_monitor_json.py). РЎРєСЂРёРїС‚ РїРѕРІС‚РѕСЂРЅРѕ РёСЃРїРѕР»СЊР·СѓРµС‚ СЂР°СЃС‡С‘С‚ `calc_min_balance.py`, РѕР±СЂР°С‰Р°РµС‚СЃСЏ Рє `view`-С„СѓРЅРєС†РёСЏРј РєРѕРЅС‚СЂР°РєС‚Р° Рё РјРѕРґСѓР»СЏ `deposit` Рё РїСЂРё С„Р»Р°РіРµ `--fail-on-low` Р·Р°РІРµСЂС€Р°РµС‚ СЂР°Р±РѕС‚Сѓ СЃ РєРѕРґРѕРј 1, РµСЃР»Рё Р±Р°Р»Р°РЅСЃ РјРµРЅСЊС€Рµ `min_balance`.
- Р”Р»СЏ РѕС‚РїСЂР°РІРєРё СѓРІРµРґРѕРјР»РµРЅРёР№ РІ Slack/Teams РёР»Рё Р»СЋР±РѕР№ СЃРѕРІРјРµСЃС‚РёРјС‹Р№ webhook РёСЃРїРѕР»СЊР·СѓР№С‚Рµ [`supra/scripts/testnet_monitor_slack.py`](../supra/scripts/testnet_monitor_slack.py). РћРЅ Р·Р°РїСѓСЃРєР°РµС‚ `testnet_monitor_json.py`, С„РѕСЂРјРёСЂСѓРµС‚ С‚РµРєСЃС‚РѕРІРѕРµ СЃРѕРѕР±С‰РµРЅРёРµ Рё РІРѕР·РІСЂР°С‰Р°РµС‚ С‚РѕС‚ Р¶Рµ РєРѕРґ РІРѕР·РІСЂР°С‚Р° (РїРѕРґРґРµСЂР¶РёРІР°РµС‚ `--fail-on-low` Рё РѕРїС†РёСЋ `--include-json`).
- `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::core_main_v2::get_lottery_status"`
- `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::core_main_v2::get_whitelist_status"`
- `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::core_main_v2::get_vrf_request_config"`
- `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::core_main_v2::get_client_whitelist_snapshot"`
- `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::core_main_v2::get_min_balance_limit_snapshot"`
- `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::core_main_v2::get_consumer_whitelist_snapshot"`
- `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::store::get_store_snapshot"`
- `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra move tool view --profile <PROFILE> --function-id lottery::store::get_lottery_snapshot --args u64:<LOTTERY_ID>"`
- РљРѕРЅС‚СЂРѕР»РёСЂСѓР№С‚Рµ РѕСЃС‚Р°С‚РѕРє РґРµРїРѕР·РёС‚Р° РїРѕ СЃРѕР±С‹С‚РёСЏРј `SubscriptionConfiguredEvent`/`MinimumBalanceUpdatedEvent` Рё РѕС‚С‡С‘С‚Р°Рј Supra dVRF (Supra CLI/Explorer РѕС‚СЂР°Р¶Р°РµС‚ Р±Р°Р»Р°РЅСЃ РєР»РёРµРЅС‚Р° РїРѕСЃР»Рµ `depositFundClient`).
- Р”Р»СЏ РїРѕРґСЂРѕР±РЅРѕРіРѕ РјРѕРЅРёС‚РѕСЂРёРЅРіР° СЃРѕР±С‹С‚РёР№ СЃРј. РѕС‚РґРµР»СЊРЅС‹Р№ РґРѕРєСѓРјРµРЅС‚ [dVRF event monitoring](./dvrf_event_monitoring.md) СЃ РїСЂРёРјРµСЂР°РјРё `events list` Рё `events tail`.
- Р”Р»СЏ РєРѕРЅС‚СЂРѕР»СЏ Р°СЃСЃРѕСЂС‚РёРјРµРЅС‚Р° Рё РїСЂРѕРґР°Р¶ РјР°РіР°Р·РёРЅР° РёСЃРїРѕР»СЊР·СѓР№С‚Рµ РїРѕС‚РѕРє `StoreSnapshotUpdatedEvent` (`events tail --event-type lottery::store::StoreSnapshotUpdatedEvent`) Рё Р°РіСЂРµРіРёСЂРѕРІР°РЅРЅС‹Рµ view РІС‹С€Рµ.

## 7. Troubleshooting
РЎРІРѕРґРЅР°СЏ С‚Р°Р±Р»РёС†Р° СЂР°СЃС€РёС„СЂРѕРІРѕРє Рё СЂРµС€РµРЅРёР№ РґРѕСЃС‚СѓРїРЅР° РІ РѕС‚РґРµР»СЊРЅРѕРј РґРѕРєСѓРјРµРЅС‚Рµ [dVRF error reference](./dvrf_error_reference.md).

- Р”Р»СЏ РѕРїРµСЂР°С‚РёРІРЅРѕРіРѕ Р°РЅР°Р»РёР·Р° СЃРѕР±С‹С‚РёР№ VRF РёСЃРїРѕР»СЊР·СѓР№С‚Рµ [dVRF event monitoring](./dvrf_event_monitoring.md): РѕРЅ СЃРѕРґРµСЂР¶РёС‚ РєРѕРјР°РЅРґС‹ `events list` Рё `events tail` РґР»СЏ РѕСЃРЅРѕРІРЅС‹С… СЃРѕР±С‹С‚РёР№ Р»РѕС‚РµСЂРµРё Рё РјРѕРґСѓР»СЏ `deposit`.

- **РќРµРґРѕСЃС‚Р°С‚РѕРє СЃСЂРµРґСЃС‚РІ**: СѓРІРµР»РёС‡РёС‚СЊ РґРµРїРѕР·РёС‚ Рё РїРѕРІС‚РѕСЂРЅРѕ РІС‹Р·РІР°С‚СЊ `record_client_whitelist_snapshot` РґР»СЏ С„РёРєСЃР°С†РёРё РЅРѕРІРѕРіРѕ Р»РёРјРёС‚Р°.
- **РќРµС‚ callback-Р°**: РїСЂРѕРІРµСЂРёС‚СЊ `DrawRequestedEvent`, СѓР±РµРґРёС‚СЊСЃСЏ, С‡С‚Рѕ `callbackGasLimit` РґРѕСЃС‚Р°С‚РѕС‡РµРЅ Рё С‡С‚Рѕ РєРѕРЅС‚СЂР°РєС‚ whitelisted.
- **Abort РІ `manual_draw` СЃ offset 11**: СѓР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ РІ РїСѓР»Рµ в‰ҐвЂЇ5 Р±РёР»РµС‚РѕРІ, С„Р»Р°Рі `draw_scheduled = true` (СЃРј. `get_lottery_status`), РЅРµС‚ Р°РєС‚РёРІРЅРѕРіРѕ `pending_request`, Р° Р°РґСЂРµСЃ РѕС‚РїСЂР°РІРёС‚РµР»СЏ Рё Р°РіСЂРµРіР°С‚РѕСЂ whitelisted.
- **Abort РїРѕ РєРѕРґР°Рј 11/12**: payload-С…РµС€ РЅРµ СЃРѕРІРїР°Р», Р·Р°РїСѓСЃС‚РёС‚СЊ `manual_draw` РїРѕРІС‚РѕСЂРЅРѕ РїРѕСЃР»Рµ РїСЂРѕРІРµСЂРєРё РїР°СЂР°РјРµС‚СЂРѕРІ.

Р—Р°РїРёСЃС‹РІР°Р№С‚Рµ tx hash РєР°Р¶РґРѕРіРѕ С€Р°РіР° Рё РґРѕР±Р°РІР»СЏР№С‚Рµ РІ README/CHANGELOG РґР»СЏ Р°СѓРґРёС‚Р°.

## 8. Р§РµРєР»РёСЃС‚ РґРµРїР»РѕСЏ (FA + VRF)
РћСЂРёРµРЅС‚РёСЂСѓРµРјСЃСЏ РЅР° РѕС„РёС†РёР°Р»СЊРЅС‹Рµ РёРЅСЃС‚СЂСѓРєС†РёРё Supra РїРѕ С‚РѕРєРµРЅР°Рј Рё CLI: [token-standards](https://docs.supra.com/network/move/token-standards), [fungible_asset module](https://docs.supra.com/network/move/supra-fungible-asset-fa-module), [Supra CLI with Docker](https://docs.supra.com/network/move/getting-started/supra-cli-with-docker).

1. **РџРѕРґРіРѕС‚РѕРІРєР° РѕРєСЂСѓР¶РµРЅРёСЏ**
   - РЎРѕР·РґР°С‚СЊ РїСЂРѕС„РёР»СЊ CLI: `docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra profile new <PROFILE> <PRIVATE_KEY_HEX> --network testnet"`.
   - РџСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё Р°РєС‚РёРІРёСЂРѕРІР°С‚СЊ Рё РїСЂРѕРІРµСЂРёС‚СЊ СЃРїРёСЃРѕРє: `docker compose run --rm --entrypoint bash supra_cli -lc "/supra/supra profile -l"`.
   - РџСЂРѕРІРµСЂРёС‚СЊ РїРѕРґРєР»СЋС‡РµРЅРёРµ Рє СЃРµС‚Рё: `docker compose run --rm --entrypoint bash supra_cli -lc "SUPRA_CONFIG=/supra/configs/testnet.yaml /supra/supra status --profile <PROFILE>"`.
2. **РРЅРёС†РёР°Р»РёР·Р°С†РёСЏ РєР°Р·РЅР°С‡РµР№СЃС‚РІР°**
   - `treasury_v1::is_initialized` в†’ РµСЃР»Рё `false`, РІС‹Р·РІР°С‚СЊ `treasury_v1::init_token` СЃ РїР°СЂР°РјРµС‚СЂР°РјРё РїСЂРѕРµРєС‚Р°.
   - Р—Р°С„РёРєСЃРёСЂРѕРІР°С‚СЊ tx hash Рё Р°РґСЂРµСЃ Metadata РёР· `treasury_v1::metadata_address`.
3. **Р РµРіРёСЃС‚СЂР°С†РёСЏ primary store**
   - Р”Р»СЏ Р°РґСЂРµСЃР° Р»РѕС‚РµСЂРµРё: `treasury_v1::register_store_for`.
   - Р”Р»СЏ РёРіСЂРѕРєРѕРІ Рё СЃРµСЂРІРёСЃРЅС‹С… Р°РєРєР°СѓРЅС‚РѕРІ: Р±Р°С‚С‡ `treasury_v1::register_stores_for` РёР»Рё РІСЂСѓС‡РЅСѓСЋ.
   - РџСЂРѕРІРµСЂРёС‚СЊ `treasury_v1::account_extended_status` РґР»СЏ РєР°Р¶РґРѕРіРѕ Р°РґСЂРµСЃР° (СЂРµРіРёСЃС‚СЂР°С†РёСЏ + freeze-С„Р»Р°Рі).
4. **Р—Р°РіСЂСѓР·РєР° Р±Р°Р»Р°РЅСЃРѕРІ**
   - РњРёРЅС‚ С‚РµСЃС‚РѕРІС‹С… СЃСѓРјРј С‡РµСЂРµР· `treasury_v1::mint_to` в†’ `treasury_v1::balance_of` РґР»СЏ РїСЂРѕРІРµСЂРєРё.
   - РџСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё Р·Р°РјРѕСЂРѕР·РёС‚СЊ РїРѕРґРѕР·СЂРёС‚РµР»СЊРЅС‹Рµ Р°РєРєР°СѓРЅС‚С‹ `treasury_v1::set_store_frozen`.
5. **VRF-РґРµРїРѕР·РёС‚ Рё whitelisting**
   - РќР°СЃС‚СЂРѕРёС‚СЊ Р»РёРјРёС‚С‹ РіР°Р·Р° С‡РµСЂРµР· `lottery::core_main_v2::configure_vrf_gas`.
   - Р Р°СЃСЃС‡РёС‚Р°С‚СЊ РјРёРЅРёРјР°Р»СЊРЅС‹Р№ РґРµРїРѕР·РёС‚ (С„РѕСЂРјСѓР»Р° `30 * maxGasPrice * (maxGasLimit + verificationGasValue)`), РІС‹Р·РІР°С‚СЊ `lottery::core_main_v2::create_subscription` СЃ Р·Р°РїР°СЃРѕРј Рё СѓР±РµРґРёС‚СЊСЃСЏ РІ СЃРѕР±С‹С‚РёРё `SubscriptionConfiguredEvent`.
   - РџСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё РѕР±РЅРѕРІРёС‚СЊ РјРёРЅРёРјР°Р»СЊРЅС‹Р№ Р±Р°Р»Р°РЅСЃ (`lottery::core_main_v2::set_minimum_balance`).
6. **РљРѕРЅС„РёРіСѓСЂР°С†РёСЏ Р»РѕС‚РµСЂРµРё**
   - `lottery::core_main_v2::record_client_whitelist_snapshot`, `record_consumer_whitelist_snapshot`, `configure_vrf_request`.
   - РџСЂРѕРІРµСЃС‚Рё whitelisting Р°РіСЂРµРіР°С‚РѕСЂР°/РїРѕС‚СЂРµР±РёС‚РµР»РµР№ (`whitelist_callback_sender`, `whitelist_consumer`).
   - РџСЂРѕРІРµСЂРёС‚СЊ `lottery::core_main_v2::get_lottery_status`, `get_whitelist_status`, `get_vrf_request_config`, `get_client_whitelist_snapshot`, `get_min_balance_limit_snapshot`, `get_consumer_whitelist_snapshot`.
7. **Smoke-С‚РµСЃС‚**
   - РњРёРЅС‚ С‚РѕРєРµРЅРѕРІ РґРІСѓРј РёРіСЂРѕРєР°Рј, РєСѓРїРёС‚СЊ Р±РёР»РµС‚С‹ (`buy_ticket`), Р·Р°РїСЂРѕСЃРёС‚СЊ СЂРѕР·С‹РіСЂС‹С€ (`manual_draw`).
   - РЈР±РµРґРёС‚СЊСЃСЏ, С‡С‚Рѕ `WinnerSelected` Рё `DrawHandledEvent` РїРѕСЏРІРёР»РёСЃСЊ РІ РёСЃС‚РѕСЂРёРё СЃРѕР±С‹С‚РёР№.
   - Р”Р»СЏ Р°РІС‚РѕРјР°С‚РёР·Р°С†РёРё Р±Р°Р·РѕРІРѕР№ РїСЂРѕРІРµСЂРєРё РёСЃРїРѕР»СЊР·СѓР№С‚Рµ СЃРєСЂРёРїС‚ [`supra/scripts/testnet_smoke_test.sh`](../supra/scripts/testnet_smoke_test.sh):
     РѕРЅ РєРѕРїРёСЂСѓРµС‚ YAML-РїСЂРѕС„РёР»СЊ (РµСЃР»Рё Р·Р°РґР°РЅ `SUPRA_CONFIG`), СЂРµРіРёСЃС‚СЂРёСЂСѓРµС‚ store Р°РґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂР°, РјРёРЅС‚РёС‚ СЃСЂРµРґСЃС‚РІР°, РїРѕРєСѓРїР°РµС‚ 5 Р±РёР»РµС‚РѕРІ,
     РЅР°СЃС‚СЂР°РёРІР°РµС‚ `configure_vrf_request` Рё РІС‹Р·С‹РІР°РµС‚ `manual_draw`, РїРѕСЃР»Рµ С‡РµРіРѕ РѕСЃС‚Р°С‘С‚СЃСЏ РѕС‚СЃР»РµРґРёС‚СЊ `DrawHandledEvent`.

Р’СЃРµ С€Р°РіРё Р»РѕРіРёСЂСѓРµРј РІ С‚Р°Р±Р»РёС†Сѓ (РґР°С‚Р°, РєРѕРјР°РЅРґР°, tx hash, РѕС‚РІРµС‚ view) РґР»СЏ РїРѕСЃР»РµРґСѓСЋС‰РµРіРѕ Р°СѓРґРёС‚Р°.

## 9. РџР»Р°РЅ РѕС‚РєР°С‚Р°
Р•СЃР»Рё РЅРµРѕР±С…РѕРґРёРјРѕ РІСЂРµРјРµРЅРЅРѕ РІРµСЂРЅСѓС‚СЊСЃСЏ Рє РїСЂРµРґС‹РґСѓС‰РµР№ СЌРєРѕРЅРѕРјРёРєРµ РёР»Рё РѕС‚РєР»СЋС‡РёС‚СЊ РїСЂРѕРґР°Р¶Рё:

1. **Р—Р°С„РёРєСЃРёСЂРѕРІР°С‚СЊ СЃРѕСЃС‚РѕСЏРЅРёРµ**
   - РЎРЅСЏС‚СЊ СЃРЅР°РїС€РѕС‚С‹ `treasury_v1::treasury_balance`, `total_supply`, `get_config` Рё `account_extended_status` РґР»СЏ РєР»СЋС‡РµРІС‹С… Р°РґСЂРµСЃРѕРІ.
   - Р­РєСЃРїРѕСЂС‚РёСЂРѕРІР°С‚СЊ СЃРїРёСЃРѕРє Р±РёР»РµС‚РѕРІ Рё С‚РµРєСѓС‰РёР№ `jackpot_amount` С‡РµСЂРµР· view-С„СѓРЅРєС†РёРё `lottery::core_main_v2`.

## 10. РђРІС‚РѕРјР°С‚РёР·Р°С†РёСЏ Supra Move С‚РµСЃС‚РѕРІ
- РџРµСЂРµРґ РїСѓР±Р»РёРєР°С†РёРµР№ СЂРµР»РёР·Р° РІСЂСѓС‡РЅСѓСЋ Р·Р°РїСѓСЃС‚РёС‚Рµ `PYTHONPATH=SupraLottery python -m supra.scripts.cli move-test --workspace SupraLottery/supra/move_workspace --all-packages --keep-going --report-json ci/move-test-report.json --report-junit ci/move-test-report.xml -- --skip-fetch-latest-git-deps` Рё Р·Р°С„РёРєСЃРёСЂСѓР№С‚Рµ СЂРµР·СѓР»СЊС‚Р°С‚ РІ РѕС‚С‡С‘С‚Рµ. РљРѕРјР°РЅРґР° РїРѕСЃР»РµРґРѕРІР°С‚РµР»СЊРЅРѕ РїСЂРѕРІРµСЂРёС‚ `lottery`, `lottery_factory`, `vrf_hub` Рё РґСЂСѓРіРёРµ РїР°РєРµС‚С‹ workspace, РЅРµ РїСЂРµСЂС‹РІР°СЏСЃСЊ РЅР° РїРµСЂРІРѕРј РїСЂРѕРІР°Р»Рµ; JSON (`ci/move-test-report.json`) Рё JUnit (`ci/move-test-report.xml`) РјРѕР¶РЅРѕ РїСЂРёР»РѕР¶РёС‚СЊ Рє СЂРµР»РёР·РЅРѕРјСѓ РѕС‚С‡С‘С‚Сѓ РёР»Рё Р·Р°РіСЂСѓР·РёС‚СЊ РІ CI-Р°СЂС‚РµС„Р°РєС‚С‹. РђРІС‚РѕРјР°С‚РёС‡РµСЃРєРёР№ GitHub Actions workflow РѕС‚РєР»СЋС‡С‘РЅ РїРѕ РґРѕРіРѕРІРѕСЂС‘РЅРЅРѕСЃС‚Рё вЂ” СЂРµРіСЂРµСЃСЃРёРѕРЅРЅС‹Рµ РїСЂРѕРІРµСЂРєРё РІС‹РїРѕР»РЅСЏСЋС‚СЃСЏ РѕРїРµСЂР°С‚РѕСЂРѕРј РІСЂСѓС‡РЅСѓСЋ.
- Р”Р»СЏ Р·Р°РїСѓСЃРєР° РІРЅСѓС‚СЂРё Docker СЃРѕС…СЂР°РЅРёС‚Рµ С‚Сѓ Р¶Рµ РєРѕРјР°РЅРґСѓ: `docker compose run --rm --entrypoint bash supra_cli -lc "python -m supra.scripts.cli move-test --workspace /supra/move_workspace --all-packages -- --skip-fetch-latest-git-deps"`. РџСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё РјРѕР¶РЅРѕ РїСЂРµРґРІР°СЂРёС‚РµР»СЊРЅРѕ РІС‹РІРµСЃС‚Рё СЃРїРёСЃРѕРє РїР°РєРµС‚РѕРІ С‡РµСЂРµР· `python -m supra.scripts.cli move-test --workspace /supra/move_workspace --list-packages` Р»РёР±Рѕ Р»РѕРєР°Р»СЊРЅРѕ РІС‹РїРѕР»РЅРёС‚СЊ `PYTHONPATH=SupraLottery python -m supra.scripts.cli move-test --workspace SupraLottery/supra/move_workspace --list-packages`.
- Р”Р»СЏ Р»РѕРєР°Р»СЊРЅРѕР№ РѕС‚Р»Р°РґРєРё Р±РµР· docker compose РёСЃРїРѕР»СЊР·СѓР№С‚Рµ РєРѕРјР°РЅРґСѓ РЅРёР¶Рµ (РёРґРµРЅС‚РёС‡РЅР° РѕСЃРЅРѕРІРЅРѕР№, РЅРѕ Р·Р°РїСѓСЃРє С‡РµСЂРµР· `docker run`):
  ```bash
  docker run --rm \
    -e SUPRA_HOME=/supra/configs \
    -v $(pwd)/supra/move_workspace:/supra/move_workspace \
    -v $(pwd)/supra/configs:/supra/configs \
    --entrypoint bash \
    asia-docker.pkg.dev/supra-devnet-misc/supra-testnet/validator-node:v9.0.12 \
    -lc "python -m supra.scripts.cli move-test --workspace /supra/move_workspace --all-packages -- --skip-fetch-latest-git-deps"
  ```
- Р’РµРґРёС‚Рµ Р¶СѓСЂРЅР°Р» Р·Р°РїСѓСЃРєРѕРІ (РґР°С‚Р°, commit, РєРѕРЅС„РёРіСѓСЂР°С†РёСЏ), С‡С‚РѕР±С‹ РґРµРјРѕРЅСЃС‚СЂРёСЂРѕРІР°С‚СЊ СЂРµРіСѓР»СЏСЂРЅСѓСЋ РІР°Р»РёРґР°С†РёСЋ РєР»РёРµРЅС‚Р° Supra VRF СЃРѕРіР»Р°СЃРЅРѕ СЂРµРєРѕРјРµРЅРґР°С†РёСЏРј Supra VRF Subscription FAQ.
2. **Р—Р°РјРѕСЂРѕР·РёС‚СЊ РѕРїРµСЂР°С†РёРё**
   - Р’СЂРµРјРµРЅРЅРѕ Р·Р°Р±Р»РѕРєРёСЂРѕРІР°С‚СЊ РїРѕРєСѓРїРєСѓ Р±РёР»РµС‚РѕРІ С‡РµСЂРµР· Р°РґРјРёРЅРёСЃС‚СЂР°С‚РёРІРЅСѓСЋ РЅР°СЃС‚СЂРѕР№РєСѓ С„СЂРѕРЅС‚РµРЅРґР°/СЃРєСЂРёРїС‚РѕРІ.
   - РџРѕ РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё Р·Р°РјРѕСЂРѕР·РёС‚СЊ primary store РёРіСЂРѕРєРѕРІ `treasury_v1::set_store_frozen(account, true)`.
3. **Р Р°СЃРїСЂРµРґРµР»РёС‚СЊ РѕСЃС‚Р°С‚РєРё**
   - Р’С‹РїР»Р°С‚РёС‚СЊ РґР¶РµРєРїРѕС‚ РїРѕР±РµРґРёС‚РµР»СЏРј `treasury_v1::payout_from_treasury`.
   - РЎР¶РµС‡СЊ РёР·Р»РёС€РєРё Сѓ РєР°Р·РЅР°С‡РµР№СЃС‚РІР° `treasury_v1::burn_from`.
4. **РћС‚РєР»СЋС‡РёС‚СЊ FA-РїРѕС‚РѕРєРё**
   - РћР±РЅРѕРІРёС‚СЊ `treasury_v1::set_config`, СѓСЃС‚Р°РЅРѕРІРёРІ 100% РЅР° РєР°Р·РЅР°С‡РµР№СЃС‚РІРѕ РґРѕ Р·Р°РІРµСЂС€РµРЅРёСЏ РѕС‚РєР°С‚Р°.
   - РџСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё Р°СЂС…РёРІРёСЂРѕРІР°С‚СЊ capability: С…СЂР°РЅРёС‚СЊ seed Metadata Рё tx hash `init_token` (СЃРј. [РѕС„РёС†РёР°Р»СЊРЅСѓСЋ РґРѕРєСѓРјРµРЅС‚Р°С†РёСЋ](https://docs.supra.com/network/move/token-standards)).
5. **Р”РѕРєСѓРјРµРЅС‚РёСЂРѕРІР°С‚СЊ**
- Р—Р°РґРѕРєСѓРјРµРЅС‚РёСЂРѕРІР°С‚СЊ РїСЂРёС‡РёРЅСѓ РѕС‚РєР°С‚Р°, РІСЂРµРјСЏ, РѕС‚РІРµС‚СЃС‚РІРµРЅРЅС‹С… Рё СЃСЃС‹Р»РєРё РЅР° tx.
- РћР±РЅРѕРІРёС‚СЊ README/runbook СЃ СѓРєР°Р·Р°РЅРёРµРј, РєРѕРіРґР° Рё РєР°Рє FA Р±СѓРґРµС‚ РїРѕРІС‚РѕСЂРЅРѕ РІРєР»СЋС‡РµРЅР°.

Р’РѕР·РІСЂР°С‚ Рє СЂР°Р±РѕС‚Рµ РІС‹РїРѕР»РЅСЏРµРј РІ РѕР±СЂР°С‚РЅРѕРј РїРѕСЂСЏРґРєРµ: СЂР°Р·Р±Р»РѕРєРёСЂРѕРІРєР° store, РІРѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёРµ РєРѕРЅС„РёРіСѓСЂР°С†РёРё, smoke-С‚РµСЃС‚.

## 11. Р§РµРє-Р»РёСЃС‚ С‚РёРїРёС‡РЅС‹С… РѕС€РёР±РѕРє Supra Move
- `error[E01002]: unexpected token` СЃ РєР»СЋС‡РµРІС‹Рј СЃР»РѕРІРѕРј `mut` вЂ” СѓРґР°Р»СЏР№С‚Рµ `mut`, РїРµСЂРµРјРµРЅРЅС‹Рµ Move РёР·РјРµРЅСЏРµРјС‹Рµ РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ.
- `error[E03002]: unbound module '0x1::u64'/'0x1::u128'` вЂ” РёСЃРїРѕР»СЊР·СѓР№С‚Рµ РїСЂРѕРµРєС‚РЅС‹Рµ С…РµР»РїРµСЂС‹ РґР»СЏ С‡РёСЃРµР» (`safe_add_u64`, `safe_mul_u128`, `u8_to_u64`).
- `error[E04001]`/`error[E04013]` РїСЂРё РґРѕСЃС‚СѓРїРµ Рє РєРѕРЅСЃС‚Р°РЅС‚Р°Рј РјРѕРґСѓР»РµР№ вЂ” РѕР±СЂР°С‰Р°Р№С‚РµСЃСЊ С‡РµСЂРµР· РїСѓР±Р»РёС‡РЅС‹Рµ view-С„СѓРЅРєС†РёРё Рё С‚РµСЃС‚РѕРІС‹Рµ РѕР±С‘СЂС‚РєРё.
- `error[E04004]`/`error[E04005]` РїСЂРё РѕР±РѕСЂР°С‡РёРІР°РЅРёРё РєРѕСЂС‚РµР¶РµР№ РІ `Option` вЂ” Р·Р°РјРµРЅСЏР№С‚Рµ РєРѕСЂС‚РµР¶Рё РѕС‚РґРµР»СЊРЅС‹РјРё СЃС‚СЂСѓРєС‚СѓСЂР°РјРё `*_View`.
- РџРѕР»РЅС‹Р№ СЃРїСЂР°РІРѕС‡РЅРёРє СЃ РєРѕРґР°РјРё РѕС€РёР±РѕРє СЃРј. РІ РґРѕРєСѓРјРµРЅС‚Рµ [docs/move_common_errors_ru.md](move_common_errors_ru.md).


### 3.11 Оффлайн и демо режим

- Если необходимо показать розыгрыш без dVRF (демо, песочница), используйте `core_main_v2::simple_draw`. Команда аналогична другим вызовам CLI:
  ```bash
  docker compose -f SupraLottery/compose.yaml run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile <PROFILE> --function-id lottery::core_main_v2::simple_draw --gas-unit-price 100 --max-gas 5000 --expiration-secs 300"
  ```
- После оффлайн-розыгрыша проверьте `get_lottery_status` — счётчики VRF не увеличиваются, поэтому перед возвращением к `request_draw` убедитесь, что `pending_request` очищен.
- Коды ошибок и рекомендации собраны в [справочнике dVRF 3.0](../../docs/dvrf_error_reference.md).
