module lottery::test_utils {
    use std::option;

    public fun unwrap<T>(opt: option::Option<T>): T {
        option::destroy_some(opt)
    }
}
