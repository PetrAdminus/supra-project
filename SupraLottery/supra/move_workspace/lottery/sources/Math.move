// sources/Math.move
module lottery::math {
    /// Overflow error used by arithmetic helpers.
    const E_OVERFLOW: u64 = 1;
    /// Division by zero error used by arithmetic helpers.
    const E_DIVISION_BY_ZERO: u64 = 2;

    /// Adds two u64 values and checks for overflow.
    public fun checked_add(left: u64, right: u64): u64 {
        let sum = left + right;
        assert!(sum >= left, E_OVERFLOW);
        sum
    }

    /// Multiplies two u64 values and checks for overflow.
    public fun checked_mul(left: u64, right: u64): u64 {
        if (left == 0 || right == 0) {
            return 0
        };
        let product = left * right;
        assert!(product / left == right, E_OVERFLOW);
        product
    }

    /// Returns `(value * numerator) / denominator` with overflow and division checks.
    public fun mul_div(value: u64, numerator: u64, denominator: u64): u64 {
        assert!(denominator > 0, E_DIVISION_BY_ZERO);
        let product = checked_mul(value, numerator);
        product / denominator
    }

    /// Returns `value % modulus` and ensures the modulus is non-zero.
    public fun rem(value: u64, modulus: u64): u64 {
        assert!(modulus > 0, E_DIVISION_BY_ZERO);
        value % modulus
    }

    /// Converts `u16` to `u64` without using cast operators.
    public fun from_u16(input: u16): u64 {
        from_u16_inner(input, 0u64)
    }

    fun from_u16_inner(remaining: u16, acc: u64): u64 {
        if (remaining == 0u16) {
            acc
        } else {
            let next_acc = checked_add(acc, 1u64);
            from_u16_inner(remaining - 1u16, next_acc)
        }
    }
}
