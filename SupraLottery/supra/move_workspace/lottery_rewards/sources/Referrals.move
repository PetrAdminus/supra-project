/// Заглушка `lottery_rewards::referrals`, удерживающая capability казначейства.
module lottery_rewards::referrals {
    use lottery_core::treasury_multi;
    use lottery_core::treasury_multi::MultiTreasuryCap;
    use std::signer;

    const E_NOT_AUTHORIZED: u64 = 1;
    const E_NOT_INITIALIZED: u64 = 2;

    struct ReferralsAccess has key { cap: MultiTreasuryCap }

    public fun ensure_caps_initialized(admin: &signer) {
        ensure_admin(admin);
        if (exists<ReferralsAccess>(@lottery)) {
            return
        };
        let cap = treasury_multi::borrow_multi_treasury_cap(
            admin,
            treasury_multi::scope_referrals(),
        );
        move_to(admin, ReferralsAccess { cap });
    }

    public fun release_caps(admin: &signer) acquires ReferralsAccess {
        ensure_admin(admin);
        if (!exists<ReferralsAccess>(@lottery)) {
            abort E_NOT_INITIALIZED
        };
        let ReferralsAccess { cap } = move_from<ReferralsAccess>(@lottery);
        treasury_multi::return_multi_treasury_cap(admin, cap);
    }

    #[view]
    public fun caps_ready(): bool {
        exists<ReferralsAccess>(@lottery)
    }

    #[view]
    public fun scope_id(): u64 {
        treasury_multi::scope_referrals()
    }

    fun ensure_admin(admin: &signer) {
        if (signer::address_of(admin) != @lottery) {
            abort E_NOT_AUTHORIZED
        };
    }
}
