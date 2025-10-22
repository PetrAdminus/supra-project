/// Минимальная обвязка вокруг capability автопокупок.
///
/// Полноценная логика будет перенесена из монолита на шаге 5, но уже сейчас
/// нужно закрепить handshake с ядром: ресурс `AutopurchaseAccess` хранит
/// capability раундов и казначейства, полученные из `lottery_core`.
module lottery_rewards::autopurchase {
    use lottery_core::rounds;
    use lottery_core::rounds::AutopurchaseRoundCap;
    use lottery_core::treasury_v1;
    use lottery_core::treasury_v1::AutopurchaseTreasuryCap;
    use std::signer;

    /// Scope для доступа автопокупок к ресурсам ядра.
    const SCOPE_AUTOPURCHASE: u64 = 10;

    const E_NOT_AUTHORIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;

    /// Ресурс, который удерживает capability автопокупок.
    struct AutopurchaseAccess has key {
        rounds: AutopurchaseRoundCap,
        treasury: AutopurchaseTreasuryCap,
    }

    /// Лениво запрашивает capability у ядра и сохраняет их под аккаунтом лотереи.
    public fun ensure_caps_initialized(
        admin: &signer,
    ) {
        let addr = signer::address_of(admin);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (exists<AutopurchaseAccess>(@lottery)) {
            return
        };
        let rounds_cap = rounds::borrow_autopurchase_round_cap(admin);
        let treasury_cap = treasury_v1::borrow_autopurchase_treasury_cap(admin);
        move_to(
            admin,
            AutopurchaseAccess { rounds: rounds_cap, treasury: treasury_cap },
        );
    }

    /// Возвращает capability в ядро, освобождая их для повторной выдачи.
    public fun release_caps(
        admin: &signer,
    ) acquires AutopurchaseAccess {
        let addr = signer::address_of(admin);
        if (addr != @lottery) {
            abort E_NOT_AUTHORIZED
        };
        if (!exists<AutopurchaseAccess>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let AutopurchaseAccess { rounds, treasury } = move_from<AutopurchaseAccess>(@lottery);
        rounds::return_autopurchase_round_cap(admin, rounds);
        treasury_v1::return_autopurchase_treasury_cap(admin, treasury);
    }

    // Проверка для smoke-тестов: capability уже заняты автопокупками.
    #[view]
    public fun caps_ready(): bool {
        exists<AutopurchaseAccess>(@lottery)
    }

}
