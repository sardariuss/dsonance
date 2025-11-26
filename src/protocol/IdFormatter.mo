module {
    
    public type InputId = {
        #Pool: Text;
        #Position: Text;
    };

    public func format(input_id: InputId) : Text {
        switch(input_id) {
            case(#Pool(id)) { "pool-" # id };
            case(#Position(id)) { "position-" # id };
        }
    };
};
