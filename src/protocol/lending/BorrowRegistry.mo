import Nat                "mo:base/Nat";
import Map                "mo:map/Map";
import Result             "mo:base/Result";
import Debug              "mo:base/Debug";
import Float              "mo:base/Float";
import Option             "mo:base/Option";
import Int                "mo:base/Int";
import Principal          "mo:base/Principal";

import Types              "../Types";
import MapUtils           "../utils/Map";
import IterUtils          "../utils/Iter";
import Math               "../utils/Math";
import LedgerTypes        "../ledger/Types";
import Borrow             "./primitives/Borrow";
import Owed               "./primitives/Owed";
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
    
    type BorrowPosition        = LendingTypes.BorrowPosition;
    type Loan                  = LendingTypes.Loan;
    type LoanPosition          = LendingTypes.LoanPosition;
    type LendingIndex          = LendingTypes.LendingIndex;
    type BorrowRegister        = LendingTypes.BorrowRegister;
    type Borrow                = LendingTypes.Borrow;
    type IDex                  = LedgerTypes.IDex;
    type ILedgerAccount        = LedgerTypes.ILedgerAccount;
    type ISwapPayable          = LedgerTypes.ISwapPayable;
    type BorrowParameters      = LendingTypes.BorrowParameters;
    type BorrowPositionTx      = LendingTypes.BorrowPositionTx;
    type BorrowOperation       = LendingTypes.BorrowOperation;
    type BorrowOperationArgs   = LendingTypes.BorrowOperationArgs;
    type Liquidation = {
        raw_borrowed: Float;
        total_collateral: Nat;
    };
    type PreparedOperation = {
        to_transfer: Nat;
        protocol_fees: ?Float;
        finalize: (TxIndex) -> BorrowOperation;
    };

    // @todo: function to delete positions repaid that are too old
    // @todo: check reentry risks on borrow, repay, supply_collateral, withdraw_collateral!
    // @todo: check if OK to update of index before/after transfer
    public class BorrowRegistry({
        register: BorrowRegister;
        supply: SupplyAccount.SupplyAccount;
        collateral: ILedgerAccount and ISwapPayable;
        borrow_positionner: BorrowPositionner.BorrowPositionner;
        indexer: Indexer.Indexer;
        withdrawal_queue: WithdrawalQueue.WithdrawalQueue;
        parameters: BorrowParameters;
        dex: IDex;
    }){

        public func get_position({ account: Account; }) : ?BorrowPosition {
            Map.get(register.borrow_positions, MapUtils.acchash, account);
        };

        public func get_positions() : Map.Iter<BorrowPosition> {
            Map.vals(register.borrow_positions);
        };

        public func run_operation(time: Nat, args: BorrowOperationArgs) : async* Result<BorrowOperation, Text> {

            let { account; } = args;

            if (Principal.isAnonymous(account.owner)) {
                return #err("Anonymous account cannot perform borrow operations");
            };

            let { to_transfer; protocol_fees; finalize; } = switch(prepare_operation(time, args)){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };

            let transfer = switch(args.kind){
                case(#PROVIDE_COLLATERAL (_)) {  await* collateral.pull    ({ from = account; amount = to_transfer; }); };
                case(#WITHDRAW_COLLATERAL(_)) { (await* collateral.transfer({ to = account;   amount = to_transfer; })).result;        };
                case(#BORROW_SUPPLY      (_)) {  await* supply.transfer    ({ to = account;   amount = to_transfer; });                };
                case(#REPAY_SUPPLY       (_)) {  await* supply.pull        ({ from = account; amount = to_transfer; protocol_fees; }); };
            };

            let tx = switch(transfer){
                case(#err(err)) { return #err("Failed to perform transfer: " # debug_show(err)); };
                case(#ok(tx_index)) { tx_index; };
            };

            let to_return = finalize(tx);

            switch(args.kind){
                case(#REPAY_SUPPLY(_)) {
                    // Once a position is repaid, it might allow to process pending withdrawal of supply
                    ignore await* withdrawal_queue.process_pending_withdrawals(time);
                };
                case(_) {}; // No need to process pending withdrawals for other operations
            };

            #ok(to_return);
        };

        public func run_operation_for_free(time: Nat, args: BorrowOperationArgs) : Result<BorrowOperation, Text> {

            let { finalize; } = switch(prepare_operation(time, args)){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };

            // Intentionnally not calling withdrawal_queue.process_pending_withdrawals()
            // as this is a free operation and the intention is to not modify the state

            #ok(finalize(0)); // TxIndex is arbitrarily set to 0 for preview
        };

        /// Liquidate borrow positions if their health factor is below 1.0.
        public func check_all_positions_and_liquidate(time: Nat) : async* Result<(), Text> {

            // @index_todo: need current index
            let index = indexer.get_index(time).borrow_index;
            let loans = get_loans(time);

            let total_to_liquidate = IterUtils.fold_left(Map.vals(loans), 0, func (sum: Nat, loan: Loan): Nat {
                sum + Option.get(loan.collateral_to_liquidate, 0);
            });

            if (total_to_liquidate == 0) {
                return #ok; // Nothing to liquidate
            };

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

            label iterate_loans for ((account, loan) in Map.entries(loans)) {

                let position = switch(Map.get(register.borrow_positions, MapUtils.acchash, account)){
                    case(null) { 
                        Debug.print("No borrow position found for account " # debug_show(account));
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
                        Debug.print("No collateral to liquidate for account " # debug_show(account));
                        continue iterate_loans; // No collateral to liquidate
                    };
                    case(?c) { c; };
                };

                let ratio_repaid = Float.fromInt(collateral_to_liquidate) / Float.fromInt(total_to_liquidate);
                let debt_repaid = Float.fromInt(receive_amount) * ratio_repaid / (1.0 + loan.liquidation_penalty);

                // @todo: maybe index shall be refreshed to the current index
                let #ok(new_borrow) = Borrow.slash(borrow, debt_repaid, index) else { 
                    Debug.trap("Failed to slash borrow: " # debug_show(borrow));
                };

                let new_collateral : Int = position.collateral.amount - collateral_to_liquidate;

                if (new_collateral < 0) {
                    Debug.trap("New collateral amount is negative: " # debug_show(new_collateral));
                };
                
                // Update the position with the new borrow and collateral
                Map.set<Account, BorrowPosition>(register.borrow_positions, MapUtils.acchash, account,
                    { position with borrow = new_borrow; collateral = { amount = Int.abs(new_collateral); }; }
                );

                // Account for the raw repaid amount
                let raw_repaid = switch(new_borrow){
                    case(null) { borrow.raw_amount; };
                    case(?r) { borrow.raw_amount - r.raw_amount; };
                };
                total_raw_repaid += raw_repaid;
            };

            // TODO: check how much interests to remove from the index?
            indexer.remove_raw_borrow({ amount = total_raw_repaid; time; });

            // Once positions are liquidated, it might allow the unlock withdrawal of supply
            ignore await* withdrawal_queue.process_pending_withdrawals(time);

            #ok;
        };

        public func get_loan_position(time: Nat, account: Account) : LoanPosition {

            let index = indexer.get_index(time).borrow_index;

            switch (Map.get(register.borrow_positions, MapUtils.acchash, account)){
                case(null) { 
                    {
                        account;
                        collateral = 0;
                        loan = null;
                    };
                };
                case(?position) {
                    borrow_positionner.to_loan_position({ position; index; });
                };
            };
        };

        public func get_loans_info(time: Nat) : { positions: [Loan]; max_ltv: Float } {

            let index = indexer.get_index(time).borrow_index;

            var max_ltv : Float = 0.0;
            let positions : [Loan] = Map.toArrayMap<Account, BorrowPosition, Loan>(register.borrow_positions, func (account: Account, position: BorrowPosition) : ?Loan {
                borrow_positionner.to_loan_position({ position; index; }).loan;
            });

            {
                positions;
                max_ltv;
            };
        };

        func get_loans(time: Nat) : Map.Map<Account, Loan> {

            let index = indexer.get_index(time).borrow_index;

            Map.mapFilter<Account, BorrowPosition, Loan>(register.borrow_positions, MapUtils.acchash, func (account: Account, position: BorrowPosition) : ?Loan {
                borrow_positionner.to_loan_position({ position; index; }).loan;
            });
        };

        func prepare_operation(time: Nat, args: BorrowOperationArgs) : Result<PreparedOperation, Text> {

            let { amount; account; } = args;
            switch(args.kind){
                case(#PROVIDE_COLLATERAL                 ) { prepare_supply_collateral   ({ time; amount; account;                      }) };
                case(#WITHDRAW_COLLATERAL                ) { prepare_withdraw_collateral ({ time; amount; account;                      }) };
                case(#BORROW_SUPPLY                      ) { prepare_borrow              ({ time; amount; account;                      }) };
                case(#REPAY_SUPPLY({max_slippage_amount})) { prepare_repay               ({ time; amount; account; max_slippage_amount; }) };
            };
        };

        func common_finalize({
            account: Account;
            position: BorrowPosition; 
            tx: BorrowPositionTx;
            time: Nat;
        }) : BorrowOperation {
            // Add the transaction to the position
            let update = BorrowPositionner.add_tx({ position; tx; });
            Map.set(register.borrow_positions, MapUtils.acchash, account, update);
            let index = indexer.get_index(time);
            {
                position = borrow_positionner.to_loan_position({ position = update; index = index.borrow_index; });
                index;
            };
        };

        func prepare_supply_collateral({
            account: Account;
            amount: Nat;
            time: Nat;
        }) : Result<PreparedOperation, Text> {

            let position = Map.get(register.borrow_positions, MapUtils.acchash, account);
            let update = borrow_positionner.provide_collateral({ position; account; amount; });

            let finalize = func(tx: TxIndex) : BorrowOperation {
                common_finalize({
                    account;
                    position = update;
                    tx = #COLLATERAL_PROVIDED(tx);
                    time;
                });
            };

            #ok({ to_transfer = amount; protocol_fees = null; finalize; });
        };

        func prepare_withdraw_collateral({
            account: Account;
            amount: Nat;
            time: Nat;
        }) : Result<PreparedOperation, Text> {

            let position = switch(Map.get(register.borrow_positions, MapUtils.acchash, account)){
                case(null) { return #err("No position found for account " # debug_show(account)); };
                case(?p) { p; };
            };

            let index = indexer.get_index(time).borrow_index;

            // Remove the collateral from the borrow position
            let update = switch(borrow_positionner.withdraw_collateral({ position; amount; index; })){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };

            let finalize = func(tx: TxIndex) : BorrowOperation {
                common_finalize({
                    account;
                    position = update;
                    tx = #COLLATERAL_WITHDRAWNED(tx);
                    time;
                });
            };

            #ok({ to_transfer = amount; protocol_fees = null; finalize; });
        };

        func prepare_borrow({
            account: Account;
            amount: Nat;
            time: Nat;
        }) : Result<PreparedOperation, Text> {

            let index = indexer.get_index(time);

            // @todo: should add to a map of <Account, Nat> the amount concurrent borrows that could 
            // increase the utilization ratio more than 1.

            // Check mathematical constraints and get new utilization
            let utilization = switch(UtilizationUpdater.add_raw_borrow(index.utilization, amount)){
                case(#err(err)) { return #err("Mathematical constraint violated: " # err); };
                case(#ok(u)) { u; };
            };
            
            // Apply business policy constraints
            let available_to_borrow = utilization.raw_supplied * (1.0 - parameters.reserve_liquidity);
            if (utilization.raw_borrowed > available_to_borrow) {
                return #err("Insufficient liquidity due to reserve policy - available: " # debug_show(available_to_borrow) # ", requested: " # debug_show(utilization.raw_borrowed));
            };
            
            if (utilization.raw_borrowed > Float.fromInt(parameters.borrow_cap)){
                return #err("Borrow cap of " # debug_show(parameters.borrow_cap) # " exceeded with current utilization " # debug_show(utilization));
            };

            let position = switch(Map.get(register.borrow_positions, MapUtils.acchash, account)){
                case(null) { return #err("No borrow position found for account " # debug_show(account)); };
                case(?p) { p; };
            };

            let update = switch(borrow_positionner.borrow_supply({ position; index = index.borrow_index; amount; })){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };

            let finalize = func(tx: TxIndex) : BorrowOperation {
                indexer.add_raw_borrow({ amount; time; }); // TODO: can trap after transfer, not safe!
                common_finalize({
                    account;
                    position = update;
                    tx = #SUPPLY_BORROWED(tx);
                    time;
                });
            };

            #ok({ to_transfer = amount; protocol_fees = null; finalize; });
        };

        func prepare_repay({
            account: Account;
            amount: Nat;
            max_slippage_amount: Nat;
            time: Nat;
        }) : Result<PreparedOperation, Text> {

            let position = switch(Map.get(register.borrow_positions, MapUtils.acchash, account)){
                case(null) { return #err("No position found for account " # debug_show(account)); };
                case(?p) { p; };
            };

            let index = indexer.get_index(time).borrow_index;

            let repay_result = borrow_positionner.repay_supply({ position; index; amount; max_slippage_amount; });
            let { repaid; raw_repaid; remaining; from_interests; } = switch(repay_result){
                case(#err(err)) { return #err(err); };
                case(#ok(p)) { p; };
            };

            // Follow a "round-up for debt, round-down for rewards" policy
            let repaid_nat = Int.abs(Math.ceil_to_int(repaid));
            let ceil_diff = Float.ceil(repaid) - repaid;

            // Consider the rounding difference as protocol fees
            let protocol_fees = ?(indexer.get_parameters().lending_fee_ratio * from_interests + ceil_diff);

            let update = { position with borrow = remaining; };

            let finalize = func(tx: TxIndex) : BorrowOperation {
                indexer.remove_raw_borrow({ amount = raw_repaid; time; });
                indexer.take_borrow_interests({ amount = from_interests; time; });
                common_finalize({
                    account;
                    position = update;
                    tx = #SUPPLY_REPAID(tx);
                    time;
                });
            };

            #ok({ to_transfer = repaid_nat; protocol_fees; finalize; });
        };

    };

};