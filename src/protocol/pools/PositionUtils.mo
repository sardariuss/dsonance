import Types  "../Types";
import RollingTimeline "../utils/RollingTimeline";

import Debug "mo:base/Debug";

module {

    type PoolType             = Types.PoolType;
    type Account              = Types.Account;
    type PositionType           = Types.PositionType;
    type DebtInfo             = Types.DebtInfo;
    type YesNoPosition          = Types.YesNoPosition;
    type LockInfo             = Types.LockInfo;
    type Lock                 = Types.Lock;
    type Time                 = Int;
    
    // TODO: it would probably be clever to put the typed choice outside of the PositionInfo type
    // to avoid all these getters and setters

    public func unwrap_yes_no(position: PositionType): YesNoPosition {
        switch(position){
            case(#YES_NO(b)) { b; };
        };
    };

    public func get_account(position: PositionType): Account {
        switch(position){
            case(#YES_NO(b)) { b.from; };
        };
    };

    public func get_timestamp(position: PositionType): Time {
        switch(position){
            case(#YES_NO(b)) { b.timestamp; };
        };
    };

    public func get_amount(position: PositionType): Nat {
        switch(position){
            case(#YES_NO(b)) { b.amount; };
        };
    };

    public func get_dissent(position: PositionType): Float {
        switch(position){
            case(#YES_NO(b)) { b.dissent; };
        };
    };

    public func unwrap_lock_info(position: YesNoPosition) : LockInfo {
        switch(position.lock){
            case(null) { Debug.trap("Lock not found"); };
            case(?lock) { lock; };
        };
    };

    public func unwrap_lock(position: PositionType) : Lock {
        switch(position){
            case(#YES_NO(b)) { 
                let lock_info = unwrap_lock_info(b);
                { 
                    release_date = lock_info.release_date;
                    amount = b.amount;
                    id = b.position_id; 
                };
            };
        };
    };

};