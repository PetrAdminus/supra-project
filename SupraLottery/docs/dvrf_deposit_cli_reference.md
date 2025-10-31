# Supra dVRF 3.0 вЂ” CLI СЃРїСЂР°РІРѕС‡РЅРёРє РїРѕ РјРѕРґСѓР»СЋ `deposit`

Р”РѕРєСѓРјРµРЅС‚ РґРѕРїРѕР»РЅСЏРµС‚ [testnet_runbook](./testnet_runbook.md) Рё СЃРѕР±РёСЂР°РµС‚ РІСЃРµ
Р°РєС‚СѓР°Р»СЊРЅС‹Рµ РєРѕРјР°РЅРґС‹ Supra CLI РґР»СЏ РІР·Р°РёРјРѕРґРµР№СЃС‚РІРёСЏ СЃ РјРѕРґСѓР»РµРј
`0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e::deposit`.
Р’СЃРµ РїСЂРёРјРµСЂС‹ Р·Р°РїСѓСЃРєР°СЋС‚СЃСЏ С‡РµСЂРµР· Docker Рё РїСЂРµРґРїРѕР»Р°РіР°СЋС‚, С‡С‚Рѕ РІС‹ СѓР¶Рµ СЃРѕР·РґР°Р»Рё
РїСЂРѕС„РёР»СЊ (`supra profile new вЂ¦`) Рё, РїСЂРё РЅРµРѕР±С…РѕРґРёРјРѕСЃС‚Рё, СЌРєСЃРїРѕСЂС‚РёСЂРѕРІР°Р»Рё
`SUPRA_CONFIG=/supra/configs/testnet.yaml`.

> Р”Р»СЏ Р±С‹СЃС‚СЂРѕР№ РїСЂРѕРІРµСЂРєРё СЃС‚Р°С‚СѓСЃР° РїРѕРґРїРёСЃРєРё РјРѕР¶РЅРѕ РІРѕСЃРїРѕР»СЊР·РѕРІР°С‚СЊСЃСЏ СЃРєСЂРёРїС‚РѕРј
> [`supra/scripts/testnet_status_report.sh`](../supra/scripts/testnet_status_report.sh):
> РѕРЅ РІС‹Р·С‹РІР°РµС‚ РєР»СЋС‡РµРІС‹Рµ view-С„СѓРЅРєС†РёРё РґРµРїРѕР·РёС‚Р° Рё РєРѕРЅС‚СЂР°РєС‚Р° Рё РІС‹РІРѕРґРёС‚ РёС…
> РІ РѕРґРЅРѕРј РѕС‚С‡С‘С‚Рµ. Р”Р»СЏ Р°РІС‚РѕРјР°С‚РёР·РёСЂРѕРІР°РЅРЅРѕРіРѕ РєРѕРЅС‚СЂРѕР»СЏ РјРёРЅРёРјР°Р»СЊРЅРѕРіРѕ Р±Р°Р»Р°РЅСЃР°
> РёСЃРїРѕР»СЊР·СѓР№С‚Рµ [`supra/scripts/testnet_monitor_check.sh`](../supra/scripts/testnet_monitor_check.sh) вЂ”
> СЃРєСЂРёРїС‚ СЂР°СЃСЃС‡РёС‚С‹РІР°РµС‚ `min_balance` РїРѕ С‚РµРєСѓС‰РёРј Р»РёРјРёС‚Р°Рј РіР°Р·Р°,
> СЃСЂР°РІРЅРёРІР°РµС‚ СЃ СЂРµР·СѓР»СЊС‚Р°С‚РѕРј `checkClientFund` Рё Р·Р°РІРµСЂС€Р°РµС‚ СЂР°Р±РѕС‚Сѓ СЃ РѕС€РёР±РєРѕР№,
> РµСЃР»Рё РґРµРїРѕР·РёС‚ РѕРїСѓСЃС‚РёР»СЃСЏ РґРѕ РїРѕСЂРѕРіРѕРІРѕРіРѕ Р·РЅР°С‡РµРЅРёСЏ. Р РµРєРѕРјРµРЅРґР°С†РёРё РїРѕ Р·Р°РїСѓСЃРєСѓ РїРѕ СЂР°СЃРїРёСЃР°РЅРёСЋ, С‡РµСЂРµР· CI Рё Supra AutoFi СЃРјРѕС‚СЂРёС‚Рµ РІ [РѕС‚РґРµР»СЊРЅРѕРј СЂСѓРєРѕРІРѕРґСЃС‚РІРµ](./dvrf_monitoring_automation.md).
> Р”Р»СЏ РјР°С€РёРЅРѕС‡РёС‚Р°РµРјРѕРіРѕ РІС‹РІРѕРґР° Рё РёРЅС‚РµРіСЂР°С†РёРё СЃ AutoFi/CI РёСЃРїРѕР»СЊР·СѓР№С‚Рµ `python supra/scripts/testnet_monitor_json.py --pretty --fail-on-low` вЂ” СЃРєСЂРёРїС‚ РїРѕРІС‚РѕСЂРЅРѕ РёСЃРїРѕР»СЊР·СѓРµС‚ С„РѕСЂРјСѓР»С‹ `calc_min_balance.py`, РІС‹Р·С‹РІР°РµС‚ `view`-С„СѓРЅРєС†РёРё `deposit` Рё РІРѕР·РІСЂР°С‰Р°РµС‚ `exit=1`, РµСЃР»Рё Р±Р°Р»Р°РЅСЃ РЅРёР¶Рµ СЂР°СЃС‡С‘С‚РЅРѕРіРѕ `min_balance`.

