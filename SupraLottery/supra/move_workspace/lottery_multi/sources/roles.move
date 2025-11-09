// sources/roles.move
module lottery_multi::roles {
    use std::vector;

    const E_PRIMARY_TYPE_NOT_ALLOWED: u64 = 0x1101;
    const E_TAG_MASK_NOT_ALLOWED: u64 = 0x1102;

    pub struct PartnerCreateCap has store {
        pub allowed_event_slug: vector<u8>,
        pub allowed_series_codes: vector<vector<u8>>,
        pub allowed_primary_types: vector<u8>,
        pub allowed_tags_mask: u64,
        pub max_parallel: u64,
        pub expires_at: u64,
    }

    public fun new_partner_cap(
        allowed_event_slug: vector<u8>,
        allowed_series_codes: vector<vector<u8>>,
        allowed_primary_types: vector<u8>,
        allowed_tags_mask: u64,
        max_parallel: u64,
        expires_at: u64,
    ): PartnerCreateCap {
        PartnerCreateCap {
            allowed_event_slug,
            allowed_series_codes,
            allowed_primary_types,
            allowed_tags_mask,
            max_parallel,
            expires_at,
        }
    }

    public fun ensure_primary_type_allowed(cap: &PartnerCreateCap, primary_type: u8) {
        let allowed = contains_u8(&cap.allowed_primary_types, primary_type);
        assert!(allowed, E_PRIMARY_TYPE_NOT_ALLOWED);
    }

    public fun ensure_tags_allowed(cap: &PartnerCreateCap, tags_mask: u64) {
        let masked = tags_mask & cap.allowed_tags_mask;
        assert!(masked == tags_mask, E_TAG_MASK_NOT_ALLOWED);
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

