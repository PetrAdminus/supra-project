spec module lottery_multi::lottery_registry {
    use lottery_multi::lottery_lottery_registry::Lottery;
    use lottery_multi::types;

    spec struct Lottery {
        invariant status == types::status_draft()
            || status == types::status_active()
            || status == types::status_closing()
            || status == types::status_draw_requested()
            || status == types::status_drawn()
            || status == types::status_payout()
            || status == types::status_finalized()
            || status == types::status_canceled();
        invariant snapshot_frozen ==> status >= types::status_closing();
        invariant len(slots_checksum) == 32;
    }
}