> РќР°С‡РёРЅР°СЏ СЃ Supra CLI 2025.05 СѓС‚РёР»РёС‚Р° РёС‰РµС‚ Р°РєС‚РёРІРЅС‹Р№ РїСЂРѕС„РёР»СЊ РІ
> `/supra/.aptos/config.yaml`. РџРµСЂРµРґ Р·Р°РїСѓСЃРєРѕРј РєРѕРјР°РЅРґ СЃРєРѕРїРёСЂСѓР№С‚Рµ YAML
> (РЅР°РїСЂРёРјРµСЂ, `supra/configs/testnet.yaml`) РІ РєРѕРЅС‚РµР№РЅРµСЂ: `docker compose run
> --rm --entrypoint bash supra_cli -lc "mkdir -p /supra/.aptos && cp
> /supra/configs/testnet.yaml /supra/.aptos/config.yaml"`.

## Р‘Р°Р·РѕРІС‹Рµ РїРµСЂРµРјРµРЅРЅС‹Рµ РѕРєСЂСѓР¶РµРЅРёСЏ

```bash
export PROFILE=my_new_profile
export SUPRA_CONFIG=/supra/configs/testnet.yaml
export DEPOSIT_ADDR=0x186ba2ba88f4a14ca51f6ce42702c7ebdf6bfcf738d897cc98b986ded6f1219e
export LOTTERY_ADDR=0xbc959517601034979f21fa2f2f41862219ea38554be27c2fdb4fd9a392caafe0
export MAX_GAS_PRICE=1000
export MAX_GAS_LIMIT=500000
export CALLBACK_GAS_PRICE=100
export CALLBACK_GAS_LIMIT=150000
export MIN_BALANCE_LIMIT=15375000000   # РїСЂРёРјРµСЂ РёР· runbook
```

> Р’РјРµСЃС‚Рѕ СЂСѓС‡РЅРѕРіРѕ СЌРєСЃРїРѕСЂС‚Р° РјРѕР¶РЅРѕ СЃРєРѕРїРёСЂРѕРІР°С‚СЊ `supra/scripts/testnet_env.example`,
> РѕС‚СЂРµРґР°РєС‚РёСЂРѕРІР°С‚СЊ Р·РЅР°С‡РµРЅРёСЏ Рё РІС‹РїРѕР»РЅРёС‚СЊ `set -a; source supra/scripts/testnet_env.local; set +a`.
> Р”Р»СЏ СЂР°СЃС‡С‘С‚Р° `MIN_BALANCE_LIMIT` РёСЃРїРѕР»СЊР·СѓР№С‚Рµ `python supra/scripts/calc_min_balance.py --max-gas-price $MAX_GAS_PRICE --max-gas-limit $MAX_GAS_LIMIT --verification-gas $VERIFICATION_GAS_VALUE --margin 0.15` вЂ” СЃРєСЂРёРїС‚ РїРѕРєР°Р¶РµС‚ `per_request_fee`, `min_balance` Рё СЂРµРєРѕРјРµРЅРґСѓРµРјС‹Р№ РґРµРїРѕР·РёС‚.

