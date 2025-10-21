/// Временная заглушка `lottery_rewards::jackpot`.
/// TODO: перенести механику джекпота и ограничить доступ `MultiTreasuryCap`.
module lottery_rewards::jackpot {
    use std::signer;

    /// Scope для доступа джекпота к `MultiTreasuryCap`.
    pub const SCOPE_JACKPOT: u64 = 20;

    /// Заглушка структуры контроля джекпота.
    struct JackpotControl has key { dummy: bool }

    /// Временная функция инициализации capability казначейства.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
