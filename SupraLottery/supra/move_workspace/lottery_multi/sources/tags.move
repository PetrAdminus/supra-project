// sources/tags.move
module lottery_multi::tags {

    use lottery_multi::errors;

    const MAX_ACTIVE_TAGS: u8 = 16;

    const TYPE_BASIC: u8 = 0;
    const TYPE_PARTNER: u8 = 1;
    const TYPE_JACKPOT: u8 = 2;
    const TYPE_VIP: u8 = 3;

    const TAG_NFT: u64 = 1u64 << 0;
    const TAG_DAILY: u64 = 1u64 << 1;
    const TAG_WEEKLY: u64 = 1u64 << 2;
    const TAG_SPLIT_PRIZE: u64 = 1u64 << 3;
    const TAG_PROMO: u64 = 1u64 << 4;
    const TAG_EXPERIMENTAL: u64 = 0x8000000000000000;

    const KNOWN_TAG_BITS: u64 = (1u64 << 0)
        | (1u64 << 1)
        | (1u64 << 2)
        | (1u64 << 3)
        | (1u64 << 4)
        | 0x8000000000000000;

    public fun validate(primary_type: u8, tags_mask: u64) {
        assert!(
            primary_type == TYPE_BASIC ||
                primary_type == TYPE_PARTNER ||
                primary_type == TYPE_JACKPOT ||
                primary_type == TYPE_VIP,
            errors::err_tag_primary_type(),
        );
        assert!(
            (tags_mask & KNOWN_TAG_BITS) == tags_mask,
            errors::err_tag_unknown_bit(),
        );
    }

    public fun count_active_tags(tags_mask: u64): u8 {
        count_bits_recursive(tags_mask, 0)
    }

    public fun assert_tag_budget(tags_mask: u64) {
        let active = count_active_tags(tags_mask);
        assert!(active <= MAX_ACTIVE_TAGS, errors::err_tag_budget_exceeded());
    }
    fun count_bits_recursive(mask: u64, acc: u8): u8 {
        if (mask == 0) {
            return acc
        };
        let increment = if ((mask & 1) == 1) { 1u8 } else { 0u8 };
        count_bits_recursive(mask >> 1, acc + increment)
    }

    //
    // Constant helpers (Move v1 compatibility)
    //

    public fun type_basic(): u8 {
        TYPE_BASIC
    }

    public fun type_partner(): u8 {
        TYPE_PARTNER
    }

    public fun type_jackpot(): u8 {
        TYPE_JACKPOT
    }

    public fun type_vip(): u8 {
        TYPE_VIP
    }

    public fun tag_nft(): u64 {
        TAG_NFT
    }

    public fun tag_daily(): u64 {
        TAG_DAILY
    }

    public fun tag_weekly(): u64 {
        TAG_WEEKLY
    }

    public fun tag_split_prize(): u64 {
        TAG_SPLIT_PRIZE
    }

    public fun tag_promo(): u64 {
        TAG_PROMO
    }

    public fun tag_experimental(): u64 {
        TAG_EXPERIMENTAL
    }
}

