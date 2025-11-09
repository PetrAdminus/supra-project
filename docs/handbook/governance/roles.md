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

## Порядок проверок в entry-функциях
1. `emergency_stop`.
2. Проверка роли/capability.
3. Проверка `FeatureSwitch` и `force_enable_devnet` (в devnet).
4. Проверка пауз (`per-lottery`, `per-role`).
5. Проверка бюджетов и квот.
6. Проверка состояния (`state_guard`).

Все выдачи/отзывы capability фиксируются событиями `RoleGranted`/`RoleRevoked`. История доступна во view и фронтенде.
