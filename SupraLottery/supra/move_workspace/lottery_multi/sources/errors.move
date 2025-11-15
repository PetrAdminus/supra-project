// sources/errors.move
module lottery_multi::errors {
    /// Common tag errors
    const E_TAG_PRIMARY_TYPE: u64 = 0x1001;
    const E_TAG_UNKNOWN_BIT: u64 = 0x1002;
    const E_TAG_BUDGET_EXCEEDED: u64 = 0x1003;

    /// Partner capability errors
    const E_PRIMARY_TYPE_NOT_ALLOWED: u64 = 0x1101;
    const E_TAG_MASK_NOT_ALLOWED: u64 = 0x1102;
    const E_ROLES_NOT_INITIALIZED: u64 = 0x1103;
    const E_PAYOUT_BATCH_CAP_MISSING: u64 = 0x1104;
    const E_PARTNER_PAYOUT_CAP_MISSING: u64 = 0x1105;
    const E_PREMIUM_CAP_MISSING: u64 = 0x1106;
    const E_PREMIUM_CAP_EXPIRED: u64 = 0x1107;

    /// Registry and configuration errors
    const E_ALREADY_INITIALIZED: u64 = 0x1201;
    const E_REGISTRY_MISSING: u64 = 0x1202;
    const E_LOTTERY_EXISTS: u64 = 0x1203;
    const E_STATUS_TRANSITION_NOT_ALLOWED: u64 = 0x1204;
    const E_PRIMARY_TYPE_LOCKED: u64 = 0x1205;
    const E_TAGS_LOCKED: u64 = 0x1206;
    const E_SNAPSHOT_FROZEN: u64 = 0x1207;
    const E_SALES_WINDOW_INVALID: u64 = 0x1208;
    const E_TICKET_PRICE_ZERO: u64 = 0x1209;
    const E_TICKET_LIMIT_INVALID: u64 = 0x120A;
    const E_PRIZE_PLAN_EMPTY: u64 = 0x120B;
    const E_PRIZE_SLOT_INVALID: u64 = 0x120C;
    const E_DRAW_ALGO_UNSUPPORTED: u64 = 0x120D;
    const E_SALES_WINDOW_CLOSED: u64 = 0x120E;
    const E_LOTTERY_NOT_ACTIVE: u64 = 0x120F;
    const E_DRAW_STATUS_INVALID: u64 = 0x1210;
    const E_CANCEL_REASON_INVALID: u64 = 0x1211;
    const E_CANCELLATION_RECORD_MISSING: u64 = 0x1212;

    /// Accounting and allocation errors
    const E_DISTRIBUTION_BPS_INVALID: u64 = 0x1301;
    const E_JACKPOT_ALLOWANCE_UNDERFLOW: u64 = 0x1302;
    const E_JACKPOT_ALLOWANCE_INCREASE: u64 = 0x1303;
    const E_PAYOUT_ALLOC_EXCEEDED: u64 = 0x1304;
    const E_OPERATIONS_ALLOC_EXCEEDED: u64 = 0x1305;

    /// Feature switch errors
    const E_FEATURE_UNKNOWN: u64 = 0x1401;
    const E_FEATURE_MODE_INVALID: u64 = 0x1402;
    const E_FEATURE_DISABLED: u64 = 0x1403;

    /// Validation and view errors
    const E_PAGINATION_LIMIT: u64 = 0x1501;

    /// Serialization errors
    const E_BCS_DECODE: u64 = 0x1A01;

    /// Ticket purchase errors
    const E_PURCHASE_QTY_ZERO: u64 = 0x1601;
    const E_PURCHASE_QTY_LIMIT: u64 = 0x1602;
    const E_PURCHASE_TOTAL_LIMIT: u64 = 0x1603;
    const E_PURCHASE_ADDRESS_LIMIT: u64 = 0x1604;
    const E_AMOUNT_OVERFLOW: u64 = 0x1605;
    const E_PREMIUM_CAP_MISMATCH: u64 = 0x1606;
    const E_PURCHASE_RATE_LIMIT_BLOCK: u64 = 0x1608;
    const E_PURCHASE_RATE_LIMIT_WINDOW: u64 = 0x1609;
    const E_PURCHASE_GRACE_RESTRICTED: u64 = 0x160A;

