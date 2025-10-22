/// Заглушка `lottery_rewards::store`, которая только удерживает capability ядра.
module lottery_rewards::store {
    use lottery_core::treasury_multi;
    use lottery_core::treasury_multi::MultiTreasuryCap;
    use std::signer;

    const E_NOT_AUTHORIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;

    struct StoreAccess has key { cap: MultiTreasuryCap }

    public fun ensure_caps_initialized(admin: &signer) {
        ensure_admin(admin);
        if (exists<StoreAccess>(@lottery)) {
            return
        };
        let cap = treasury_multi::borrow_multi_treasury_cap(
            admin,
            treasury_multi::scope_store(),
        );
        move_to(admin, StoreAccess { cap });
    }

    public fun release_caps(admin: &signer) acquires StoreAccess {
        ensure_admin(admin);
        if (!exists<StoreAccess>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let StoreAccess { cap } = move_from<StoreAccess>(@lottery);
        treasury_multi::return_multi_treasury_cap(admin, cap);
    }

    #[view]
    public fun caps_ready(): bool {
        exists<StoreAccess>(@lottery)
    }

    #[view]
    public fun scope_id(): u64 {
        treasury_multi::scope_store()
    }

    fun ensure_admin(admin: &signer) {
        if (signer::address_of(admin) != @lottery) {
            abort E_NOT_AUTHORIZED
        };
    }
}
