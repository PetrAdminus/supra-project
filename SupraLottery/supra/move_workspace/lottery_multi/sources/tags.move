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

    const KNOWN_TAG_BITS: u64 = TAG_NFT
        | TAG_DAILY
        | TAG_WEEKLY
        | TAG_SPLIT_PRIZE
        | TAG_PROMO
        | TAG_EXPERIMENTAL;

    public fun validate(primary_type: u8, tags_mask: u64) {
        assert!(
            primary_type == TYPE_BASIC ||
                primary_type == TYPE_PARTNER ||
                primary_type == TYPE_JACKPOT ||
                primary_type == TYPE_VIP,
            errors::E_TAG_PRIMARY_TYPE,
        );
        // Ensure the mask does not contain unknown (reserved) bits.
        let unknown_bits = tags_mask & !KNOWN_TAG_BITS;
        assert!(unknown_bits == 0, errors::E_TAG_UNKNOWN_BIT);
    }

    public fun count_active_tags(tags_mask: u64): u8 {
        let mut count = 0u8;
        let mut mask = tags_mask;
        while (mask > 0) {
            if ((mask & 1) == 1) {
                count = count + 1;
            };
            mask = mask >> 1;
        };
        count
    }

    public fun assert_tag_budget(tags_mask: u64) {
        let active = count_active_tags(tags_mask);
        assert!(active <= MAX_ACTIVE_TAGS, errors::E_TAG_BUDGET_EXCEEDED);
    }
}

