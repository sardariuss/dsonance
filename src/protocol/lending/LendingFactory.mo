import LendingTypes       "Types";
import BorrowPositionner  "BorrowPositionner";
import BorrowRegistry     "BorrowRegistry";
import SupplyRegistry     "SupplyRegistry";
import InterestRateCurve  "InterestRateCurve";
import WithdrawalQueue    "WithdrawalQueue";
import Indexer            "Indexer";
import UtilizationUpdater "UtilizationUpdater";
import SupplyAccount      "SupplyAccount";
import LedgerTypes        "../ledger/Types";
import Clock              "../utils/Clock";

module {

    type IndexerState        = LendingTypes.IndexerState;
    type LendingPoolRegister = LendingTypes.LendingPoolRegister;
    type Parameters          = LendingTypes.Parameters;
    type ILedgerAccount      = LedgerTypes.ILedgerAccount;
    type IDex                = LedgerTypes.IDex;
    type ISwapReceivable     = LedgerTypes.ISwapReceivable;
    type ISwapPayable        = LedgerTypes.ISwapPayable;

    public func build({
        protocol_owner: Principal;
        parameters: Parameters;
        state: IndexerState;
        register: LendingPoolRegister;
        supply_account: ILedgerAccount and ISwapReceivable;
        collateral_account: ILedgerAccount and ISwapPayable;
        dex: IDex;
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

        let supply = SupplyAccount.SupplyAccount({
            protocol_owner;
            ledger_account = supply_account;
            indexer;
        });

        let withdrawal_queue = WithdrawalQueue.WithdrawalQueue({
            indexer;
            register;
            supply;
        });

        let supply_registry = SupplyRegistry.SupplyRegistry({
            indexer;
            register;
            withdrawal_queue;
            supply;
        });

        let borrow_registry = BorrowRegistry.BorrowRegistry({
            indexer;
            register;
            utilization_updater;
            withdrawal_queue;
            supply;
            collateral_account;
            dex;
            parameters;
            borrow_positionner = BorrowPositionner.BorrowPositionner({
                parameters;
                collateral_spot_in_asset = func() : Float {
                    dex.last_price({
                        pay_token = collateral_account.token_symbol();
                        receive_token = supply_account.token_symbol();
                    });
                };
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