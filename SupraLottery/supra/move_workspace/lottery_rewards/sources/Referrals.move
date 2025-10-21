/// Временная заглушка `lottery_rewards::referrals`.
/// TODO: перенести реферальную программу и использовать `MultiTreasuryCap` с нужным scope.
module lottery_rewards::referrals {
    use std::signer;

    /// Scope для доступа реферальной программы к `MultiTreasuryCap`.
    pub const SCOPE_REFERRALS: u64 = 21;

    /// Заглушка структуры контроля рефералов.
    struct ReferralsControl has key { dummy: bool }

    /// Временная функция инициализации capability казначейства.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
