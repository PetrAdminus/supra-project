/// Временная заглушка `lottery_rewards::autopurchase`.
/// TODO: перенести функционал автопокупок и запрос capability у `lottery_core::rounds` и `treasury_v1`.
module lottery_rewards::autopurchase {
    use std::signer;

    /// Scope для доступа автопокупок к ресурсам ядра.
    pub const SCOPE_AUTOPURCHASE: u64 = 10;

    /// Заглушка структуры контроля доступа к capability раундов и казначейства.
    struct AutopurchaseAccess has key { dummy: bool }

    /// Временная функция для ленивой инициализации capability.
    public fun ensure_caps_initialized(admin: &signer) {
        let _ = signer::address_of(admin);
    }
}
