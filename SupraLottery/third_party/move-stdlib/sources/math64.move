module std::math64 {
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
        let value128 = value as u128;
        let numerator128 = numerator as u128;
        let denominator128 = denominator as u128;
        let product = value128 * numerator128;
        let result128 = product / denominator128;
        assert!(result128 <= MAX_U64_AS_U128, E_OVERFLOW);
        result128 as u64
    }
}
