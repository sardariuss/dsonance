module {

    public type Times = {
        #times: Nat;
        #repeatedly;
    };
    
    public type ITearDownable = {
        teardown: () -> ();
    };

    public type IMock<R> = ITearDownable and {
        expect_call: (R, Times) -> ();
    };

};