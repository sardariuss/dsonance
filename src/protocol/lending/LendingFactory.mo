import LendingPool "LendingPool";
import LendingTypes "Types";
import BorrowPositionner "BorrowPositionner";
import BorrowRegistry "BorrowRegistry";
import SupplyRegistry "SupplyRegistry";
import InterestRateCurve "InterestRateCurve";
import PayementTypes "../payement/Types";

module {

    type LendingPoolState = LendingTypes.LendingPoolState;
    type LendingPoolRegister = LendingTypes.LendingPoolRegister;
    type Parameters = LendingTypes.Parameters;
    type ILedgerFacade = PayementTypes.ILedgerFacade;

    public func build({
        parameters: Parameters;
        state: LendingPoolState;
        register: LendingPoolRegister;
        supply_ledger: ILedgerFacade;
        collateral_ledger: ILedgerFacade;
        get_collateral_spot_in_asset: ({ time: Nat; }) -> Float;
    }) : LendingPool.LendingPool {

        let borrow_positionner = BorrowPositionner.BorrowPositionner({
            parameters;
            get_collateral_spot_in_asset;
        });

        let supply_registry = SupplyRegistry.SupplyRegistry({
            register;
            ledger = supply_ledger;
        });

        let borrow_registry = BorrowRegistry.BorrowRegistry({
            register;
            supply_ledger;
            collateral_ledger;
            borrow_positionner;
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