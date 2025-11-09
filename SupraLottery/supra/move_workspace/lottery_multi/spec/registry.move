spec module lottery_multi::registry {
    use lottery_multi::registry::Lottery;
    use lottery_multi::types;

    spec struct Lottery {
        invariant status == types::STATUS_DRAFT
            || status == types::STATUS_ACTIVE
            || status == types::STATUS_CLOSING
            || status == types::STATUS_DRAW_REQUESTED
            || status == types::STATUS_DRAWN
            || status == types::STATUS_PAYOUT
            || status == types::STATUS_FINALIZED
            || status == types::STATUS_CANCELED;
        invariant snapshot_frozen ==> status >= types::STATUS_CLOSING;
        invariant len(slots_checksum) == 32;
    }
}