    /// VRF / draw errors
    const E_VRF_PENDING: u64 = 0x1701;
    const E_VRF_NOT_REQUESTED: u64 = 0x1702;
    const E_VRF_NONCE_UNKNOWN: u64 = 0x1703;
    const E_VRF_PAYLOAD_MISMATCH: u64 = 0x1704;
    const E_VRF_ATTEMPT_OUT_OF_ORDER: u64 = 0x1705;
    const E_VRF_RNG_COUNT_INVALID: u64 = 0x1706;
    const E_VRF_SNAPSHOT_EMPTY: u64 = 0x1707;
    const E_VRF_CONSUMED: u64 = 0x1708;
    const E_VRF_RETRY_WINDOW: u64 = 0x1709;
    const E_VRF_CLIENT_SEED_OVERFLOW: u64 = 0x170A;
    const E_VRF_DEPOSIT_NOT_INITIALIZED: u64 = 0x170B;
    const E_VRF_DEPOSIT_CONFIG: u64 = 0x170C;
    const E_VRF_REQUESTS_PAUSED: u64 = 0x170D;
    const E_VRF_RETRY_POLICY_INVALID: u64 = 0x170E;
    const E_VRF_MANUAL_SCHEDULE_REQUIRED: u64 = 0x170F;
    const E_VRF_MANUAL_DEADLINE: u64 = 0x1710;

    /// Winner computation / payouts
    const E_WINNER_VRF_NOT_READY: u64 = 0x1801;
    const E_WINNER_ALL_ASSIGNED: u64 = 0x1802;
    const E_WINNER_INDEX_OUT_OF_RANGE: u64 = 0x1803;
    const E_WINNER_DEDUP_EXHAUSTED: u64 = 0x1804;
    const E_PAYOUT_STATE_MISSING: u64 = 0x1805;
    const E_PAYOUT_ROUND_NON_MONOTONIC: u64 = 0x1806;
    const E_PAYOUT_COOLDOWN: u64 = 0x1807;
    const E_PAYOUT_BATCH_TOO_LARGE: u64 = 0x1808;
    const E_PAYOUT_BATCH_COOLDOWN: u64 = 0x1809;
    const E_PAYOUT_BATCH_NONCE: u64 = 0x180A;
    const E_PAYOUT_OPERATIONS_BUDGET: u64 = 0x180B;
    const E_PARTNER_PAYOUT_BUDGET_EXCEEDED: u64 = 0x180C;
    const E_PARTNER_PAYOUT_COOLDOWN: u64 = 0x180D;
    const E_PARTNER_PAYOUT_NONCE: u64 = 0x180E;
    const E_PARTNER_PAYOUT_HOLDER_MISMATCH: u64 = 0x180F;
    const E_PARTNER_PAYOUT_EXPIRED: u64 = 0x1810;
    const E_REFUND_NOT_ACTIVE: u64 = 0x1811;
    const E_REFUND_ROUND_NON_MONOTONIC: u64 = 0x1812;
    const E_REFUND_LIMIT_TICKETS: u64 = 0x1813;
    const E_REFUND_LIMIT_FUNDS: u64 = 0x1814;
    const E_REFUND_STATUS_INVALID: u64 = 0x1815;
    const E_REFUND_BATCH_EMPTY: u64 = 0x1816;
    const E_REFUND_TIMESTAMP: u64 = 0x1817;
    const E_REFUND_PROGRESS_INCOMPLETE: u64 = 0x1818;
    const E_REFUND_PROGRESS_FUNDS: u64 = 0x1819;

    /// Price feed errors
    const E_PRICE_FEED_EXISTS: u64 = 0x1901;
    const E_PRICE_FEED_NOT_FOUND: u64 = 0x1902;
    const E_PRICE_DECIMALS_INVALID: u64 = 0x1903;
    const E_PRICE_STALE: u64 = 0x1904;
    const E_PRICE_FALLBACK_ACTIVE: u64 = 0x1905;
    const E_PRICE_CLAMP_TRIGGERED: u64 = 0x1906;
    const E_PRICE_CLAMP_ACTIVE: u64 = 0x1907;
    const E_PRICE_CLAMP_NOT_ACTIVE: u64 = 0x1908;

    /// Automation / automation bot errors
    const E_AUTOBOT_REGISTRY_MISSING: u64 = 0x1A01;
    const E_AUTOBOT_ALREADY_REGISTERED: u64 = 0x1A02;
    const E_AUTOBOT_NOT_REGISTERED: u64 = 0x1A03;
    const E_AUTOBOT_EXPIRED: u64 = 0x1A04;
    const E_AUTOBOT_FORBIDDEN_TARGET: u64 = 0x1A05;
    const E_AUTOBOT_FAILURE_LIMIT: u64 = 0x1A06;
    const E_AUTOBOT_TIMELOCK: u64 = 0x1A07;
    const E_AUTOBOT_PENDING_EXISTS: u64 = 0x1A08;
    const E_AUTOBOT_PENDING_MISMATCH: u64 = 0x1A09;
    const E_AUTOBOT_PENDING_REQUIRED: u64 = 0x1A0A;
    const E_AUTOBOT_ACTION_HASH_EMPTY: u64 = 0x1A0B;
    const E_AUTOBOT_CALLER_MISMATCH: u64 = 0x1A0C;

