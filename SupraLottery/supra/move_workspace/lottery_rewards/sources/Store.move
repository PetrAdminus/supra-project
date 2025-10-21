/// Временная заглушка `lottery_rewards::store`.
/// TODO: перенести магазин наград и ограничить операции `MultiTreasuryCap`.
module lottery_rewards::store {
    use std::signer;

    /// Scope для доступа магазина к `MultiTreasuryCap`.
    pub const SCOPE_STORE: u64 = 22;

    /// Заглушка структуры контроля магазина.
    struct StoreControl has key { dummy: bool }

    /// Временная функция инициализации capability казначейства.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
