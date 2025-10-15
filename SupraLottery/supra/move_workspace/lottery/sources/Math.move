// sources/Math.move
module lottery::math {
    /// Ошибка переполнения при арифметических операциях.
    const E_OVERFLOW: u64 = 1;
    /// Ошибка деления на ноль при арифметических операциях.
    const E_DIVISION_BY_ZERO: u64 = 2;

    /// Сложение `u64` с проверкой переполнения.
    public fun checked_add(left: u64, right: u64): u64 {
        let sum = left + right;
        assert!(sum >= left, E_OVERFLOW);
        sum
    }

    /// Умножение `u64` с проверкой переполнения.
    public fun checked_mul(left: u64, right: u64): u64 {
        if (left == 0 || right == 0) {
            return 0
        };
        let product = left * right;
        assert!(product / left == right, E_OVERFLOW);
        product
    }

    /// Возвращает `(value * numerator) / denominator`, проверяя переполнения и деление на ноль.
    public fun mul_div(value: u64, numerator: u64, denominator: u64): u64 {
        assert!(denominator > 0, E_DIVISION_BY_ZERO);
        let product = checked_mul(value, numerator);
        product / denominator
    }

    /// Остаток от деления `value` на `modulus` c проверкой деления на ноль.
    public fun rem(value: u64, modulus: u64): u64 {
        assert!(modulus > 0, E_DIVISION_BY_ZERO);
        value % modulus
    }

    /// Безопасное преобразование `u16` в `u64` без использования операторов приведения.
    public fun from_u16(input: u16): u64 {
        let mut remaining = input;
        let mut acc = 0u64;
        while (remaining > 0u16) {
            acc = checked_add(acc, 1);
            remaining = remaining - 1;
        };
        acc
    }
}
