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
import LedgerAccount      "../ledger/LedgerAccount";
import Clock              "../utils/Clock";

module {

    type IndexerState        = LendingTypes.IndexerState;
    type LendingRegister     = LendingTypes.LendingRegister;
    type LendingParameters   = LendingTypes.LendingParameters;
    type ILedgerAccount      = LedgerTypes.ILedgerAccount;
    type IDex                = LedgerTypes.IDex;
    type ISwapReceivable     = LedgerTypes.ISwapReceivable;
    type ISwapPayable        = LedgerTypes.ISwapPayable;
    type ILedgerFungible     = LedgerTypes.ILedgerFungible;

    public func build({
        parameters: LendingParameters;
        state: IndexerState;
        register: LendingRegister;
        admin: Principal;
        protocol: Principal;
        supply_ledger: ILedgerFungible;
        collateral_ledger: ILedgerFungible;
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
            admin;
            ledger_account = LedgerAccount.LedgerAccount({
                protocol_account = { owner = protocol; subaccount = null; };
                ledger = supply_ledger;
            });
            indexer;
        });
        let collateral = LedgerAccount.LedgerAccount({
            protocol_account = { owner = protocol; subaccount = null; };
            ledger = collateral_ledger;
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
            collateral;
            dex;
            parameters;
            borrow_positionner = BorrowPositionner.BorrowPositionner({
                parameters;
                collateral_spot_in_asset = func() : Float {
                    dex.last_price({
                        pay_token = collateral.token_symbol();
                        receive_token = supply.token_symbol();
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