> Supra CLI РёС‰РµС‚ `config.yaml` РІ РєР°С‚Р°Р»РѕРіРµ `/supra/.aptos`. РџСЂРё СЂР°Р±РѕС‚Рµ
> РІ РєРѕРЅС‚РµР№РЅРµСЂРµ РІС‹РїРѕР»РЅРёС‚Рµ РѕРґРёРЅ СЂР°Р·: `docker compose run --rm --entrypoint
> bash supra_cli -lc "mkdir -p /supra/.aptos && cp /supra/configs/testnet.yaml
> /supra/.aptos/config.yaml"`.

## РћРЅР±РѕСЂРґРёРЅРі РєР»РёРµРЅС‚Р° dVRF

| РљРѕРјР°РЅРґР° | РќР°Р·РЅР°С‡РµРЅРёРµ | РџСЂРёРјРµСЂ |
| --- | --- | --- |
| `migrateClient(max_gas_price, max_gas_limit)` | Р РµРіРёСЃС‚СЂРёСЂСѓРµС‚ РєР»РёРµРЅС‚Р° РІ dVRF 3.0, СЃРѕС…СЂР°РЅСЏСЏ Р»РёРјРёС‚С‹ РіР°Р·Р°. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::migrateClient --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT --assume-yes"` |
| `addClientToWhitelist(max_gas_price, max_gas_limit)` | РђРєС‚РёРІРёСЂСѓРµС‚ РєР»РёРµРЅС‚Р° РЅР° СЃС‚РѕСЂРѕРЅРµ Supra. Р’РѕР·РІСЂР°С‰Р°РµС‚ РѕС€РёР±РєСѓ `ECLIENT_NOT_EXIST`, РµСЃР»Рё `migrateClient` РµС‰С‘ РЅРµ РїСЂРѕС€С‘Р». | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::addClientToWhitelist --args u128:$MAX_GAS_PRICE u128:$MAX_GAS_LIMIT --assume-yes"` |
| `clientSettingMinimumBalance(min_balance)` | Р¤РёРєСЃРёСЂСѓРµС‚ РјРёРЅРёРјР°Р»СЊРЅС‹Р№ Р±Р°Р»Р°РЅСЃ, РєРѕС‚РѕСЂС‹Р№ Supra Р±СѓРґРµС‚ РєРѕРЅС‚СЂРѕР»РёСЂРѕРІР°С‚СЊ. РљРѕРЅС‚СЂР°РєС‚ РІС‹Р·С‹РІР°РµС‚ СЌС‚Сѓ С„СѓРЅРєС†РёСЋ РІРЅСѓС‚СЂРё `create_subscription`. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::clientSettingMinimumBalance --args u128:$MIN_BALANCE_LIMIT --assume-yes"` |
| `depositFundClient(amount)` | РџРѕРїРѕР»РЅСЏРµС‚ РґРµРїРѕР·РёС‚ РєР»РёРµРЅС‚Р°. РџСЂРё РёСЃРїРѕР»СЊР·РѕРІР°РЅРёРё `create_subscription` СЌС‚Р° С„СѓРЅРєС†РёСЏ РІС‹Р·С‹РІР°РµС‚СЃСЏ Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєРё. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::depositFundClient --args u64:20000000000 --assume-yes"` |
| `addContractToWhitelist(contract_addr, callback_gas_price, callback_gas_limit)` | РџСЂРёРІСЏР·С‹РІР°РµС‚ РєРѕРЅРєСЂРµС‚РЅС‹Р№ РєРѕРЅС‚СЂР°РєС‚-РїРѕС‚СЂРµР±РёС‚РµР»СЊ Рє РїРѕРґРїРёСЃРєРµ. `create_subscription` РІС‹Р·С‹РІР°РµС‚ РµС‘ РґР»СЏ Р°РґСЂРµСЃР° Р»РѕС‚РµСЂРµРё. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::addContractToWhitelist --args address:$LOTTERY_ADDR u128:$CALLBACK_GAS_PRICE u128:$CALLBACK_GAS_LIMIT --assume-yes"` |

