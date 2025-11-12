# Роли и capability

| Роль | Capability | Основные права | Ограничения |
| --- | --- | --- | --- |
| RootAdmin | `RootAdminCap` | Назначение/отзыв остальных ролей, обновление глобальных настроек | Единственный владелец, операции логируются событиями `AdminAction` |
| OperationalAdmin | `OperationalAdminCap` | Создание/активация лотерей, запуск батчей, управление паузами | Подчиняется глобальным лимитам, таймлок на чувствительные операции |
| TreasuryCustodian | `TreasuryCustodianCap` | Пополнение депозитов VRF, управление казначейскими пулами | Не может изменять конфигурации лотерей |
| PartnerOperator | `PartnerCreateCap` | Создание лотерей из разрешённых шаблонов, использование PartnerVault/NftEscrow | Ограничен `allowed_primary_types`, `allowed_tags_mask`, лимитами бюджета и cooldown выплат |
| PremiumUser | `PremiumAccessCap` | Доступ к премиальным функциям (автопокупка, повышенные лимиты) | `auto_renew`, `referrer` управляются административно |
| AutomationBot | `AutomationBotCap` | Запуск dry-run/execute процедур, мониторинг VRF | Требует корректного `reputation_score`, таймлок на unpause/payout |
| AuditObserver | `AuditViewCap` | Чтение агрегированных данных и архивов | Ограничения чтения фиксируются в политиках индексатора |
| SupportAgent | `SupportCap` | Работа с тикетами и принудительными рефандами | Только при активной паузе и после подтверждения RootAdmin |

## Матрица выдачи и ревокации capability

| Capability | Кому выдаётся | Кто инициирует | Внечейн-подтверждение | Таймлок до активации | Процедура отзыва | Наблюдаемость |
| --- | --- | --- | --- | --- | --- | --- |
| `RootAdminCap` | Мультисиг-кошелёк совета директоров | Совет директоров (2/3 подписи) | Протокол заседания и запись в [incident_log.md](../operations/incident_log.md) | 24 ч между решением и публикацией транзакции | Любой член совета через тот же мультисиг | События `AdminAction`, запись в статусной странице |
| `OperationalAdminCap` | Операционный мультисиг | RootAdmin после 2 подтверждений от дежурных | Чек-лист запуска + задача в ticketing | 6 ч (регламент дежурных) | RootAdmin, требует отчёта об инциденте | `RoleStore::payout_granted/revoked`, дашборд «Operational Admins» |
| `PayoutBatchCap` | Команда казначейства | RootAdmin + TreasuryCustodian | Отдельный лимит и SLA в казначейском регистре | 4 ч + проверка `operations_budget_total` | RootAdmin немедленно, TreasuryCustodian может запросить паузу через инцидент | События `PayoutBatchCapGranted/Revoked`, view `roles::has_payout_batch_cap` |
| `PartnerPayoutCap` | Партнёрский кошелёк | RootAdmin по заявке бизнеса | KYC/AML чек-лист, акт об ограничении бюджета | 24 ч (фрод-мониторинг) | RootAdmin или истечение `expires_at`; отзыв фиксируется в журнале партнёров | События `PartnerPayoutCapGranted/Revoked`, view `list_partner_caps` |
| `PartnerCreateCap` | Партнёрская студия | RootAdmin после согласования с бизнесом | Подписанное приложение партнёра + whitelist тегов | 48 ч (мягкий запуск) | RootAdmin, уведомление через support и изменение тегов в `legacy_bridge::update_legacy_classification_admin` | События `LotteryCreated` с `allowed_*`, playbook этапа 3 |
| `PremiumAccessCap` | Пользователь (премиум) | OperationalAdmin или автоматический скрипт | KYC проверка и статус подписки | Нет (активация мгновенная) | Автоотзыв по `expires_at` или вручную админом | События `PremiumAccessGranted/Revoked`, view `list_premium_caps` |
| `AutomationBotCap` | Бот с выделенным ключом | RootAdmin + DevOps (два подтверждения) | DR-план + dry-run checklist | 12 ч между `announce_dry_run` и первой задачей | RootAdmin или превышение `max_failures` (авто) | События `AutomationKeyRotated`, мониторинг `automation_*` |
| `AuditViewCap` | Внутренний аудит/партнёр | RootAdmin | NDA + регистрация в списке аудиторов | 24 ч (уведомление безопасности) | RootAdmin, запись в журнал аудита | View `roles::list_audit_caps`, журнал подписей |
| `SupportCap` | Поддержка | OperationalAdmin по заявке support lead | SLA и обучение по рефандам | 2 ч (handover смены) | OperationalAdmin или RootAdmin при эскалации | События `SupportCapGranted/Revoked`, runbook рефандов |

**Примечания**

- Для всех capability с таймлоком применяется правило «двух глаз»: один оператор готовит транзакцию, второй подтверждает в ticketing и подписывает dry-run.
- Если отзыв инициирован из-за инцидента, требуется заполнить шаблон из [postmortems.md](../operations/postmortems.md) в течение 24 часов.
- Runbook AutomationBot и чек-лист релиза содержат контроль, что активные capability не истекают в ближайшие 72 часа.

## Порядок проверок в entry-функциях
1. `emergency_stop`.
2. Проверка роли/capability.
3. Проверка `FeatureSwitch` и `force_enable_devnet` (в devnet).
4. Проверка пауз (`per-lottery`, `per-role`).
5. Проверка бюджетов и квот.
6. Проверка состояния (`state_guard`).

Все выдачи/отзывы capability фиксируются событиями `RoleGranted`/`RoleRevoked`. История доступна во view и фронтенде.

Дополнительные юридические ограничения и список запрещённых юрисдикций приведены в [compliance.md](compliance.md); перед выдачей партнёрских capability требуется подтвердить выполнение требований KYC/AML.
