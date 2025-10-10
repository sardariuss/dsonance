import Types  "../Types";
import RollingTimeline "../utils/RollingTimeline";

import Debug "mo:base/Debug";

module {

    type VoteType             = Types.VoteType;
    type Account              = Types.Account;
    type BallotType           = Types.BallotType;
    type DebtInfo             = Types.DebtInfo;
    type YesNoBallot          = Types.YesNoBallot;
    type LockInfo             = Types.LockInfo;
    type Lock                 = Types.Lock;
    type Time                 = Int;
    
    // TODO: it would probably be clever to put the typed choice outside of the BallotInfo type
    // to avoid all these getters and setters

    public func unwrap_yes_no(ballot: BallotType): YesNoBallot {
        switch(ballot){
            case(#YES_NO(b)) { b; };
        };
    };

    public func get_account(ballot: BallotType): Account {
        switch(ballot){
            case(#YES_NO(b)) { b.from; };
        };
    };

    public func get_timestamp(ballot: BallotType): Time {
        switch(ballot){
            case(#YES_NO(b)) { b.timestamp; };
        };
    };

    public func get_amount(ballot: BallotType): Nat {
        switch(ballot){
            case(#YES_NO(b)) { b.amount; };
        };
    };

    public func get_dissent(ballot: BallotType): Float {
        switch(ballot){
            case(#YES_NO(b)) { b.dissent; };
        };
    };

    public func get_consent(ballot: BallotType): Float {
        switch(ballot){
            case(#YES_NO(b)) { RollingTimeline.current(b.consent); };
        };
    };

    public func unwrap_lock_info(ballot: YesNoBallot) : LockInfo {
        switch(ballot.lock){
            case(null) { Debug.trap("Lock not found"); };
            case(?lock) { lock; };
        };
    };

    public func unwrap_lock(ballot: BallotType) : Lock {
        switch(ballot){
            case(#YES_NO(b)) { 
                let lock_info = unwrap_lock_info(b);
                { 
                    release_date = lock_info.release_date;
                    amount = b.amount;
                    id = b.ballot_id; 
                };
            };
        };
    };

};