import Types "../Types";

module {

    public func transferFromErrorToText(err: Types.TransferFromError) : Text {
        switch(err) {
            case (#BadFee({expected_fee})) { "Bad fee: expected " # debug_show(expected_fee) };
            case (#BadBurn({min_burn_amount})) { "Bad burn: minimum amount " # debug_show(min_burn_amount) };
            case (#InsufficientFunds({balance})) { "Insufficient funds: balance " # debug_show(balance) };
            case (#InsufficientAllowance({allowance})) { "Insufficient allowance: " # debug_show(allowance) };
            case (#TooOld) { "Transaction too old" };
            case (#CreatedInFuture({ledger_time})) { "Transaction created in future: " # debug_show(ledger_time) };
            case (#Duplicate({duplicate_of})) { "Duplicate transaction: " # debug_show(duplicate_of) };
            case (#TemporarilyUnavailable) { "Service temporarily unavailable" };
            case (#GenericError({error_code; message})) { "Generic error " # debug_show(error_code) # ": " # message };
        };
    };

    public func approveErrorToText(err: Types.ApproveError) : Text {
        switch(err) {
            case (#BadFee({expected_fee})) { "Bad fee: expected " # debug_show(expected_fee) };
            case (#InsufficientFunds({balance})) { "Insufficient funds: balance " # debug_show(balance) };
            case (#AllowanceChanged({current_allowance})) { "Allowance changed: current " # debug_show(current_allowance) };
            case (#Expired({ledger_time})) { "Transaction expired: " # debug_show(ledger_time) };
            case (#TooOld) { "Transaction too old" };
            case (#CreatedInFuture({ledger_time})) { "Transaction created in future: " # debug_show(ledger_time) };
            case (#Duplicate({duplicate_of})) { "Duplicate transaction: " # debug_show(duplicate_of) };
            case (#TemporarilyUnavailable) { "Service temporarily unavailable" };
            case (#GenericError({error_code; message})) { "Generic error " # debug_show(error_code) # ": " # message };
        };
    };

    public func transferErrorToText(error: Types.TransferError) : Text {
        switch(error) {
            case (#BadFee({expected_fee})) { "Bad fee: expected " # debug_show(expected_fee) };
            case (#BadBurn({min_burn_amount})) { "Bad burn: minimum amount " # debug_show(min_burn_amount) };
            case (#InsufficientFunds({balance})) { "Insufficient funds: balance " # debug_show(balance) };
            case (#Duplicate({duplicate_of})) { "Duplicate transaction: " # debug_show(duplicate_of) };
            case (#TemporarilyUnavailable) { "Service temporarily unavailable" };
            case (#GenericError({error_code; message})) { "Generic error " # debug_show(error_code) # ": " # message };
            case (#TooOld) { "Transaction too old" };
            case (#CreatedInFuture({ledger_time})) { "Transaction created in future: " # debug_show(ledger_time) };
            case (#Trapped({error_code})) { "Transaction trapped: " # debug_show(error_code) };
        };
    };

}