## РЈРїСЂР°РІР»РµРЅРёРµ Р»РёРјРёС‚Р°РјРё

РџРѕСЃР»Рµ РѕРЅР±РѕСЂРґРёРЅРіР° Supra РїРѕР·РІРѕР»СЏРµС‚ РѕР±РЅРѕРІР»СЏС‚СЊ Р»РёРјРёС‚С‹ Р±РµР· РїРѕРІС‚РѕСЂРЅРѕРіРѕ СЃРѕР·РґР°РЅРёСЏ
РїРѕРґРїРёСЃРєРё.

```bash
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run \
  --profile $PROFILE \
  --function-id $DEPOSIT_ADDR::deposit::updateMaxGasPrice \
  --args u128:1200 --assume-yes"

docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run \
  --profile $PROFILE \
  --function-id $DEPOSIT_ADDR::deposit::updateMaxGasLimit \
  --args u128:600000 --assume-yes"

docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run \
  --profile $PROFILE \
  --function-id $DEPOSIT_ADDR::deposit::updateCallbackGasPrice \
  --args address:$LOTTERY_ADDR u128:150 --assume-yes"

docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run \
  --profile $PROFILE \
  --function-id $DEPOSIT_ADDR::deposit::updateCallbackGasLimit \
  --args address:$LOTTERY_ADDR u128:180000 --assume-yes"
```

> РџСЂРё РѕР±РЅРѕРІР»РµРЅРёРё Р»РёРјРёС‚РѕРІ РЅРµ Р·Р°Р±С‹РІР°Р№С‚Рµ РїРµСЂРµСЃС‡РёС‚Р°С‚СЊ РјРёРЅРёРјР°Р»СЊРЅС‹Р№ Р±Р°Р»Р°РЅСЃ С‡РµСЂРµР·
> `lottery::core_main_v2::calculate_min_balance` Рё РІС‹Р·РІР°С‚СЊ `set_minimum_balance`,
> РµСЃР»Рё Supra С‚СЂРµР±СѓРµС‚ СЃРёРЅС…СЂРѕРЅРёР·Р°С†РёРё Р·РЅР°С‡РµРЅРёСЏ.

## РџСЂРѕРІРµСЂРєР° СЃРѕСЃС‚РѕСЏРЅРёСЏ РїРѕРґРїРёСЃРєРё

| Р¤СѓРЅРєС†РёСЏ | Р§С‚Рѕ РїРѕРєР°Р·С‹РІР°РµС‚ | РџСЂРёРјРµСЂ |
| --- | --- | --- |
| `checkMinBalanceClient(address)` | РўРµРєСѓС‰РёР№ РјРёРЅРёРјР°Р»СЊРЅС‹Р№ Р±Р°Р»Р°РЅСЃ РґР»СЏ РєР»РёРµРЅС‚Р°. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::checkMinBalanceClient --args address:$LOTTERY_ADDR"` |
| `checkMaxGasPriceClient(address)` | РЎРѕС…СЂР°РЅС‘РЅРЅС‹Р№ `maxGasPrice`. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::checkMaxGasPriceClient --args address:$LOTTERY_ADDR"` |
| `checkMaxGasLimitClient(address)` | РЎРѕС…СЂР°РЅС‘РЅРЅС‹Р№ `maxGasLimit`. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::checkMaxGasLimitClient --args address:$LOTTERY_ADDR"` |
| `getContractDetails(address)` | РџР°СЂР° `(callbackGasPrice, callbackGasLimit)` РґР»СЏ whitelisted РєРѕРЅС‚СЂР°РєС‚Р°. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::getContractDetails --args address:$LOTTERY_ADDR"` |
| `checkClientFund(address)` | РўРµРєСѓС‰РёР№ Р±Р°Р»Р°РЅСЃ РґРµРїРѕР·РёС‚Р° РєР»РёРµРЅС‚Р°. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::checkClientFund --args address:$LOTTERY_ADDR"` |
| `isMinimumBalanceReached(address)` | РџРѕРєР°Р·С‹РІР°РµС‚, РѕРїСѓСЃС‚РёР»СЃСЏ Р»Рё РґРµРїРѕР·РёС‚ РґРѕ РјРёРЅРёРјР°Р»СЊРЅРѕРіРѕ Р±Р°Р»Р°РЅСЃР°. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::isMinimumBalanceReached --args address:$LOTTERY_ADDR"` |
| `countTotalWhitelistedContractByClient(address)` | РљРѕР»РёС‡РµСЃС‚РІРѕ whitelisted РєРѕРЅС‚СЂР°РєС‚РѕРІ РґР»СЏ РєР»РёРµРЅС‚Р°. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::countTotalWhitelistedContractByClient --args address:$LOTTERY_ADDR"` |
| `listAllWhitelistedContractByClient(address)` | РЎРїРёСЃРѕРє Р°РґСЂРµСЃРѕРІ whitelisted РєРѕРЅС‚СЂР°РєС‚РѕРІ. | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::listAllWhitelistedContractByClient --args address:$LOTTERY_ADDR"` |
| `getSubscriptionInfoByClient(address)` | РњРµС‚Р°РґР°РЅРЅС‹Рµ РїРѕРґРїРёСЃРєРё (РЅР°РїСЂРёРјРµСЂ, SNAP-РїСЂРѕРіСЂР°РјРјР°, С‚Р°Р№РјСЃС‚РµРјРї). | `docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool view --profile $PROFILE --function-id $DEPOSIT_ADDR::deposit::getSubscriptionInfoByClient --args address:$LOTTERY_ADDR"` |

