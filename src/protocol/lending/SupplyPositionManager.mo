import Nat                "mo:base/Nat";
import Map                "mo:map/Map";
import Result             "mo:base/Result";
import Float              "mo:base/Float";
import Int                "mo:base/Int";
import Array              "mo:base/Array";
import Iter               "mo:base/Iter";

import Types              "../Types";
import MapUtils           "../utils/Map";
import Math               "../utils/Math";
import LendingTypes       "Types";
import Indexer            "Indexer";

module {

    type Account               = Types.Account;
    type TxIndex               = Types.TxIndex;
    type Result<Ok, Err>       = Result.Result<Ok, Err>;

    type SupplyPosition        = LendingTypes.SupplyPosition;
    type SupplyPositionTx      = LendingTypes.SupplyPositionTx;
    type SupplyRegister        = LendingTypes.SupplyRegister;
    type LendingIndex          = LendingTypes.LendingIndex;
    type SupplyInfo            = LendingTypes.SupplyInfo;

    // Pure accounting manager for supply positions
    // No token transfers, no indexer updates (raw_supplied)
    // Just position management with index scaling
    public class SupplyPositionManager({
        register: SupplyRegister;
        indexer: Indexer.Indexer;
    }) {

        public func get_position({ account: Account; }) : ?SupplyPosition {
            Map.get(register.supply_positions, MapUtils.acchash, account);
        };

        public func get_positions() : Map.Iter<SupplyPosition> {
            Map.vals(register.supply_positions);
        };

        // Set a position
        public func set_position({
            account: Account;
            position: SupplyPosition;
        }) {
            Map.set(register.supply_positions, MapUtils.acchash, account, position);
        };

        // Delete a position
        public func delete_position({ account: Account; }) {
            Map.delete(register.supply_positions, MapUtils.acchash, account);
        };

        // Add a transaction to a position (used for recording supply/withdraw txs)
        public func add_tx({
            position: SupplyPosition;
            tx: SupplyPositionTx;
        }) : SupplyPosition {
            let new_tx = Array.append(position.tx, [tx]);
            { position with tx = new_tx; };
        };

        // Add amount to a supply position (scales up existing position with current index)
        public func add_amount({
            account: Account;
            amount: Float;
            time: Nat;
        }) : Result<(), Text> {

            let index = indexer.update(time).supply_index;
            let position = get_position({ account; });

            // Scale up existing position (if any) and add new amount
            let new_position = add_supply({
                position;
                account;
                index;
                amount = Int.abs(Math.floor_to_int(amount));
            });

            Map.set(register.supply_positions, MapUtils.acchash, account, new_position);

            #ok(());
        };

        // Remove amount from a supply position (returns withdrawn amount)
        public func remove_amount({
            account: Account;
            amount: Nat;
            max_slippage_amount: Nat;
            time: Nat;
        }) : Result<Float, Text> {

            let position = switch(get_position({ account; })){
                case(null) { return #err("No supply position found for account"); };
                case(?p) { p; };
            };

            ignore indexer.update(time);

            let withdraw_result = withdraw_supply({ position; amount; max_slippage_amount; });
            let { withdrawn; remaining; } = switch(withdraw_result){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };

            let update = { position with raw_amount = remaining; };

            // If position is empty after withdrawal, delete it
            if (remaining == 0.0) {
                Map.delete(register.supply_positions, MapUtils.acchash, account);
            } else {
                Map.set(register.supply_positions, MapUtils.acchash, account, update);
            };

            #ok(withdrawn);
        };

        public func get_supply_info(time: Nat, account: Account) : SupplyInfo {

            let index = indexer.get_index_now(time).supply_index;

            switch (Map.get(register.supply_positions, MapUtils.acchash, account)){
                case (null) {
                    {
                        account;
                        supplied = 0.0;
                        accrued_amount = 0.0;
                        supply_index = index;
                    };
                };
                case (?position) {
                    to_supply_info({ position; index; });
                };
            };
        };

        public func get_all_supply_info(time: Nat) : { positions: [SupplyInfo]; total_supplied: Float } {

            let index = indexer.get_index_now(time).supply_index;
            var total_supplied = 0.0;

            let positions = Array.map<SupplyPosition, SupplyInfo>(
                Iter.toArray(Map.vals(register.supply_positions)),
                func (position: SupplyPosition) : SupplyInfo {
                    let info = to_supply_info({ position; index; });
                    total_supplied += info.accrued_amount;
                    info;
                }
            );

            { positions; total_supplied; };
        };

        // Public helpers for SupplyRegistry to use

        public func add_supply({
            position: ?SupplyPosition;
            account: Account;
            index: LendingTypes.Index;
            amount: Nat;
        }) : SupplyPosition {
            switch(position){
                case(null) {
                    // Create new position
                    {
                        account;
                        tx = [];
                        raw_amount = Float.fromInt(amount);
                        index = index.value;
                    };
                };
                case(?p) {
                    // Scale up existing position to current index
                    let scaled_up = indexer.scale_supply_up({
                        principal = p.raw_amount;
                        past_index = p.index;
                    });
                    // Add new amount
                    let new_raw = scaled_up + Float.fromInt(amount);
                    {
                        p with
                        raw_amount = new_raw;
                        index = index.value;
                    };
                };
            };
        };

        public func withdraw_supply({
            position: SupplyPosition;
            amount: Nat;
            max_slippage_amount: Nat;
        }) : Result<{
            withdrawn: Float;
            raw_withdrawn: Float;
            remaining: Float;
            from_interests: Float;
        }, Text> {

            // Scale up to current value
            let current_value = indexer.scale_supply_up({
                principal = position.raw_amount;
                past_index = position.index;
            });

            let requested = Float.fromInt(amount);

            if (requested > current_value + Float.fromInt(max_slippage_amount)) {
                return #err("Requested withdrawal " # debug_show(requested) # " exceeds available balance " # debug_show(current_value) # " plus slippage tolerance " # debug_show(max_slippage_amount));
            };

            // If requested amount + slippage is close to the full balance, withdraw everything to avoid tiny leftovers
            var withdrawn = requested;
            if (Float.fromInt(amount + max_slippage_amount) >= current_value) {
                withdrawn := current_value;
            };

            // Calculate raw amount to remove
            let raw_withdrawn = indexer.scale_supply_down({
                scaled = withdrawn;
                past_index = position.index;
            });

            let remaining = position.raw_amount - raw_withdrawn;

            if (remaining < 0.0) {
                return #err("Remaining raw amount would be negative: " # debug_show(remaining));
            };

            // Calculate interest portion
            let from_interests = Float.max(0.0, withdrawn - position.raw_amount);

            #ok({
                withdrawn;
                raw_withdrawn;
                remaining;
                from_interests;
            });
        };

        func to_supply_info({
            position: SupplyPosition;
            index: LendingTypes.Index;
        }) : SupplyInfo {
            let accrued_amount = indexer.scale_supply_up({
                principal = position.raw_amount;
                past_index = position.index;
            });

            {
                account = position.account;
                supplied = position.raw_amount;
                accrued_amount;
                supply_index = index;
            };
        };

    };

};
