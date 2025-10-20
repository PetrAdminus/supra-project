# Оценка рисков при снятии friend-ограничений

## Рекомендации Supra по видимости функций

> «A `public` function can be called by *any* function defined in *any* module or script.» — [Supra Move Book, Functions → Visibility](https://docs.supra.com/network/move/move-book/basic-concepts/functions).  
> «The `public(friend)` visibility modifier ... A `public(friend)` function can be called by other functions defined in the same module, or functions defined in modules which are explicitly specified in the friend list.» — [Supra Move Book, Functions → Visibility](https://docs.supra.com/network/move/move-book/basic-concepts/functions).  
> «The `friend` syntax is used to declare modules that are trusted by the current module.» — [Supra Move Book, Friends](https://docs.supra.com/network/move/move-book/basic-concepts/friends).

Документация подчёркивает, что перевод `public(friend)` функций на `public` снимает все ограничения и позволяет вызывать их из любых модулей и скриптов, включая сторонние деплойменты. Любые инварианты, которые сегодня обеспечиваются только доверенными вызовами, придётся дублировать дополнительными проверками (подпись администратора, allow-list и т.д.).

## Общие выводы

- Без дополнительных гардов перевод на `public` раскрывает функции финансового ядра (распределение выплат, учёт бонусов, миграция состояния) для произвольных вызовов, что создаёт риск обнуления пулов или подмены статистики.  
- Функции, которые раньше были `public(friend)`, уже переведены на `public(package)`: доступ сохранится внутри пакета, но внешние модули и скрипты по-прежнему ограничены.
- Перед снятием ограничений нужно внедрить явную авторизацию (например, требовать администратора через `signer`) или перевести чувствительные операции в `entry`-функции, которые сами выполняют внутренние вызовы безопасных помощников.

## Анализ функций Supra Lottery

### Treasury.move
- `distribute_payout` уже переведён на `public(package)`. Полное раскрытие до `public` без дополнительной авторизации позволило бы переводить любую сумму с баланса казны, поэтому перед изменением требуется обёртка с проверкой администратора или явный allow-list модулей.【F:SupraLottery/supra/move_workspace/lottery/sources/Treasury.move†L601-L650】

### TreasuryMulti.move
- `record_allocation_internal` и `record_operations_income_internal` доступны как `public(package)`, что защищает от внешних вызовов. Перед переходом на `public` необходимо внедрить авторизацию, иначе злоумышленник сможет бесплатно увеличивать аллокации или начислять доход, нарушая балансы.【F:SupraLottery/supra/move_workspace/lottery/sources/TreasuryMulti.move†L297-L388】
- `distribute_prize_internal`, `withdraw_operations_internal`, `pay_operations_bonus_internal` и `distribute_jackpot_internal` также ограничены `public(package)`. Их перевод на `public` без подписей администраторов даст возможность вывести ликвидность из пулов; потребуются строгие проверки `signer` или сохранение пакетной видимости.【F:SupraLottery/supra/move_workspace/lottery/sources/TreasuryMulti.move†L330-L408】
- `pool_prize_balance`, `pool_operations_balance`, `share_config_*`, `summary_*` возвращают внутренние структуры и пока остаются `public(package)`. Прежде чем раскрывать их наружу, убедитесь, что это не нарушит инварианты сериализации и не выдаст данные миграции раньше времени.【F:SupraLottery/supra/move_workspace/lottery/sources/TreasuryMulti.move†L485-L511】

### LotteryRounds.move
- `record_prepaid_purchase` и `migrate_import_round` ограничены `public(package)`, поэтому их по-прежнему могут вызывать только модули пакета. Полное раскрытие потребует проверок администратора и защиту от подмены состояния перед тем, как разрешать внешние вызовы.【F:SupraLottery/supra/move_workspace/lottery/sources/LotteryRounds.move†L157-L170】【F:SupraLottery/supra/move_workspace/lottery/sources/LotteryRounds.move†L469-L504】

### LotteryInstances.move
- `record_ticket_sale` и `migrate_override_stats` теперь `public(package)`, что удерживает вызовы внутри пакета. Расширение до `public` без проверок приведёт к накрутке статистики и неверным джекпотам, поэтому перед изменением нужны авторизационные проверки или отдельные безопасные обёртки.【F:SupraLottery/supra/move_workspace/lottery/sources/LotteryInstances.move†L417-L444】

### Vip.move
- `bonus_tickets_for` и `record_bonus_usage` ограничены `public(package)` и используются только внутренними модулями. Перевод на `public` потребует лимитов и контроля подписей, иначе появится возможность бесконтрольно списывать или выдавать бонусы.【F:SupraLottery/supra/move_workspace/lottery/sources/Vip.move†L331-L370】

### History.move
- `record_draw` остался внутри пакета (`public(package)`), что предотвращает фиктивные розыгрыши. Для полного раскрытия понадобится проверка администратора и защита от повторных вызовов извне.【F:SupraLottery/supra/move_workspace/lottery/sources/History.move†L118-L134】

### Referrals.move
- `record_purchase` ограничена `public(package)` и недоступна внешним модулям. Прежде чем делать её `public`, требуется авторизованный вызывающий или отдельная безопасная `entry`-обёртка, иначе бонусы можно будет начислять без фактических покупок.【F:SupraLottery/supra/move_workspace/lottery/sources/Referrals.move†L296-L402】

### Lottery.move
- `export_state_for_migration` и `clear_state_after_migration` уже `public(package)` и доступны только миграционным модулям пакета. Открытие их наружу потребует строгой авторизации и, возможно, отдельного формата вывода, чтобы не позволять сбрасывать состояние произвольно.【F:SupraLottery/supra/move_workspace/lottery/sources/Lottery.move†L261-L282】

## Рекомендации

1. Регулярно прогонять `move check`/`move test` для автономных пакетов (`lottery`, `lottery_factory`, `vrf_hub`), чтобы отследить любые регрессии в доступе после удаления friend-зависимостей.
2. Прежде чем делать функцию полностью `public`, добавить проверку администратора или операторского списка с использованием `signer`, либо выделить безопасную `entry`-обёртку, которую будет вызывать фронт/скрипты.
3. Для чисто утилитарных геттеров рассмотреть `#[view] public` только после проверки, что выдаваемые данные не раскрывают миграционные структуры раньше времени.