Р”Р»СЏ РїРѕР»СѓС‡РµРЅРёСЏ РёСЃС‚РѕСЂРёРё РѕРїРµСЂР°С†РёР№ (РЅР°РїСЂРёРјРµСЂ, РїРѕРїРѕР»РЅРµРЅРёСЏ РґРµРїРѕР·РёС‚Р°) РёСЃРїРѕР»СЊР·СѓР№С‚Рµ
`move tool events list --address $DEPOSIT_ADDR --limit 20`.

## Р¤РёРЅР°РЅСЃРѕРІС‹Рµ РѕРїРµСЂР°С†РёРё

```bash
# Р”РѕРїРѕР»РЅРёС‚РµР»СЊРЅРѕ РїРѕРїРѕР»РЅРёС‚СЊ РґРµРїРѕР·РёС‚
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run \
  --profile $PROFILE \
  --function-id $DEPOSIT_ADDR::deposit::depositFundClient \
  --args u64:5000000000 --assume-yes"

# Р’С‹РІРµСЃС‚Рё СЃСЂРµРґСЃС‚РІР° (РµСЃР»Рё РЅРµС‚ Р°РєС‚РёРІРЅС‹С… Р·Р°РїСЂРѕСЃРѕРІ)
docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CONFIG:+SUPRA_CONFIG=$SUPRA_CONFIG }/supra/supra move tool run \
  --profile $PROFILE \
  --function-id $DEPOSIT_ADDR::deposit::withdrawFundClient \
  --args u64:1000000000 --assume-yes"
```

> Supra Р·Р°РїСЂРµС‰Р°РµС‚ РІС‹РІРѕРґ, РµСЃР»Рё Сѓ РєР»РёРµРЅС‚Р° РµСЃС‚СЊ РЅРµР·Р°РІРµСЂС€С‘РЅРЅС‹Рµ Р·Р°РїСЂРѕСЃС‹ VRF.
> РџСЂРѕРІРµСЂСЏР№С‚Рµ `lottery::core_main_v2::get_lottery_status` Рё СЃРѕР±С‹С‚РёСЏ `DrawHandledEvent`.

## Р Р°СЃРїСЂРѕСЃС‚СЂР°РЅС‘РЅРЅС‹Рµ РѕС€РёР±РєРё

