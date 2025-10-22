/// Заглушка `lottery_rewards::jackpot`, обеспечивающая handshake с ядром.
///
/// Полноценная логика появления джекпота переедет из монолита на следующем
/// шаге, но уже сейчас модуль бронирует capability казначейства и возвращает
/// её через `release_caps`, чтобы smoke-тесты могли проверять готовность API.
module lottery_rewards::jackpot {
    use lottery_core::treasury_multi;
    use lottery_core::treasury_multi::MultiTreasuryCap;
    use std::signer;

    const E_NOT_AUTHORIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;

    struct JackpotAccess has key { cap: MultiTreasuryCap }

    public fun ensure_caps_initialized(admin: &signer) {
        ensure_admin(admin);
        if (exists<JackpotAccess>(@lottery)) {
            return
        };
        let cap = treasury_multi::borrow_multi_treasury_cap(
            admin,
            treasury_multi::scope_jackpot(),
        );
        move_to(admin, JackpotAccess { cap });
    }

    public fun release_caps(admin: &signer) acquires JackpotAccess {
        ensure_admin(admin);
        if (!exists<JackpotAccess>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let JackpotAccess { cap } = move_from<JackpotAccess>(@lottery);
        treasury_multi::return_multi_treasury_cap(admin, cap);
    }

    #[view]
    public fun caps_ready(): bool {
        exists<JackpotAccess>(@lottery)
    }

    #[view]
    public fun scope_id(): u64 {
        treasury_multi::scope_jackpot()
    }

    fun ensure_admin(admin: &signer) {
        if (signer::address_of(admin) != @lottery) {
            abort E_NOT_AUTHORIZED
        };
    }
}
