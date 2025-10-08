module lottery::test_utils {
    use std::option;

    public fun unwrap<T>(opt: option::Option<T>): T {
        let mut tmp = opt;
        option::extract(&mut tmp)
    }
}
