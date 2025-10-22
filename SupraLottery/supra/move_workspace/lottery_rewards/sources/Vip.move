/// Заглушка `lottery_rewards::vip`, удерживающая capability `MultiTreasuryCap`.
module lottery_rewards::vip {
    use lottery_core::treasury_multi;
    use lottery_core::treasury_multi::MultiTreasuryCap;
    use std::signer;

    const E_NOT_AUTHORIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;

    struct VipAccess has key { cap: MultiTreasuryCap }

    public fun ensure_caps_initialized(admin: &signer) {
        ensure_admin(admin);
        if (exists<VipAccess>(@lottery)) {
            return
        };
        let cap = treasury_multi::borrow_multi_treasury_cap(
            admin,
            treasury_multi::scope_vip(),
        );
        move_to(admin, VipAccess { cap });
    }

    public fun release_caps(admin: &signer) acquires VipAccess {
        ensure_admin(admin);
        if (!exists<VipAccess>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let VipAccess { cap } = move_from<VipAccess>(@lottery);
        treasury_multi::return_multi_treasury_cap(admin, cap);
    }

    #[view]
    public fun caps_ready(): bool {
        exists<VipAccess>(@lottery)
    }

    #[view]
    public fun scope_id(): u64 {
        treasury_multi::scope_vip()
    }

    fun ensure_admin(admin: &signer) {
        if (signer::address_of(admin) != @lottery) {
            abort E_NOT_AUTHORIZED
        };
    }
}
