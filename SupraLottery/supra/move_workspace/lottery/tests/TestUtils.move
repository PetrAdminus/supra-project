#[test_only]
module lottery::test_utils {
    use std::option;

    public fun unwrap<T>(o: option::Option<T>): T {
        assert!(option::is_some(&o), 9);
        option::extract(o)
    }
}
