# Коды ошибок

| Код | Модуль | Описание |
| --- | --- | --- |
| `0xE_TAG_PRIMARY_TYPE` | `lottery_multi::tags` | Некорректный основной тип лотереи |
| `0xE_CONFIG_INVALID_DISTRIBUTION` | `lottery_multi::registry` | Сумма распределений продаж не равна 10_000 bps |
| `0xE_SNAPSHOT_FROZEN` | `lottery_multi::sales` | Попытка изменить билеты после фиксации снапшота |
| `0xE_VRF_PAYLOAD_SCHEMA` | `lottery_multi::types` | Payload VRF не соответствует текущей схеме |
| `0xE_VRF_CONSUMED` | `lottery_multi::draw` | Повторный fulfill для уже обработанного запроса |
| `0xE_WINNER_CURSOR_STALE` | `lottery_multi::payouts` | Батч победителей запущен с устаревшей позиции |
| `0xE_PAYOUT_ALLOWANCE` | `lottery_multi::economics` | Недостаточно средств или превышен allowance джекпота |
| `0xE_JACKPOT_ALLOWANCE_INCREASE` | `lottery_multi::economics` | Попытка увеличить `jackpot_allowance_token` после инициализации |
| `0xE_RATE_LIMIT` | `lottery_multi::sales` | Превышен лимит покупок за окно |
| `0xE_FEATURE_DISABLED` | `lottery_multi::feature_switch` | Попытка вызвать отключённую функцию |
| `0xE_PRICE_STALE` | `lottery_multi::price_feed` | Данные прайс-фида устарели |
| `0xE_PRICE_FALLBACK_ACTIVE` | `lottery_multi::price_feed` | Попытка использовать цену при активном fallback |
| `0xE_PRICE_CLAMP_ACTIVE` | `lottery_multi::price_feed` | Попытка использовать цену при активном клампе |
| `0xE_PRICE_CLAMP_NOT_ACTIVE` | `lottery_multi::price_feed` | Попытка снять кламп, который уже отключён |
| `0xE_AUTOMATION_LOCKED` | `lottery_multi::automation` | Нарушен таймлок или недостаточная репутация бота |

Полный перечень ошибок хранится в `SupraLottery/supra/move_workspace/lottery_multi/sources/errors.move`.
