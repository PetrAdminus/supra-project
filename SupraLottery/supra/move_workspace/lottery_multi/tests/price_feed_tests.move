module lottery_multi::price_feed_tests {
    use std::option;
    use std::signer;

    use lottery_multi::errors;
    use lottery_multi::price_feed;

    const FEED_ID: u64 = price_feed::ASSET_SUPRA_USD;

    #[test(account = @lottery_multi)]
    fun register_and_read(account: &signer) {
        price_feed::init_price_feed(account, 1);
        price_feed::register_feed(
            account,
            FEED_ID,
            10_000_000,
            8,
            option::none(),
            option::none(),
            1_000,
        );
        let (price, decimals) = price_feed::latest_price(FEED_ID, 1_100);
        assert!(price == 10_000_000, 0);
        assert!(decimals == 8, 0);
    }

    #[test(account = @lottery_multi)]
    #[expected_failure(abort_code = errors::E_PRICE_STALE)]
    fun stale_feed_rejected(account: &signer) {
        price_feed::init_price_feed(account, 1);
        price_feed::register_feed(
            account,
            FEED_ID,
            15_000_000,
            8,
            option::some(60),
            option::none(),
            1_000,
        );
        let _ = price_feed::latest_price(FEED_ID, 1_200);
    }

    #[test(account = @lottery_multi)]
    #[expected_failure(abort_code = errors::E_PRICE_FALLBACK_ACTIVE)]
    fun fallback_blocks_consumers(account: &signer) {
        price_feed::init_price_feed(account, 1);
        price_feed::register_feed(
            account,
            FEED_ID,
            21_000_000,
            8,
            option::none(),
            option::none(),
            1_000,
        );
        price_feed::set_fallback(account, FEED_ID, true, 1);
        let _ = price_feed::latest_price(FEED_ID, 1_100);
    }

    #[test(account = @lottery_multi)]
    fun clamp_marks_feed_unavailable(account: &signer) {
        price_feed::init_price_feed(account, 1);
        price_feed::register_feed(
            account,
            FEED_ID,
            40_000_000,
            8,
            option::none(),
            option::some(50),
            1_000,
        );
        price_feed::update_price(account, FEED_ID, 45_000_000, 1_050);
        let view = price_feed::get_price_view(FEED_ID);
        assert!(view.clamp_active, 0);
        assert!(view.price == 40_000_000, 0);
        assert!(view.last_updated_ts == 1_000, 0);
    }

    #[test(account = @lottery_multi)]
    #[expected_failure(abort_code = errors::E_PRICE_CLAMP_ACTIVE)]
    fun clamp_blocks_latest_price(account: &signer) {
        price_feed::init_price_feed(account, 1);
        price_feed::register_feed(
            account,
            FEED_ID,
            50_000_000,
            8,
            option::none(),
            option::some(50),
            1_000,
        );
        price_feed::update_price(account, FEED_ID, 60_000_000, 1_050);
        let _ = price_feed::latest_price(FEED_ID, 1_060);
    }

    #[test(account = @lottery_multi)]
    fun clear_clamp_allows_recovery(account: &signer) {
        price_feed::init_price_feed(account, 1);
        price_feed::register_feed(
            account,
            FEED_ID,
            55_000_000,
            8,
            option::none(),
            option::some(50),
            1_000,
        );
        price_feed::update_price(account, FEED_ID, 65_000_000, 1_050);
        price_feed::clear_clamp(account, FEED_ID, 1_200);
        // After manual clearance, admin can publish new price within limits
        price_feed::update_price(account, FEED_ID, 55_100_000, 1_210);
        let (price, _) = price_feed::latest_price(FEED_ID, 1_220);
        assert!(price == 55_100_000, 0);
    }
}