| РЎРѕРѕР±С‰РµРЅРёРµ | РџСЂРёС‡РёРЅР° | Р§С‚Рѕ РґРµР»Р°С‚СЊ |
| --- | --- | --- |
| `ECLIENT_ALREADY_EXIST` | РљР»РёРµРЅС‚ СѓР¶Рµ Р·Р°СЂРµРіРёСЃС‚СЂРёСЂРѕРІР°РЅ С‡РµСЂРµР· `migrateClient`. | РџСЂРѕРґРѕР»Р¶Р°Р№С‚Рµ СЃ `addClientToWhitelist` вЂ” РїРѕРІС‚РѕСЂРЅС‹Р№ РІС‹Р·РѕРІ `migrateClient` РЅРµ С‚СЂРµР±СѓРµС‚СЃСЏ. |
| `ECLIENT_NOT_EXIST` | Supra РµС‰С‘ РЅРµ Р·Р°С„РёРєСЃРёСЂРѕРІР°Р»Р° РєР»РёРµРЅС‚Р°; РїРѕРїС‹С‚РєР° РґРѕР±Р°РІРёС‚СЊ РІ whitelist РёР»Рё СЃРѕР·РґР°С‚СЊ РїРѕРґРїРёСЃРєСѓ СЃР»РёС€РєРѕРј СЂР°РЅРѕ. | РџРѕРІС‚РѕСЂРёС‚Рµ `migrateClient`, РґРѕР¶РґРёС‚РµСЃСЊ РїРѕРґС‚РІРµСЂР¶РґРµРЅРёСЏ Рё РїРѕРІС‚РѕСЂРёС‚Рµ РєРѕРјР°РЅРґСѓ С‡РµСЂРµР· 1вЂ“2 РјРёРЅСѓС‚С‹. |
| `FUNCTION_RESOLUTION_FAILURE` | РќРµРІРµСЂРЅРѕРµ РёРјСЏ С„СѓРЅРєС†РёРё (snake_case РІРјРµСЃС‚Рѕ camelCase) РёР»Рё СѓСЃС‚Р°СЂРµРІС€Р°СЏ РІРµСЂСЃРёСЏ CLI. | РСЃРїРѕР»СЊР·СѓР№С‚Рµ РёРґРµРЅС‚РёС„РёРєР°С‚РѕСЂС‹ РёР· РѕС„РёС†РёР°Р»СЊРЅРѕР№ РґРѕРєСѓРјРµРЅС‚Р°С†РёРё Supra (`migrateClient`, `addClientToWhitelist`, Рё С‚.Рґ.) Рё РІС‹Р·С‹РІР°Р№С‚Рµ РёС… С‡РµСЂРµР· `move tool run --profile вЂ¦ --function-id deposit::functionName`. |
| `E_CALLBACK_LIMIT_INVALID` | Р—РЅР°С‡РµРЅРёСЏ `callbackGasPrice`/`callbackGasLimit` РЅРёР¶Рµ РјРёРЅРёРјР°Р»СЊРЅРѕ РґРѕРїСѓСЃС‚РёРјС‹С…. | РЈРІРµР»РёС‡СЊС‚Рµ Р»РёРјРёС‚С‹ (СЃРј. РѕС„РёС†РёР°Р»СЊРЅСѓСЋ С‚Р°Р±Р»РёС†Сѓ РјРёРЅРёРјР°Р»СЊРЅС‹С… Р·РЅР°С‡РµРЅРёР№ РІ РґРѕРєСѓРјРµРЅС‚Р°С†РёРё Supra). |

## РЎРІСЏР·Р°РЅРЅС‹Рµ РјР°С‚РµСЂРёР°Р»С‹

- [Testnet runbook](./testnet_runbook.md)
- [Walkthrough РґР»СЏ РїСЂРѕС„РёР»СЏ `my_new_profile`](./dvrf_testnet_my_new_profile_walkthrough.md)
- [РЎРїСЂР°РІРѕС‡РЅРёРє РѕС€РёР±РѕРє dVRF](./dvrf_error_reference.md)
- [РњРѕРЅРёС‚РѕСЂРёРЅРі СЃРѕР±С‹С‚РёР№ dVRF](./dvrf_event_monitoring.md)
- [РђРІС‚РѕРјР°С‚РёР·Р°С†РёСЏ РјРѕРЅРёС‚РѕСЂРёРЅРіР° (cron/AutoFi, Slack webhook)](./dvrf_monitoring_automation.md)

