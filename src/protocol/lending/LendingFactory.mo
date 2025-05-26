import LendingTypes "Types";
import BorrowPositionner "BorrowPositionner";
import BorrowRegistry "BorrowRegistry";
import SupplyRegistry "SupplyRegistry";
import InterestRateCurve "InterestRateCurve";
import WithdrawalQueue "WithdrawalQueue";
import Indexer "Indexer";
import UtilizationUpdater "UtilizationUpdater";
import PayementTypes "../payement/Types";
import Clock "../utils/Clock";

module {

    type IndexerState = LendingTypes.IndexerState;
    type LendingPoolRegister = LendingTypes.LendingPoolRegister;
    type Parameters = LendingTypes.Parameters;
    type ILiquidityPool = LendingTypes.ILiquidityPool;
    type ILedgerFacade = PayementTypes.ILedgerFacade;

    public func build({
        parameters: Parameters;
        state: IndexerState;
        register: LendingPoolRegister;
        supply_ledger: ILedgerFacade;
        collateral_ledger: ILedgerFacade;
        liquidity_pool: ILiquidityPool;
        clock: Clock.IClock;
    }) : {
        indexer: Indexer.Indexer;
        supply_registry: SupplyRegistry.SupplyRegistry;
        borrow_registry: BorrowRegistry.BorrowRegistry;
        withdrawal_queue: WithdrawalQueue.WithdrawalQueue;
    } {

        let utilization_updater = UtilizationUpdater.UtilizationUpdater({
            parameters;
        });

        let indexer = Indexer.Indexer({
            clock;
            parameters;
            state;
            utilization_updater;
            interest_rate_curve = InterestRateCurve.InterestRateCurve(
                parameters.interest_rate_curve
            );
        });

        let withdrawal_queue = WithdrawalQueue.WithdrawalQueue({
            indexer;
            register;
            ledger = supply_ledger;
        });

        let supply_registry = SupplyRegistry.SupplyRegistry({
            indexer;
            register;
            withdrawal_queue;
            ledger = supply_ledger;
        });

        let borrow_registry = BorrowRegistry.BorrowRegistry({
            indexer;
            register;
            utilization_updater;
            supply_withdrawals = withdrawal_queue;
            supply_ledger;
            collateral_ledger;
            liquidity_pool;
            borrow_positionner = BorrowPositionner.BorrowPositionner({
                parameters;
                liquidity_pool;
            });
        });

        {
            indexer;
            supply_registry;
            borrow_registry;
            withdrawal_queue;
        };
    };

};