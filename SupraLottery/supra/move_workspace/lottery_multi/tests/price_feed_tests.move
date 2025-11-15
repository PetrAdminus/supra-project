module lottery_multi::price_feed_tests {
    use std::option;

    use lottery_multi::errors;
    use lottery_multi::price_feed;

    // #[test(account = @lottery_multi)]
    fun register_and_read(account: &signer) {

        price_feed::init_price_feed(account, 1);
        price_feed::register_feed(
            account,
            feed_id(),
            10_000_000,
            8,
            option::none(),
            option::none(),
            1_000,
        );
        let (price, decimals) = price_feed::latest_price(feed_id(), 1_100);
        assert!(price == 10_000_000, 0);
        assert!(decimals == 8, 0);
    }

    // #[test(account = @lottery_multi)]
    // // #[expected_failure(abort_code = errors::E_PRICE_STALE)]
    fun stale_feed_rejected(account: &signer) {

        price_feed::init_price_feed(account, 1);
        price_feed::register_feed(
            account,
            feed_id(),
            15_000_000,
            8,
            option::some(60),
            option::none(),
            1_000,
        );
        let (_, _) = price_feed::latest_price(feed_id(), 1_200);
    }

    // #[test(account = @lottery_multi)]
    // // #[expected_failure(abort_code = errors::E_PRICE_FALLBACK_ACTIVE)]
    fun fallback_blocks_consumers(account: &signer) {

        price_feed::init_price_feed(account, 1);
        price_feed::register_feed(
            account,
            feed_id(),
            21_000_000,
            8,
            option::none(),
            option::none(),
            1_000,
        );
        price_feed::set_fallback(account, feed_id(), true, 1);
        let (_, _) = price_feed::latest_price(feed_id(), 1_100);
    }

    // #[test(account = @lottery_multi)]
    fun clamp_marks_feed_unavailable(account: &signer) {

        price_feed::init_price_feed(account, 1);
        price_feed::register_feed(
            account,
            feed_id(),
            40_000_000,
            8,
            option::none(),
            option::some(50),
            1_000,
        );
        price_feed::update_price(account, feed_id(), 45_000_000, 1_050);
        let view = price_feed::get_price_view(feed_id());
        assert!(price_feed::price_view_clamp_active(&view), 0);
        assert!(price_feed::price_view_price(&view) == 40_000_000, 0);
        assert!(price_feed::price_view_last_updated(&view) == 1_000, 0);
    }

    // #[test(account = @lottery_multi)]
    // // #[expected_failure(abort_code = errors::E_PRICE_CLAMP_ACTIVE)]
    fun clamp_blocks_latest_price(account: &signer) {

        price_feed::init_price_feed(account, 1);
        price_feed::register_feed(
            account,
            feed_id(),
            50_000_000,
            8,
            option::none(),
            option::some(50),
            1_000,
        );
        price_feed::update_price(account, feed_id(), 60_000_000, 1_050);
        let (_, _) = price_feed::latest_price(feed_id(), 1_060);
    }

    // #[test(account = @lottery_multi)]
    fun clear_clamp_allows_recovery(account: &signer) {

        price_feed::init_price_feed(account, 1);
        price_feed::register_feed(
            account,
            feed_id(),
            55_000_000,
            8,
            option::none(),
            option::some(50),
            1_000,
        );
        price_feed::update_price(account, feed_id(), 65_000_000, 1_050);
        price_feed::clear_clamp(account, feed_id(), 1_200);
        // After manual clearance, admin can publish new price within limits
        price_feed::update_price(account, feed_id(), 55_100_000, 1_210);
        let (price, _) = price_feed::latest_price(feed_id(), 1_220);
        assert!(price == 55_100_000, 0);
    }

    fun feed_id(): u64 {
        price_feed::asset_supra_usd_id()
    }
}








