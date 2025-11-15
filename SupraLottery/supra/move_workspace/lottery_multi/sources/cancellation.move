// sources/cancellation.move
module lottery_multi::cancellation {
    use lottery_multi::lottery_registry;
    use lottery_multi::sales;

    public entry fun cancel_lottery_admin(
        admin: &signer,
        id: u64,
        reason_code: u8,
        now_ts: u64,
    ) {
        let (tickets_sold, proceeds_accum) = if (sales::has_state(id)) {
            let (sold, proceeds, _last_ts) = sales::sales_totals(id);
            sales::begin_refund(id);
            (sold, proceeds)
        } else {
            (0u64, 0u64)
        };
        lottery_registry::apply_cancellation(
            admin,
            id,
            reason_code,
            now_ts,
            tickets_sold,
            proceeds_accum,
        );
    }
}
