module std::math64 {
    friend std::fixed_point32;
    const E_OVERFLOW: u64 = 0;
    const E_DIV_BY_ZERO: u64 = 1;

    const MAX_U64_AS_U128: u128 = 18446744073709551615u128;

    public fun checked_add(a: u64, b: u64): u64 {
        let result = a + b;
        assert!(result >= a, E_OVERFLOW);
        result
    }

    public fun checked_mul(a: u64, b: u64): u64 {
        if (a == 0 || b == 0) {
            0
        } else {
            let result = a * b;
            assert!(result / a == b, E_OVERFLOW);
            result
        }
    }

    public fun mod(value: u64, modulus: u64): u64 {
        assert!(modulus > 0, E_DIV_BY_ZERO);
        value % modulus
    }

    public fun mul_div(value: u64, numerator: u64, denominator: u64): u64 {
        assert!(denominator > 0, E_DIV_BY_ZERO);
        let value128 = to_u128(value);
        let numerator128 = to_u128(numerator);
        let denominator128 = to_u128(denominator);
        let product = value128 * numerator128;
        let result128 = product / denominator128;
        from_u128(result128)
    }

    public(friend) fun to_u128(value: u64): u128 {
        let result = 0u128;
        let base = 1u128;
        let remaining = value;
        while (remaining > 0) {
            if ((remaining & 1) == 1) {
                result = result + base;
            };
            remaining = remaining >> 1;
            if (remaining > 0) {
                base = base << 1;
            };
        };
        result
    }

    public(friend) fun from_u128(value: u128): u64 {
        assert!(value <= MAX_U64_AS_U128, E_OVERFLOW);
        let result = 0u64;
        let base = 1u64;
        let remaining = value;
        while (remaining > 0) {
            if ((remaining & 1u128) == 1u128) {
                result = result + base;
            };
            remaining = remaining >> 1;
            if (remaining > 0) {
                base = base << 1;
            };
        };
        result
    }

    public fun from_u16(value: u16): u64 {
        let result = 0u64;
        let remaining = value;
        while (remaining > 0) {
            result = result + 1;
            remaining = remaining - 1;
        };
        result
    }
}
