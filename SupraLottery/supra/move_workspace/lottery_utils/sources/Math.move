module lottery_utils::math {
    const U64_MAX: u64 = 0xffffffffffffffff;
    const U64_MAX_AS_U128: u128 = 0xffffffffffffffff;
    const U8_MAX_AS_U64: u64 = 255;

    public fun widen_u16_from_u8(value: u8): u16 {
        widen_u16_from_u8_inner(value, 0u16)
    }

    fun widen_u16_from_u8_inner(value: u8, acc: u16): u16 {
        if (value == 0u8) {
            acc
        } else {
            widen_u16_from_u8_inner(value - 1u8, acc + 1u16)
        }
    }

    public fun widen_u64_from_u8(value: u8): u64 {
        widen_u64_from_u16(widen_u16_from_u8(value))
    }

    public fun widen_u64_from_u16(value: u16): u64 {
        widen_u64_from_u16_inner(value, 0u64)
    }

    fun widen_u64_from_u16_inner(value: u16, acc: u64): u64 {
        if (value == 0u16) {
            acc
        } else {
            widen_u64_from_u16_inner(value - 1u16, acc + 1u64)
        }
    }

    public fun widen_u128_from_u8(value: u8): u128 {
        widen_u128_from_u64(widen_u64_from_u8(value))
    }

    public fun widen_u128_from_u16(value: u16): u128 {
        widen_u128_from_u64(widen_u64_from_u16(value))
    }

    public fun widen_u128_from_u64(value: u64): u128 {
        widen_u128_from_u64_bits(value, 1u128, 0u128)
    }

    fun widen_u128_from_u64_bits(value: u64, base: u128, acc: u128): u128 {
        if (value == 0u64) {
            acc
        } else {
            let bit = value % 2u64;
            let updated = if (bit == 1u64) {
                acc + base
            } else {
                acc
            };
            let remaining = value / 2u64;
            if (remaining == 0u64) {
                updated
            } else {
                widen_u128_from_u64_bits(remaining, base * 2u128, updated)
            }
        }
    }

    public fun checked_u64_from_u128(value: u128, abort_code: u64): u64 {
        assert!(value <= U64_MAX_AS_U128, abort_code);
        checked_u64_from_u128_bits(value, 1u64, 0u64, abort_code)
    }

    fun checked_u64_from_u128_bits(
        remaining: u128,
        base: u64,
        acc: u64,
        abort_code: u64,
    ): u64 {
        if (remaining == 0u128) {
            acc
        } else {
            let bit = remaining % 2u128;
            let next_acc = if (bit == 1u128) {
                safe_add_u64(acc, base, abort_code)
            } else {
                acc
            };
            let next_remaining = remaining / 2u128;
            if (next_remaining == 0u128) {
                next_acc
            } else {
                let next_base = safe_mul_u64(base, 2u64, abort_code);
                checked_u64_from_u128_bits(next_remaining, next_base, next_acc, abort_code)
            }
        }
    }

    public fun narrow_u8_from_u64(value: u64, abort_code: u64): u8 {
        assert!(value <= U8_MAX_AS_U64, abort_code);
        narrow_u8_from_u64_inner(value, 0u8)
    }

    fun narrow_u8_from_u64_inner(value: u64, acc: u8): u8 {
        if (value == 0u64) {
            acc
        } else {
            narrow_u8_from_u64_inner(value - 1u64, acc + 1u8)
        }
    }

    public fun safe_add_u64(a: u64, b: u64, abort_code: u64): u64 {
        assert!(b <= U64_MAX - a, abort_code);
        a + b
    }

    public fun safe_mul_u64(a: u64, b: u64, abort_code: u64): u64 {
        if (a == 0u64 || b == 0u64) {
            0u64
        } else {
            assert!(b <= U64_MAX / a, abort_code);
            a * b
        }
    }
}
