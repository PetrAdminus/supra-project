module lottery::math {
    const E_OVERFLOW: u64 = 1;
    const E_DIVISION_BY_ZERO: u64 = 2;

    public fun checked_add(a: u64, b: u64): u64 {
        let result = a + b;
        result
    }

    public fun checked_sub(a: u64, b: u64): u64 {
        assert!(a >= b, E_OVERFLOW);
        let result = a - b;
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

    public fun checked_div(numerator: u64, denominator: u64): u64 {
        assert!(denominator > 0, E_DIVISION_BY_ZERO);
        numerator / denominator
    }

    public fun mul_div(a: u64, b: u64, denominator: u64): u64 {
        let product = checked_mul(a, b);
        checked_div(product, denominator)
    }

    public fun modulo(value: u64, denominator: u64): u64 {
        assert!(denominator > 0, E_DIVISION_BY_ZERO);
        value % denominator
    }

    public fun from_u16(value: u16): u64 {
        from_u16_internal(value, 0)
    }

    fun from_u16_internal(remaining: u16, accumulator: u64): u64 {
        if (remaining == 0) {
            accumulator
        } else {
            from_u16_internal(remaining - 1, accumulator + 1)
        }
    }
}
