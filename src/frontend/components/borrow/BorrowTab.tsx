import { protocolActor } from "../../actors/ProtocolActor";
import { fromNullableExt } from "../../utils/conversions/nullable";
import { TokenLabel } from "../common/TokenLabel";
import BorrowButton, { MaxChoiceType } from "./BorrowButton";
import { OperationKind, Result_1 } from "../../../declarations/protocol/protocol.did";
import { useMemo } from "react";
import { useAuth } from "@ic-reactor/react";
import { Account } from "@/declarations/ck_btc/ck_btc.did";
import DualLabel from "../common/DualLabel";
import { aprToApy } from "../../utils/lending";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";
import { formatAmountCompact } from "../../utils/conversions/token";
import { REPAY_SLIPPAGE_RATIO, UNDEFINED_SCALAR } from "../../constants";
import HealthFactor from "./HealthFactor";

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

  const previewOperation = (amount: bigint, kind: OperationKind) : Promise<Result_1 | undefined> => {
    try {
      return previewBorrowOperation([{ subaccount: [], amount, kind }]);
    } catch (error) {
      console.error("Error previewing borrow operation:", error);
      return Promise.resolve(undefined);
    }
  }

  const runOperation = (amount: bigint, kind: OperationKind) : Promise<Result_1 | undefined> => {

    try {

      console.log("Original args:", { amount, kind });

      const prerequisite = (() => {
        if ("PROVIDE_COLLATERAL" in kind && amount > 0n) {
          // If PROVIDE_COLLATERAL is specified, ensure collateralLedger has enough allowance
          // to cover the amount being provided.
          return collateralLedger.approveIfNeeded(amount);
        } else if ("REPAY_SUPPLY" in kind && amount > 0n) {
          // If REPAY_SUPPLY is specified, ensure supplyLedger has enough allowance
          // to cover the amount being borrowed.
          return supplyLedger.approveIfNeeded(amount + kind.REPAY_SUPPLY.max_slippage_amount);
        } else {
          // Transfer direction is from protocol to user, so nothing here.
          return Promise.resolve({ tokenFee: 0n, approveCalled: false });
        }
      })();

      return prerequisite.then(({tokenFee, approveCalled}) => {
        // Subtract the token fee from the amount if an approval was executed.
        // Second token fee is for the tranfer_from operation that will be executed by the protocol.
        const finalAmount = amount - tokenFee * (approveCalled ? 2n : 1n);
        return runBorrowOperation([{ subaccount: [], kind, amount: finalAmount }]).then((result) => {
          if (result !== undefined && "ok" in result) {
            refreshLoanPosition(); // Refresh the loan position after supply
            refreshIndexerState(); // Refresh the indexer state after supply
            supplyLedger.refreshUserBalance(); // Refresh the supply ledger balance
            collateralLedger.refreshUserBalance(); // Refresh the collateral ledger balance
          }
          return result;
        });
      });
    } catch (error) {
      console.error("Error running borrow operation:", error);
      return Promise.resolve(undefined);
    }
  };

  const { collateral, currentOwed, rawBorrowed, health, netWorth, netApy } = useMemo(() => {

    const collateral = loanPosition?.collateral ?? 0n;

    const loan = fromNullableExt(loanPosition?.loan);
    const rawBorrowed = loan?.raw_borrowed ?? 0n;
    const health = loan?.health;
    const currentOwed = BigInt(Math.ceil(loan?.current_owed ?? 0));
    const ltv = loan?.ltv ?? 0;
    const requiredRepayment = loan?.required_repayment ?? 0;

    const borrowApy = indexerState?.borrow_rate ? aprToApy(indexerState?.borrow_rate) : 0;
    
    var netWorth = 0;
    var netApy = undefined;
    const collateralUsd = collateralLedger.convertToUsd(collateral);
    const borrowedUsd = supplyLedger.convertToUsd(rawBorrowed);
    if (collateralUsd !== undefined && borrowedUsd !== undefined) {
      netWorth = collateralUsd - borrowedUsd;
      if (netWorth !== 0) {
        // @todo: need to add supply APY to netApy
        netApy = -(borrowedUsd * borrowApy) / netWorth;
      }
    }

    return {
      collateral,
      currentOwed,
      rawBorrowed,
      health,
      netWorth,
      netApy
    };
  }, [loanPosition, indexerState]);

  return (
    <div className="flex flex-col justify-center mt-4 space-y-4">
      <div className="flex flex-row items-center p-2 space-x-4">
        <DualLabel top="Net worth" bottom={formatAmountCompact(netWorth, 2)} />
        <DualLabel top="Net APY" bottom={`${netApy === undefined ? UNDEFINED_SCALAR : (netApy * 100).toFixed(2) + "%"}`} />
        <HealthFactor loan_position={loanPosition} />
      </div>
      <div className="flex flex-col justify-center bg-slate-200 dark:bg-gray-800 rounded p-6 space-y-6">
        <div className="flex flex-col justify-center w-full">
          <span className="text-xl font-semibold">Your supply</span>
          <div className="grid grid-cols-[1fr_1fr_1fr_1fr_1fr] items-center gap-6 w-full max-w-5xl mt-4">
            <TokenLabel metadata={supplyLedger.metadata}/>
            <div className="relative flex flex-col">
              <span className="text-lg font-bold"> { supplyLedger.formatAmount(userSupply?.amount) } </span>
              <span className="absolute top-6 text-xs text-gray-400"> { supplyLedger.formatAmountUsd(userSupply?.amount) } </span>
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
              <span className="absolute top-6 text-xs text-gray-400"> { collateralLedger.formatAmountUsd(collateral) } </span>
            </div>
            <span>{/*spacer*/}</span>
            <BorrowButton 
              title="Supply"
              ledger={collateralLedger}
              previewOperation={(amount) => previewOperation(amount, { "PROVIDE_COLLATERAL" : null })}
              runOperation={(amount) => runOperation(amount, { "PROVIDE_COLLATERAL" : null })}
              health={health}
              maxLabel="Wallet balance"
              maxValue={collateralLedger.userBalance ?? 0n }
            />
            <BorrowButton 
              title="Withdraw"
              ledger={collateralLedger}
              previewOperation={(amount) => previewOperation(amount, { "WITHDRAW_COLLATERAL": null })}
              runOperation={(amount) => runOperation(amount, { "WITHDRAW_COLLATERAL": null })}
              health={health}
              maxLabel="Available"
              maxValue={collateral} // @todo: change with available to withdraw, should take into account the LTV
            />
          </div>
        </div>
        <div className="border-b border-gray-300 dark:border-gray-700 w-full"></div>
        <div className="flex flex-col justify-center w-full">
          <span className="text-xl font-semibold">Your borrow</span>
          <div className="grid grid-cols-[1fr_1fr_1fr_1fr_1fr] items-center gap-6 w-full max-w-5xl mt-4">
            <TokenLabel metadata={supplyLedger.metadata}/>
            <div className="relative flex flex-col">
              <span className="text-lg font-bold"> { supplyLedger.formatAmount(currentOwed) } </span>
              <span className="absolute top-6 text-xs text-gray-400"> { supplyLedger.formatAmountUsd(currentOwed) } </span>
            </div>
            <span>{/*spacer*/}</span>
            <BorrowButton 
              title="Borrow"
              ledger={supplyLedger}
              previewOperation={(amount) => previewOperation(amount, { "BORROW_SUPPLY": null })}
              runOperation={(amount) => runOperation(amount, { "BORROW_SUPPLY": null })}
              health={health}
              maxLabel="Available"
              maxValue={supplyLedger.userBalance ?? 0n } // @todo: change with available to borrow, should take into account the LTV
            />
            <BorrowButton 
              title="Repay"
              ledger={supplyLedger}
              previewOperation={(amount) => previewOperation(amount, { "REPAY_SUPPLY": { max_slippage_amount: BigInt(Math.ceil(REPAY_SLIPPAGE_RATIO * Number(amount))) } })}
              runOperation={(amount) => runOperation(amount, { "REPAY_SUPPLY": { max_slippage_amount: BigInt(Math.ceil(REPAY_SLIPPAGE_RATIO * Number(amount))) } })}
              health={health}
              maxLabel="Total owed"
              maxValue={currentOwed}
            />
          </div>
        </div>
      </div>
    </div>
  );
}

export default BorrowTab;