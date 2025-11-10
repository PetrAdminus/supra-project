spec module lottery_multi::price_feed {
    use std::table;

    spec struct PriceFeedRecord {
        invariant decimals <= 18;
        invariant staleness_window > 0;
        invariant clamp_threshold_bps > 0;
    }

    spec fun registry(): PriceFeedRegistry = global<PriceFeedRegistry>(@lottery_multi);

    spec fun feed(asset_id: u64): PriceFeedRecord = table::borrow(&registry().feeds, asset_id);

    spec schema FeedAvailable {
        asset_id: u64;
        condition exists<PriceFeedRegistry>(@lottery_multi);
        condition table::contains(&registry().feeds, asset_id);
    }

    spec register_feed {
        aborts_if !exists<PriceFeedRegistry>(@lottery_multi);
        aborts_if table::contains(&registry().feeds, asset_id);
    }

    spec update_price with FeedAvailable {
        ensures feed(asset_id).fallback_active == false;
        ensures feed(asset_id).fallback_reason == 0;
        ensures !feed(asset_id).clamp_active ==> feed(asset_id).price == price;
        ensures !feed(asset_id).clamp_active ==> feed(asset_id).last_updated_ts == updated_ts;
        ensures feed(asset_id).clamp_active ==> feed(asset_id).price == old(feed(asset_id)).price;
        ensures feed(asset_id).clamp_active ==> feed(asset_id).last_updated_ts == old(feed(asset_id)).last_updated_ts;
    }

    spec set_fallback with FeedAvailable {
        ensures feed(asset_id).fallback_active == active;
        ensures feed(asset_id).fallback_reason == reason;
        ensures !active ==> feed(asset_id).clamp_active == false;
    }

    spec clear_clamp with FeedAvailable {
        aborts_if !old(feed(asset_id)).clamp_active;
        ensures feed(asset_id).clamp_active == false;
        ensures feed(asset_id).last_updated_ts == cleared_ts;
    }

    spec latest_price with FeedAvailable {
        aborts_if feed(asset_id).fallback_active;
        aborts_if feed(asset_id).clamp_active;
    }
}
