module lottery_multi::math {
    const U64_MAX: u64 = 0xffffffffffffffff;
    const U64_MAX_AS_U128: u128 = 0xffffffffffffffff;
    const U8_MAX_AS_U64: u64 = 255;

    public fun widen_u16_from_u8(value: u8): u16 {
        let result = 0u16;
        let temp = value;
        while (temp > 0u8) {
            result = result + 1u16;
            temp = temp - 1u8;
        };
        result
    }

    public fun widen_u64_from_u8(value: u8): u64 {
        widen_u64_from_u16(widen_u16_from_u8(value))
    }

    public fun widen_u64_from_u16(value: u16): u64 {
        let result = 0u64;
        let temp = value;
        while (temp > 0u16) {
            result = result + 1u64;
            temp = temp - 1u16;
        };
        result
    }

    public fun widen_u128_from_u8(value: u8): u128 {
        widen_u128_from_u64(widen_u64_from_u8(value))
    }

    public fun widen_u128_from_u16(value: u16): u128 {
        widen_u128_from_u64(widen_u64_from_u16(value))
    }

    public fun widen_u128_from_u64(value: u64): u128 {
        let result = 0u128;
        let temp = value;
        let base = 1u128;
        while (temp > 0u64) {
            let bit = temp % 2u64;
            if (bit == 1u64) {
                result = result + base;
            };
            temp = temp / 2u64;
            if (temp > 0u64) {
                base = base * 2u128;
            };
        };
        result
    }

    public fun checked_u64_from_u128(value: u128, abort_code: u64): u64 {
        assert!(value <= U64_MAX_AS_U128, abort_code);
        let result = 0u64;
        let temp = value;
        let base = 1u64;
        while (temp > 0u128) {
            let bit = temp % 2u128;
            if (bit == 1u128) {
                result = safe_add_u64(result, base, abort_code);
            };
            temp = temp / 2u128;
            if (temp > 0u128) {
                base = safe_mul_u64(base, 2u64, abort_code);
            };
        };
        result
    }

    public fun narrow_u8_from_u64(value: u64, abort_code: u64): u8 {
        assert!(value <= U8_MAX_AS_U64, abort_code);
        let result = 0u8;
        let temp = value;
        while (temp > 0u64) {
            result = result + 1u8;
            temp = temp - 1u64;
        };
        result
    }

    public fun safe_add_u64(a: u64, b: u64, abort_code: u64): u64 {
        assert!(b <= U64_MAX - a, abort_code);
        a + b
    }

    public fun safe_mul_u64(a: u64, b: u64, abort_code: u64): u64 {
        if (a == 0u64 || b == 0u64) {
            return 0u64
        };
        assert!(b <= U64_MAX / a, abort_code);
        a * b
    }
}
