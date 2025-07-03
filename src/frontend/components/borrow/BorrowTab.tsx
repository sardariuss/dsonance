import { protocolActor } from "../../actors/ProtocolActor";
import { formatAmountUsd } from "../../utils/conversions/token";
import { fromNullableExt } from "../../utils/conversions/nullable";
import { TokenLabel } from "../common/TokenLabel";
import BorrowButton, { MaxChoiceType } from "./BorrowButton";
import { OperationKindArgs, Result_1 } from "../../../declarations/protocol/protocol.did";
import { useMemo } from "react";
import { useAuth } from "@ic-reactor/react";
import { Account } from "@/declarations/ck_btc/ck_btc.did";
import DualLabel from "../common/DualLabel";
import { aprToApy, getHealthColor } from "../../utils/lending";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";

const BorrowTab = () => {

  const { identity } = useAuth({});

  if (!identity) {
    return null;
  }

  const account : Account= useMemo(() => ({
    owner: identity?.getPrincipal(),
    subaccount: []
  }), [identity]);

  const { supplyLedger, collateralLedger } = useFungibleLedgerContext();

  const { data: indexerState, call: refreshIndexerState } = protocolActor.useQueryCall({
    functionName: 'get_lending_index',
  });

  const { data: loanPosition, call: refreshLoanPosition } = protocolActor.useQueryCall({
    functionName: 'get_loan_position',
    args: [account]
  });

  const { call: previewBorrowOperation } = protocolActor.useUpdateCall({
    functionName: 'preview_borrow_operation',
  });

  const { call: runBorrowOperation } = protocolActor.useUpdateCall({
    functionName: 'run_borrow_operation',
  });

  const { data: userSupply } = protocolActor.useQueryCall({
    functionName: "get_user_supply",
    args: [{ account }],
  });

  const previewOperation = (args: OperationKindArgs) : Promise<Result_1 | undefined> => {
    return previewBorrowOperation([{ subaccount: [], args }]);
  }

  const runOperation = (args: OperationKindArgs) : Promise<Result_1 | undefined> => {

    let prerequisite : Promise<boolean> = Promise.resolve(true);

    if ("PROVIDE_COLLATERAL" in args && args.PROVIDE_COLLATERAL.amount > 0n) {
      prerequisite = collateralLedger.approveIfNeeded(args.PROVIDE_COLLATERAL.amount);
    } else if ("BORROW_SUPPLY" in args && args.BORROW_SUPPLY.amount > 0n) {
      prerequisite = supplyLedger.approveIfNeeded(args.BORROW_SUPPLY.amount);
    }

    return prerequisite.then((approved) => {
      if (!approved) {
        return undefined; // If approval failed, do not proceed with the operation
      }
      return runBorrowOperation([{ subaccount: [], args }]).then((result) => {
        if (result !== undefined && "ok" in result) {
          refreshLoanPosition(); // Refresh the loan position after supply
          refreshIndexerState(); // Refresh the indexer state after supply
        }
        return result;
      });
    });
  };

  const { collateral, rawBorrowed, health, netWorth, netApy } = useMemo(() => {

    const collateral = loanPosition?.collateral ?? 0n;

    const loan = fromNullableExt(loanPosition?.loan);
    const rawBorrowed = loan?.raw_borrowed ?? 0n;
    const health = loan?.health ?? 0;
    const currentOwed = loan?.current_owed ?? 0;
    const ltv = loan?.ltv ?? 0;
    const requiredRepayment = loan?.required_repayment ?? 0;

    const borrowApy = indexerState?.borrow_rate ? aprToApy(indexerState?.borrow_rate) : 0;
    
    var netWorth = 0;
    var netApy = 0;
    const collateralUsd = collateralLedger.convertToUsd(collateral);
    const borrowedUsd = supplyLedger.convertToUsd(rawBorrowed);
    if (collateralUsd !== undefined && borrowedUsd !== undefined) {
      netWorth = collateralUsd - borrowedUsd;
      netApy = -(borrowedUsd * borrowApy) / netWorth;
    }

    return {
      collateral,
      rawBorrowed,
      health,
      netWorth,
      netApy
    };
  }, [loanPosition, indexerState]);

  // @todo: need to add "remaining collateral" for withdraw
  // @todo: need to add "remaning debt" for repay
  // @todo: if loan data is undefined, use 0 as amountCollateral and amountBorrowed; do not display LTV nor health factor.

  return (
    <div className="flex flex-col justify-center mt-4 space-y-4">
      <div className="flex flex-row items-center p-2 space-x-4">
        <DualLabel top="Net worth" bottom={formatAmountUsd(netWorth)} />
        <DualLabel top="Net APY" bottom={`${(netApy * 100).toFixed(2)}%`} />
        <div className="grid grid-rows-[2fr_3fr] place-items-start">
          <span className="text-gray-500 dark:text-gray-400 text-sm">Health factor</span>
          <span className={`${getHealthColor(health)}`}>{health.toFixed(2)}</span>
        </div>
      </div>
      <div className="flex flex-col justify-center bg-slate-200 dark:bg-gray-800 rounded p-6 space-y-6">
        <div className="flex flex-col justify-center w-full">
          <span className="text-xl font-semibold">Your supply</span>
          <div className="grid grid-cols-[1fr_1fr_1fr_1fr_1fr] items-center gap-6 w-full max-w-5xl mt-4">
            <TokenLabel metadata={supplyLedger.metadata}/>
            <div className="relative flex flex-col">
              <span className="text-lg font-bold"> { supplyLedger.formatAmount(userSupply?.amount) } </span>
              <span className="absolute top-6 text-xs text-gray-400"> { formatAmountUsd(supplyLedger.convertToUsd(userSupply?.amount)) } </span>
            </div>
          </div>
        </div>
      </div>
      <div className="flex flex-col justify-center bg-slate-200 dark:bg-gray-800 rounded p-6 space-y-6">
        <div className="flex flex-col justify-center w-full">
          <span className="text-xl font-semibold">Your collateral</span>
          <div className="grid grid-cols-[1fr_1fr_1fr_1fr_1fr] items-center gap-6 w-full max-w-5xl mt-4">
            <TokenLabel metadata={collateralLedger.metadata}/>
            <div className="relative flex flex-col">
              <span className="text-lg font-bold"> { collateralLedger.formatAmount(collateral) } </span>
              <span className="absolute top-6 text-xs text-gray-400"> { formatAmountUsd(collateralLedger.convertToUsd(collateral)) } </span>
            </div>
            <span>{/*spacer*/}</span>
            <BorrowButton 
              title="Supply"
              ledger={collateralLedger}
              previewOperation={(amount) => previewOperation({ "PROVIDE_COLLATERAL": { amount } })}
              runOperation={(amount) => runOperation({ "PROVIDE_COLLATERAL": { amount } })}
              health={health}
              maxChoice={{type: MaxChoiceType.WalletBalance, value: collateralLedger.userBalance ?? 0n }}
            />
            <BorrowButton 
              title="Withdraw"
              ledger={collateralLedger}
              previewOperation={(amount) => previewOperation({ "WITHDRAW_COLLATERAL": { amount } })}
              runOperation={(amount) => runOperation({ "WITHDRAW_COLLATERAL": { amount } })}
              health={health}
              maxChoice={{type: MaxChoiceType.Available, value: collateralLedger.userBalance ?? 0n }} /* @todo: change with available to withdraw */
            />
          </div>
        </div>
        <div className="border-b border-gray-300 dark:border-gray-700 w-full"></div>
        <div className="flex flex-col justify-center w-full">
          <span className="text-xl font-semibold">Your borrow</span>
          <div className="grid grid-cols-[1fr_1fr_1fr_1fr_1fr] items-center gap-6 w-full max-w-5xl mt-4">
            <TokenLabel metadata={supplyLedger.metadata}/>
            <div className="relative flex flex-col">
              <span className="text-lg font-bold"> { supplyLedger.formatAmount(rawBorrowed)} </span>
              <span className="absolute top-6 text-xs text-gray-400"> { formatAmountUsd(supplyLedger.convertToUsd(rawBorrowed)) } </span>
            </div>
            <span>{/*spacer*/}</span>
            <BorrowButton 
              title="Borrow"
              ledger={supplyLedger}
              previewOperation={(amount) => previewOperation({ "BORROW_SUPPLY": { amount } })}
              runOperation={(amount) => runOperation({ "BORROW_SUPPLY": { amount } })}
              health={health}
              maxChoice={{type: MaxChoiceType.Available, value: supplyLedger.userBalance ?? 0n }} /* @todo: change with available to borrow */
            />
            <BorrowButton 
              title="Repay"
              ledger={supplyLedger}
              previewOperation={(amount) => previewOperation({ "REPAY_SUPPLY": { repayment: { "PARTIAL" : amount } } })}
              runOperation={(amount) => runOperation({ "REPAY_SUPPLY": { repayment: { "PARTIAL" : amount } } })}
              health={health}
              maxChoice={{type: MaxChoiceType.WalletBalance, value: supplyLedger.userBalance ?? 0n }}
            />
          </div>
        </div>
      </div>
    </div>
  );
}

export default BorrowTab;