/// Временная заглушка `lottery_rewards::vip`.
/// TODO: перенести VIP-подписки и привязать их к capability распределения наград.
module lottery_rewards::vip {
    use std::signer;

    /// Scope для доступа VIP-подписок к `MultiTreasuryCap`.
    pub const SCOPE_VIP: u64 = 23;

    /// Заглушка структуры контроля VIP.
    struct VipControl has key { dummy: bool }

    /// Временная функция инициализации capability казначейства.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
