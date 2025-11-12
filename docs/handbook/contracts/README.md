# Контракты SupraLottery

## Пакеты Move
- [`core`](../../SupraLottery/supra/move_workspace/core/sources) — системные ресурсы и депозиты VRF.
- [`support`](../../SupraLottery/supra/move_workspace/support/sources) — общие утилиты и хранилища.
- [`reward`](../../SupraLottery/supra/move_workspace/reward/sources) — призовые пулы, NFT-награды.
- [`lottery_multi`](../../SupraLottery/supra/move_workspace/lottery_multi/sources) — параллельные лотереи и вспомогательные сервисы.

Каждый пакет описан в отдельных файлах:
- [core.md](core.md)
- [support.md](support.md)
- [reward.md](reward.md)
- [lottery_multi.md](lottery_multi.md) — модули, функции и события, добавленные на этапах 1–2 RFC v1.
- [lottery_multi_stage_playbook.md](lottery_multi_stage_playbook.md) — пошаговое описание механик этапов 3–6 и связь с тестами.
- [tags_policy.md](tags_policy.md) — политика классификаторов, допустимые комбинации тегов и ручные исключения.

### Структура описания модуля
Для каждого Move-модуля используйте шаблон `contracts/<module>/functions.md`:
```
## module::function
- Сигнатура
- Назначение
- Предусловия (assert!/abort)
- Постусловия
- Используемые события
- Требуемые capability
- Связанные разделы документации
```

Комментарии в коде должны содержать ссылки вида:
```move
/// Docs: docs/handbook/contracts/lottery_multi.md#registry
```

Все файлы в этом разделе ведутся на русском языке, за исключением выдержек из кода.
