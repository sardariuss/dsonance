import LendingPool "LendingPool";
import LendingTypes "Types";
import BorrowPositionner "BorrowPositionner";
import BorrowRegistry "BorrowRegistry";
import SupplyRegistry "SupplyRegistry";
import InterestRateCurve "InterestRateCurve";

import LedgerFacade "../payement/LedgerFacade";

module {

    type LendingPoolState = LendingTypes.LendingPoolState;
    type BorrowRegister = LendingTypes.BorrowRegister;
    type SupplyRegister = LendingTypes.SupplyRegister;
    type Parameters = LendingTypes.Parameters;

    public func build({
        parameters: Parameters;
        state: LendingPoolState;
        borrow_register: BorrowRegister;
        supply_register: SupplyRegister;
        supply_ledger: LedgerFacade.LedgerFacade;
        collateral_ledger: LedgerFacade.LedgerFacade;
    }) : LendingPool.LendingPool {

        // @todo: fix
        let get_collateral_spot_in_asset = func({ time: Nat; }) : Float { 0.0; };
        let add_to_supply_balance = func(_ : Int) : () {};

        let borrow_positionner = BorrowPositionner.BorrowPositionner({
            parameters;
            get_collateral_spot_in_asset;
        });

        let supply_registry = SupplyRegistry.SupplyRegistry({
            register = supply_register;
            ledger = supply_ledger;
            add_to_supply_balance;
        });

        let borrow_registry = BorrowRegistry.BorrowRegistry({
            register = borrow_register;
            supply_ledger;
            collateral_ledger;
            borrow_positionner;
            add_to_supply_balance;
        });
        
        let interest_rate_curve = InterestRateCurve.InterestRateCurve(
            parameters.interest_rate_curve
        );

        LendingPool.LendingPool({
            parameters;
            state;
            borrow_registry;
            supply_registry;
            interest_rate_curve;
        });
    };

};