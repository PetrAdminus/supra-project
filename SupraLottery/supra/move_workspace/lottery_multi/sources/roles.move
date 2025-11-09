// sources/roles.move
module lottery_multi::roles {
    use std::option;
    use std::vector;

    use lottery_multi::errors;

    pub struct PartnerCreateCap has store {
        pub allowed_event_slug: vector<u8>,
        pub allowed_series_codes: vector<vector<u8>>,
        pub allowed_primary_types: vector<u8>,
        pub allowed_tags_mask: u64,
        pub max_parallel: u64,
        pub expires_at: u64,
        pub payout_cooldown_secs: u64,
    }

    pub struct PremiumAccessCap has store {
        pub holder: address,
        pub expires_at: u64,
        pub auto_renew: bool,
        pub referrer: option::Option<address>,
    }

    public fun new_partner_cap(
        allowed_event_slug: vector<u8>,
        allowed_series_codes: vector<vector<u8>>,
        allowed_primary_types: vector<u8>,
        allowed_tags_mask: u64,
        max_parallel: u64,
        expires_at: u64,
        payout_cooldown_secs: u64,
    ): PartnerCreateCap {
        PartnerCreateCap {
            allowed_event_slug,
            allowed_series_codes,
            allowed_primary_types,
            allowed_tags_mask,
            max_parallel,
            expires_at,
            payout_cooldown_secs,
        }
    }

    public fun ensure_primary_type_allowed(cap: &PartnerCreateCap, primary_type: u8) {
        let allowed = contains_u8(&cap.allowed_primary_types, primary_type);
        assert!(allowed, errors::E_PRIMARY_TYPE_NOT_ALLOWED);
    }

    public fun ensure_tags_allowed(cap: &PartnerCreateCap, tags_mask: u64) {
        let masked = tags_mask & cap.allowed_tags_mask;
        assert!(masked == tags_mask, errors::E_TAG_MASK_NOT_ALLOWED);
    }

    public fun new_premium_cap(
        holder: address,
        expires_at: u64,
        auto_renew: bool,
        referrer: option::Option<address>,
    ): PremiumAccessCap {
        PremiumAccessCap {
            holder,
            expires_at,
            auto_renew,
            referrer,
        }
    }

    public fun is_premium_active(cap: &PremiumAccessCap, now_sec: u64): bool {
        cap.expires_at >= now_sec
    }

    fun contains_u8(items: &vector<u8>, value: u8): bool {
        let len = vector::length(items);
        let mut i = 0;
        while (i < len) {
            let current = *vector::borrow(items, i);
            if (current == value) {
                return true;
            };
            i = i + 1;
        };
        false
    }
}

