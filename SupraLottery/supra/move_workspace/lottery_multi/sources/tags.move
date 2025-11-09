// sources/tags.move
module lottery_multi::tags {

    const E_INVALID_PRIMARY_TYPE: u64 = 0x1001;
    const MAX_ACTIVE_TAGS: u8 = 16;

    pub const TYPE_BASIC: u8 = 0;
    pub const TYPE_PARTNER: u8 = 1;
    pub const TYPE_JACKPOT: u8 = 2;
    pub const TYPE_VIP: u8 = 3;

    pub const TAG_NFT: u64 = 1u64 << 0;
    pub const TAG_DAILY: u64 = 1u64 << 1;
    pub const TAG_WEEKLY: u64 = 1u64 << 2;
    pub const TAG_SPLIT_PRIZE: u64 = 1u64 << 3;
    pub const TAG_PROMO: u64 = 1u64 << 4;
    pub const TAG_EXPERIMENTAL: u64 = 0x8000000000000000;

    public fun validate(primary_type: u8, tags_mask: u64) {
        assert!(
            primary_type == TYPE_BASIC ||
                primary_type == TYPE_PARTNER ||
                primary_type == TYPE_JACKPOT ||
                primary_type == TYPE_VIP,
            E_INVALID_PRIMARY_TYPE,
        );
        let _ = tags_mask;
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
        assert!(active <= MAX_ACTIVE_TAGS, 0x1002);
    }
}