    /// History import / archive errors
    const E_HISTORY_MISSING: u64 = 0x1B01;
    const E_HISTORY_MISMATCH: u64 = 0x1B02;
    const E_FINALIZATION_INCOMPLETE: u64 = 0x1B03;
    const E_HISTORY_NOT_AUTHORIZED: u64 = 0x1B04;
    const E_HISTORY_EXPECTED_MISSING: u64 = 0x1B05;
    const E_HISTORY_CONTROL_MISSING: u64 = 0x1B06;
    const E_HISTORY_IMPORT_HASH: u64 = 0x1B07;
    const E_HISTORY_ID_MISMATCH: u64 = 0x1B08;
    const E_HISTORY_NOT_LEGACY: u64 = 0x1B09;
    const E_HISTORY_SUMMARY_MISSING: u64 = 0x1B0A;
    const E_HISTORY_DECODE: u64 = 0x1B0B;
    /// Error code accessors generated for Move v1 compatibility
    public fun err_tag_primary_type(): u64 { E_TAG_PRIMARY_TYPE }
    public fun err_tag_unknown_bit(): u64 { E_TAG_UNKNOWN_BIT }
    public fun err_tag_budget_exceeded(): u64 { E_TAG_BUDGET_EXCEEDED }
    public fun err_primary_type_not_allowed(): u64 { E_PRIMARY_TYPE_NOT_ALLOWED }
    public fun err_tag_mask_not_allowed(): u64 { E_TAG_MASK_NOT_ALLOWED }
    public fun err_roles_not_initialized(): u64 { E_ROLES_NOT_INITIALIZED }
    public fun err_payout_batch_cap_missing(): u64 { E_PAYOUT_BATCH_CAP_MISSING }
    public fun err_partner_payout_cap_missing(): u64 { E_PARTNER_PAYOUT_CAP_MISSING }
    public fun err_premium_cap_missing(): u64 { E_PREMIUM_CAP_MISSING }
    public fun err_premium_cap_expired(): u64 { E_PREMIUM_CAP_EXPIRED }
    public fun err_already_initialized(): u64 { E_ALREADY_INITIALIZED }
    public fun err_registry_missing(): u64 { E_REGISTRY_MISSING }
    public fun err_lottery_exists(): u64 { E_LOTTERY_EXISTS }
    public fun err_status_transition_not_allowed(): u64 { E_STATUS_TRANSITION_NOT_ALLOWED }
    public fun err_primary_type_locked(): u64 { E_PRIMARY_TYPE_LOCKED }
    public fun err_tags_locked(): u64 { E_TAGS_LOCKED }
    public fun err_snapshot_frozen(): u64 { E_SNAPSHOT_FROZEN }
    public fun err_sales_window_invalid(): u64 { E_SALES_WINDOW_INVALID }
    public fun err_ticket_price_zero(): u64 { E_TICKET_PRICE_ZERO }
    public fun err_ticket_limit_invalid(): u64 { E_TICKET_LIMIT_INVALID }
    public fun err_prize_plan_empty(): u64 { E_PRIZE_PLAN_EMPTY }
    public fun err_prize_slot_invalid(): u64 { E_PRIZE_SLOT_INVALID }
    public fun err_draw_algo_unsupported(): u64 { E_DRAW_ALGO_UNSUPPORTED }
    public fun err_sales_window_closed(): u64 { E_SALES_WINDOW_CLOSED }
    public fun err_lottery_not_active(): u64 { E_LOTTERY_NOT_ACTIVE }
    public fun err_draw_status_invalid(): u64 { E_DRAW_STATUS_INVALID }
    public fun err_cancel_reason_invalid(): u64 { E_CANCEL_REASON_INVALID }
    public fun err_cancellation_record_missing(): u64 { E_CANCELLATION_RECORD_MISSING }
    public fun err_distribution_bps_invalid(): u64 { E_DISTRIBUTION_BPS_INVALID }
    public fun err_jackpot_allowance_underflow(): u64 { E_JACKPOT_ALLOWANCE_UNDERFLOW }
    public fun err_jackpot_allowance_increase(): u64 { E_JACKPOT_ALLOWANCE_INCREASE }
    public fun err_payout_alloc_exceeded(): u64 { E_PAYOUT_ALLOC_EXCEEDED }
    public fun err_operations_alloc_exceeded(): u64 { E_OPERATIONS_ALLOC_EXCEEDED }
    public fun err_feature_unknown(): u64 { E_FEATURE_UNKNOWN }
    public fun err_feature_mode_invalid(): u64 { E_FEATURE_MODE_INVALID }
    public fun err_feature_disabled(): u64 { E_FEATURE_DISABLED }
    public fun err_pagination_limit(): u64 { E_PAGINATION_LIMIT }
    public fun err_purchase_qty_zero(): u64 { E_PURCHASE_QTY_ZERO }
    public fun err_purchase_qty_limit(): u64 { E_PURCHASE_QTY_LIMIT }
    public fun err_purchase_total_limit(): u64 { E_PURCHASE_TOTAL_LIMIT }
    public fun err_purchase_address_limit(): u64 { E_PURCHASE_ADDRESS_LIMIT }
    public fun err_amount_overflow(): u64 { E_AMOUNT_OVERFLOW }
    public fun err_premium_cap_mismatch(): u64 { E_PREMIUM_CAP_MISMATCH }
    public fun err_purchase_rate_limit_block(): u64 { E_PURCHASE_RATE_LIMIT_BLOCK }
    public fun err_purchase_rate_limit_window(): u64 { E_PURCHASE_RATE_LIMIT_WINDOW }
    public fun err_purchase_grace_restricted(): u64 { E_PURCHASE_GRACE_RESTRICTED }
    public fun err_vrf_pending(): u64 { E_VRF_PENDING }
    public fun err_vrf_not_requested(): u64 { E_VRF_NOT_REQUESTED }
    public fun err_vrf_nonce_unknown(): u64 { E_VRF_NONCE_UNKNOWN }
    public fun err_vrf_payload_mismatch(): u64 { E_VRF_PAYLOAD_MISMATCH }
    public fun err_vrf_attempt_out_of_order(): u64 { E_VRF_ATTEMPT_OUT_OF_ORDER }
    public fun err_vrf_rng_count_invalid(): u64 { E_VRF_RNG_COUNT_INVALID }
    public fun err_vrf_snapshot_empty(): u64 { E_VRF_SNAPSHOT_EMPTY }
    public fun err_vrf_consumed(): u64 { E_VRF_CONSUMED }
    public fun err_vrf_retry_window(): u64 { E_VRF_RETRY_WINDOW }
    public fun err_vrf_client_seed_overflow(): u64 { E_VRF_CLIENT_SEED_OVERFLOW }
    public fun err_vrf_deposit_not_initialized(): u64 { E_VRF_DEPOSIT_NOT_INITIALIZED }
    public fun err_vrf_deposit_config(): u64 { E_VRF_DEPOSIT_CONFIG }
    public fun err_vrf_requests_paused(): u64 { E_VRF_REQUESTS_PAUSED }
    public fun err_vrf_retry_policy_invalid(): u64 { E_VRF_RETRY_POLICY_INVALID }
    public fun err_vrf_manual_schedule_required(): u64 { E_VRF_MANUAL_SCHEDULE_REQUIRED }
    public fun err_vrf_manual_deadline(): u64 { E_VRF_MANUAL_DEADLINE }
    public fun err_winner_vrf_not_ready(): u64 { E_WINNER_VRF_NOT_READY }
    public fun err_winner_all_assigned(): u64 { E_WINNER_ALL_ASSIGNED }
    public fun err_winner_index_out_of_range(): u64 { E_WINNER_INDEX_OUT_OF_RANGE }
    public fun err_winner_dedup_exhausted(): u64 { E_WINNER_DEDUP_EXHAUSTED }
    public fun err_payout_state_missing(): u64 { E_PAYOUT_STATE_MISSING }
    public fun err_payout_round_non_monotonic(): u64 { E_PAYOUT_ROUND_NON_MONOTONIC }
    public fun err_payout_cooldown(): u64 { E_PAYOUT_COOLDOWN }
    public fun err_payout_batch_too_large(): u64 { E_PAYOUT_BATCH_TOO_LARGE }
    public fun err_payout_batch_cooldown(): u64 { E_PAYOUT_BATCH_COOLDOWN }
    public fun err_payout_batch_nonce(): u64 { E_PAYOUT_BATCH_NONCE }
    public fun err_payout_operations_budget(): u64 { E_PAYOUT_OPERATIONS_BUDGET }
    public fun err_partner_payout_budget_exceeded(): u64 { E_PARTNER_PAYOUT_BUDGET_EXCEEDED }
    public fun err_partner_payout_cooldown(): u64 { E_PARTNER_PAYOUT_COOLDOWN }
    public fun err_partner_payout_nonce(): u64 { E_PARTNER_PAYOUT_NONCE }
    public fun err_partner_payout_holder_mismatch(): u64 { E_PARTNER_PAYOUT_HOLDER_MISMATCH }
    public fun err_partner_payout_expired(): u64 { E_PARTNER_PAYOUT_EXPIRED }
    public fun err_refund_not_active(): u64 { E_REFUND_NOT_ACTIVE }
    public fun err_refund_round_non_monotonic(): u64 { E_REFUND_ROUND_NON_MONOTONIC }
    public fun err_refund_limit_tickets(): u64 { E_REFUND_LIMIT_TICKETS }
    public fun err_refund_limit_funds(): u64 { E_REFUND_LIMIT_FUNDS }
    public fun err_refund_status_invalid(): u64 { E_REFUND_STATUS_INVALID }
    public fun err_refund_batch_empty(): u64 { E_REFUND_BATCH_EMPTY }
    public fun err_refund_timestamp(): u64 { E_REFUND_TIMESTAMP }
    public fun err_refund_progress_incomplete(): u64 { E_REFUND_PROGRESS_INCOMPLETE }
    public fun err_refund_progress_funds(): u64 { E_REFUND_PROGRESS_FUNDS }
    public fun err_price_feed_exists(): u64 { E_PRICE_FEED_EXISTS }
    public fun err_price_feed_not_found(): u64 { E_PRICE_FEED_NOT_FOUND }
    public fun err_price_decimals_invalid(): u64 { E_PRICE_DECIMALS_INVALID }
    public fun err_price_stale(): u64 { E_PRICE_STALE }
    public fun err_price_fallback_active(): u64 { E_PRICE_FALLBACK_ACTIVE }
    public fun err_price_clamp_triggered(): u64 { E_PRICE_CLAMP_TRIGGERED }
    public fun err_price_clamp_active(): u64 { E_PRICE_CLAMP_ACTIVE }
    public fun err_price_clamp_not_active(): u64 { E_PRICE_CLAMP_NOT_ACTIVE }
    public fun err_bcs_decode(): u64 { E_BCS_DECODE }
    public fun err_autobot_registry_missing(): u64 { E_AUTOBOT_REGISTRY_MISSING }
    public fun err_autobot_already_registered(): u64 { E_AUTOBOT_ALREADY_REGISTERED }
    public fun err_autobot_not_registered(): u64 { E_AUTOBOT_NOT_REGISTERED }
    public fun err_autobot_expired(): u64 { E_AUTOBOT_EXPIRED }
    public fun err_autobot_forbidden_target(): u64 { E_AUTOBOT_FORBIDDEN_TARGET }
    public fun err_autobot_failure_limit(): u64 { E_AUTOBOT_FAILURE_LIMIT }
    public fun err_autobot_timelock(): u64 { E_AUTOBOT_TIMELOCK }
    public fun err_autobot_pending_exists(): u64 { E_AUTOBOT_PENDING_EXISTS }
    public fun err_autobot_pending_mismatch(): u64 { E_AUTOBOT_PENDING_MISMATCH }
    public fun err_autobot_pending_required(): u64 { E_AUTOBOT_PENDING_REQUIRED }
    public fun err_autobot_action_hash_empty(): u64 { E_AUTOBOT_ACTION_HASH_EMPTY }
    public fun err_autobot_caller_mismatch(): u64 { E_AUTOBOT_CALLER_MISMATCH }
    public fun err_history_missing(): u64 { E_HISTORY_MISSING }
    public fun err_history_mismatch(): u64 { E_HISTORY_MISMATCH }
    public fun err_finalization_incomplete(): u64 { E_FINALIZATION_INCOMPLETE }
    public fun err_history_not_authorized(): u64 { E_HISTORY_NOT_AUTHORIZED }
    public fun err_history_expected_missing(): u64 { E_HISTORY_EXPECTED_MISSING }
    public fun err_history_control_missing(): u64 { E_HISTORY_CONTROL_MISSING }
    public fun err_history_import_hash(): u64 { E_HISTORY_IMPORT_HASH }
    public fun err_history_id_mismatch(): u64 { E_HISTORY_ID_MISMATCH }
    public fun err_history_not_legacy(): u64 { E_HISTORY_NOT_LEGACY }
    public fun err_history_summary_missing(): u64 { E_HISTORY_SUMMARY_MISSING }
    public fun err_history_decode(): u64 { E_HISTORY_DECODE }
}
