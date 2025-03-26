module {
    
    public type InputId = {
        #VoteId: Text;
        #BallotId: Text;
    };

    public func format(input_id: InputId) : Text {
        switch(input_id) {
            case(#VoteId(id)) { "vote-" # id };
            case(#BallotId(id)) { "ballot-" # id };
        }
    };
};
