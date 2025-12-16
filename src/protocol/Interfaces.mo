import Types "Types";
import LockInfoUpdater "locks/LockInfoUpdater";
import Map "mo:map/Map";

module {

    type Decayed = Types.Decayed;

    public type IDecayModel = {
        compute_decay: (Nat) -> Float;
        create_decayed: (Float, Nat) -> Decayed;
        unwrap_decayed: (Decayed, Nat) -> Float;
    };

    public type ILockInfoUpdater = {
        add: (new: LockInfoUpdater.Elem, previous: Map.Iter<LockInfoUpdater.Elem>, time: Nat) -> ();
    };

};