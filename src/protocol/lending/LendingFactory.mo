import LendingTypes                  "Types";
import BorrowPositionner             "BorrowPositionner";
import BorrowRegistry                "BorrowRegistry";
import SupplyRegistry                "SupplyRegistry";
import RedistributionHub             "RedistributionHub";
import InterestRateCurve             "InterestRateCurve";
import WithdrawalQueue               "WithdrawalQueue";
import Indexer                       "Indexer";
import SupplyAccount                 "SupplyAccount";
import SupplyPositionManager         "SupplyPositionManager";
import RedistributionPositionManager "RedistributionPositionManager";
import LedgerTypes                   "../ledger/Types";
import LedgerAccount                 "../ledger/LedgerAccount";
import Timeline                      "../utils/Timeline";

import Result             "mo:base/Result";

module {

    type LendingIndex        = LendingTypes.LendingIndex;
    type LendingRegister     = LendingTypes.LendingRegister;
    type LendingParameters   = LendingTypes.LendingParameters;
    type ILedgerAccount      = LedgerTypes.ILedgerAccount;
    type IDex                = LedgerTypes.IDex;
    type ISwapReceivable     = LedgerTypes.ISwapReceivable;
    type ISwapPayable        = LedgerTypes.ISwapPayable;
    type ILedgerFungible     = LedgerTypes.ILedgerFungible;
    type ProtocolInfo        = LedgerTypes.ProtocolInfo;
    type IPriceTracker       = LedgerTypes.IPriceTracker;
    type Result<Ok, Err>     = Result.Result<Ok, Err>;

    public func build({
        parameters: LendingParameters;
        index: Timeline.Timeline<LendingIndex>;
        register: LendingRegister;
        admin: Principal;
        protocol_info: ProtocolInfo;
        supply_ledger: ILedgerFungible;
        collateral_ledger: ILedgerFungible;
        dex: IDex;
        collateral_price_tracker: IPriceTracker;
    }) : {
        indexer: Indexer.Indexer;
        supply: SupplyAccount.SupplyAccount;
        supply_registry: SupplyRegistry.SupplyRegistry;
        redistribution_hub: RedistributionHub.RedistributionHub;
        borrow_registry: BorrowRegistry.BorrowRegistry;
        withdrawal_queue: WithdrawalQueue.WithdrawalQueue;
    } {

        let indexer = Indexer.Indexer({
            parameters;
            index;
            interest_rate_curve = InterestRateCurve.InterestRateCurve(
                parameters.interest_rate_curve
            );
        });

        let supply = SupplyAccount.SupplyAccount({
            admin;
            ledger_account = LedgerAccount.LedgerAccount({
                protocol_account = {
                    owner = protocol_info.principal;
                    subaccount = protocol_info.supply.subaccount;
                };
                ledger = supply_ledger;
            });
            fees_account = {
                owner = protocol_info.principal;
                subaccount = ?protocol_info.supply.fees_subaccount;
            };
            unclaimed_fees = protocol_info.supply.unclaimed_fees;
        });
        let collateral = LedgerAccount.LedgerAccount({
            protocol_account = {
                owner = protocol_info.principal;
                subaccount = protocol_info.collateral.subaccount;
            };
            ledger = collateral_ledger;
        });

        let withdrawal_queue = WithdrawalQueue.WithdrawalQueue({
            indexer;
            register;
            supply;
        });

        // Create position managers first
        let supply_position_manager = SupplyPositionManager.SupplyPositionManager({
            register;
            indexer;
        });

        let redistribution_position_manager = RedistributionPositionManager.RedistributionPositionManager({
            register;
            indexer;
        });

        // Then inject them into registries/hubs
        let supply_registry = SupplyRegistry.SupplyRegistry({
            supply;
            indexer;
            withdrawal_queue;
            parameters;
            position_manager = supply_position_manager;
        });

        let redistribution_hub = RedistributionHub.RedistributionHub({
            indexer;
            supply;
            parameters;
            supply_position_manager;
            position_manager = redistribution_position_manager;
        });

        let borrow_registry = BorrowRegistry.BorrowRegistry({
            indexer;
            register;
            withdrawal_queue;
            supply;
            collateral;
            dex;
            parameters;
            borrow_positionner = BorrowPositionner.BorrowPositionner({
                parameters;
                collateral_price_tracker;
            });
        });

        {
            indexer;
            supply;
            supply_registry;
            redistribution_hub;
            borrow_registry;
            withdrawal_queue;
        };
    };

};