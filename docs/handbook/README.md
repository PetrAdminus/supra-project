# Руководство SupraLottery

Этот справочник служит точкой входа в проект SupraLottery и описывает архитектуру мульти-лотерейной платформы, основываясь на RFC v1.

## Как пользоваться книгой
- **Архитектура** — высокоуровневое устройство пакетов Move, off-chain сервисов и жизненного цикла розыгрышей. См. [architecture/overview.md](architecture/overview.md).
- **Управление доступом** — роли, capability и процедуры выдачи/отзыва. См. [governance/roles.md](governance/roles.md).
- **Контракты** — описание пакетов `core`, `support`, `reward`, `lottery_multi` и их API. Стартовая страница: [contracts/README.md](contracts/README.md).
- **Операции** — runbook для администраторов, партнёров, пострелизная поддержка и журналирование. См. [operations/runbooks.md](operations/runbooks.md), [operations/post_release_support.md](operations/post_release_support.md), [operations/postmortems.md](operations/postmortems.md).
- **Фронтенд и API** — требования к разделу «История», i18n и будущим публичным интерфейсам. См. [frontend/overview.md](frontend/overview.md)
  и [frontend/a11y.md](frontend/a11y.md).
- **Тестирование** — обязательные тесты, Move Prover и контроль качества. См. [qa/testing_matrix.md](qa/testing_matrix.md).
- **Справочные материалы** — словарь ошибок, глоссарий, схемы данных. См. [reference/errors.md](reference/errors.md).

Все файлы должны сохраняться в кодировке UTF-8 без BOM.

## Обновление руководства
1. При изменении контрактов — синхронизируйте разделы «Контракты», «Архитектура» и «QA».
2. При добавлении ролей или capability — обновите `governance/roles.md` и `operations/runbooks.md`.
3. Перед релизом — проверьте версию в [architecture/rfc_status.md](architecture/rfc_status.md) и зафиксируйте номер git-тега в changelog проекта.

Главный README и комментарии в коде должны ссылаться на соответствующие разделы этой книги.
