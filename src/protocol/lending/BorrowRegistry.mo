import Nat                "mo:base/Nat";
import Map                "mo:map/Map";
import Result             "mo:base/Result";
import Debug              "mo:base/Debug";
import Float              "mo:base/Float";
import Option             "mo:base/Option";
import Int                "mo:base/Int";

import Types              "../Types";
import MapUtils           "../utils/Map";
import IterUtils          "../utils/Iter";
import LedgerTypes        "../ledger/Types";
import Borrow             "./primitives/Borrow";
import BorrowPositionner  "BorrowPositionner";
import LendingTypes       "Types";
import Indexer            "Indexer";
import WithdrawalQueue    "WithdrawalQueue";
import UtilizationUpdater "UtilizationUpdater";
import SupplyAccount      "SupplyAccount";

module {

    type Account               = Types.Account;
    type TxIndex               = Types.TxIndex;
    type Result<Ok, Err>       = Result.Result<Ok, Err>;
    
    type Repayment             = LendingTypes.Repayment;
    type BorrowPosition        = LendingTypes.BorrowPosition;
    type Loan                  = LendingTypes.Loan;
    type BorrowRegister        = LendingTypes.BorrowRegister;
    type Borrow                = LendingTypes.Borrow;
    type IDex                  = LedgerTypes.IDex;
    type ILedgerAccount        = LedgerTypes.ILedgerAccount;
    type ISwapPayable          = LedgerTypes.ISwapPayable;
    type BorrowParameters      = LendingTypes.BorrowParameters;
    type Liquidation = {
        raw_borrowed: Float;
        total_collateral: Nat;
    };

    // @todo: function to delete positions repaid that are too old
    public class BorrowRegistry({
        register: BorrowRegister;
        supply: SupplyAccount.SupplyAccount;
        collateral: ILedgerAccount and ISwapPayable;
        borrow_positionner: BorrowPositionner.BorrowPositionner;
        indexer: Indexer.Indexer;
        withdrawal_queue: WithdrawalQueue.WithdrawalQueue;
        utilization_updater: UtilizationUpdater.UtilizationUpdater;
        parameters: BorrowParameters;
        dex: IDex;
    }){

        public func get_position({ account: Account; }) : ?BorrowPosition {
            Map.get(register.borrow_positions, MapUtils.acchash, account);
        };

        public func get_positions() : Map.Iter<BorrowPosition> {
            Map.vals(register.borrow_positions);
        };

        public func supply_collateral({
            account: Account;
            amount: Nat;
        }) : async* Result<(), Text> {

            // Transfer the collateral from the user account
            let tx = switch(await* collateral.pull({ from = account; amount; })){
                case(#err(_)) { return #err("Failed to transfer collateral from the user account"); };
                case(#ok(tx)) { tx; };
            };

            let position =  Map.get(register.borrow_positions, MapUtils.acchash, account);

            // Create or update the borrow position
            var update = borrow_positionner.provide_collateral({ position; account; amount; });
            update := BorrowPositionner.add_tx({ position = update; tx = #COLLATERAL_PROVIDED(tx); });
            Map.set(register.borrow_positions, MapUtils.acchash, account, update);

            #ok;
        };

        public func withdraw_collateral({
            account: Account;
            amount: Nat;
        }) : async* Result<(), Text> {

            let position = switch(Map.get(register.borrow_positions, MapUtils.acchash, account)){
                case(null) { return #err("No position found for account " # debug_show(account)); };
                case(?p) { p; };
            };

            let index = indexer.get_state().borrow_index;

            // Remove the collateral from the borrow position
            var update = switch(borrow_positionner.withdraw_collateral({ position; amount; index; })){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };

            // Transfer the collateral to the user account
            let tx = switch((await* collateral.transfer({ to = account; amount; })).result){
                case(#err(_)) { return #err("Failed to transfer the collateral to the user account"); };
                case(#ok(tx)) { tx; };
            };

            update := BorrowPositionner.add_tx({ position = update; tx = #COLLATERAL_WITHDRAWNED(tx); });
            Map.set(register.borrow_positions, MapUtils.acchash, account, update);

            #ok;
        };

        public func borrow({
            account: Account;
            amount: Nat;
        }) : async* Result<(), Text> {

            let supply_balance = supply.get_balance();
            if (supply_balance < amount){
                return #err("Available liquidity " # debug_show(supply_balance) # " is less than the requested amount " # debug_show(amount));
            };
            
            let position = switch(Map.get(register.borrow_positions, MapUtils.acchash, account)){
                case(null) { return #err("No borrow position found for account " # debug_show(account)); };
                case(?p) { p; };
            };

            // @todo: should add to a map of <Account, Nat> the amount concurrent borrows that could 
            // increase the utilization ratio more than 1.0

            // Verify the utilization does not exceed the allowed limit
            let utilization = switch(utilization_updater.add_raw_borrow(indexer.get_state().utilization, amount)){
                case(#err(err)) { return #err("Failed to update utilization: " # err); };
                case(#ok(u)) { u; };
            };
            if (utilization.ratio > 1.0) {
                return #err("Utilization of " # debug_show(utilization) # " is greater than 1.0");
            };
            if (utilization.raw_borrowed > Float.fromInt(parameters.borrow_cap)){
                return #err("Borrow cap of " # debug_show(parameters.borrow_cap) # " exceeded with current utilization " # debug_show(utilization));
            };

            let index = indexer.get_state().borrow_index;

            var update = switch(borrow_positionner.borrow_supply({ position; index; amount; })){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };
            
            // Capture the borrow index before initiating the transfer.
            // Note: There may be a slight time drift (~1–2 seconds) between capturing the index
            // and updating the user's position, due to the await on the transfer.
            // This means the position will be recorded with a slightly stale index.
            // In practice, this has negligible impact on accuracy since the interest accrued
            // over a few seconds is minimal. This tradeoff is acceptable to preserve
            // consistency in how interest is calculated and avoid retroactive index shifts.
            
            // Transfer the borrow amount to the user account
            let tx = switch(await* supply.transfer({ to = account; amount; })){
                case(#err(err)) { return #err("Failed to transfer borrow amount to the user account: " # debug_show(err)); };
                case(#ok(tx)) { tx; };
            };

            // Update the borrow position
            update := BorrowPositionner.add_tx({ position = update; tx = #SUPPLY_BORROWED(tx); });
            Map.set(register.borrow_positions, MapUtils.acchash, account, update);
            indexer.add_raw_borrow({ amount; });

            #ok;
        };

        public func repay({
            account: Account;
            repayment: Repayment;
        }) : async* Result<(), Text> {
            
            let position = switch(Map.get(register.borrow_positions, MapUtils.acchash, account)){
                case(null) { return #err("No position found for account " # debug_show(account)); };
                case(?p) { p; };
            };

            let index = indexer.get_state().borrow_index;

            let { amount; raw_repaid; remaining; } = switch(borrow_positionner.repay_supply({ position; index; repayment; })){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };

            // Transfer the repayment from the user
            let tx = switch(await* supply.pull({ from = account; amount; })){
                case(#err(_)) { return #err("Transfer failed"); };
                case(#ok(tx)) { tx; };
            };

            // Update the borrow position
            var update = { position with borrow = remaining; };
            update := BorrowPositionner.add_tx({ position = update; tx = #SUPPLY_REPAID(tx); });
            Map.set(register.borrow_positions, MapUtils.acchash, account, update);

            indexer.remove_raw_borrow({ amount = raw_repaid });

            // Once a position is repaid, it might allow the unlock withdrawal of supply
            ignore await* withdrawal_queue.process_pending_withdrawals();

            #ok;
        };

        /// Liquidate borrow positions if their health factor is below 1.0.
        public func check_all_positions_and_liquidate() : async* Result<(), Text> {

            let index = indexer.get_state().borrow_index;
            let loans = get_loans();

            let total_to_liquidate = IterUtils.fold_left(loans, 0, func (sum: Nat, loan: Loan): Nat {
                sum + Option.get(loan.collateral_to_liquidate, 0);
            });

            let prepare_swap_args = {
                dex;
                amount = total_to_liquidate;
                max_slippage = parameters.max_slippage;
            };

            // Perform the swap
            let receive_amount = switch (await* (collateral.swap(prepare_swap_args).against(supply))){
                case(#err(err)) {
                    return #err("Failed to perform swap: " # err);
                };
                case(#ok(swap_reply)) {
                    swap_reply.receive_amount;
                };
            };

            var total_raw_repaid : Float = 0.0;

            // TODO: the liquidation penalty could be kept as fees for the protocol instead
            // of being used to repay the borrow

            label iterate_loans for (loan in loans.reset()) {

                let position = switch(Map.get(register.borrow_positions, MapUtils.acchash, loan.account)){
                    case(null) { 
                        Debug.print("No borrow position found for account " # debug_show(loan.account));
                        continue iterate_loans; // No position to liquidate
                    };
                    case(?p) { p };
                };

                let borrow = switch(position.borrow){
                    case(null) { 
                        Debug.trap("Borrow position is null, cannot liquidate"); // TODO: handle this case properly
                    };
                    case(?b) { b; };
                };

                let collateral_to_liquidate = switch(loan.collateral_to_liquidate){
                    case(null) { 
                        Debug.print("No collateral to liquidate for account " # debug_show(loan.account));
                        continue iterate_loans; // No collateral to liquidate
                    };
                    case(?c) { c; };
                };

                let ratio_repaid = Float.fromInt(collateral_to_liquidate) / Float.fromInt(total_to_liquidate);
                let debt_repaid = Float.fromInt(receive_amount) * ratio_repaid / (1.0 + loan.liquidation_penalty);

                let #ok(new_borrow) = Borrow.slash(borrow, { 
                    index; // @todo: maybe index shall be refreshed to the current index
                    accrued_amount = debt_repaid;
                }) else {
                    Debug.trap("Failed to slash borrow: " # debug_show(borrow));
                };

                let new_collateral : Int = position.collateral.amount - collateral_to_liquidate;

                if (new_collateral < 0) {
                    Debug.trap("New collateral amount is negative: " # debug_show(new_collateral));
                };
                
                // Update the position with the new borrow and collateral
                Map.set<Account, BorrowPosition>(register.borrow_positions, MapUtils.acchash, loan.account,
                    { position with borrow = new_borrow; collateral = { amount = Int.abs(new_collateral); }; }
                );

                // Account for the raw repaid amount
                let raw_repaid = switch(new_borrow){
                    case(null) { borrow.raw_amount; };
                    case(?r) { borrow.raw_amount - r.raw_amount; };
                };
                total_raw_repaid += raw_repaid;
            };

            indexer.remove_raw_borrow({ amount = total_raw_repaid });

            // Once positions are liquidated, it might allow the unlock withdrawal of supply
            ignore await* withdrawal_queue.process_pending_withdrawals();

            #ok;
        };

        public func get_loan(account: Account) : ?Loan {

            let index = indexer.get_state().borrow_index;

            switch (Map.get(register.borrow_positions, MapUtils.acchash, account)){
                case(null) { null; };
                case(?position) {
                    borrow_positionner.to_loan({ position; index; });
                };
            };
        };

        public func get_loans() : Map.Iter<Loan> {
            let index = indexer.get_state().borrow_index;
            let filtered_map = Map.mapFilter<Account, BorrowPosition, Loan>(register.borrow_positions, MapUtils.acchash, func (account: Account, position: BorrowPosition) : ?Loan {
                borrow_positionner.to_loan({ position; index; });
            });
            Map.vals(filtered_map);
        };

    };

};