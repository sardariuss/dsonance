import { protocolActor } from "../../actors/ProtocolActor";
import { fromNullableExt } from "../../utils/conversions/nullable";
import { TokenLabel } from "../common/TokenLabel";
import BorrowButton from "./BorrowButton";
import { OperationKind, Result_1 } from "../../../declarations/protocol/protocol.did";
import { useMemo, useEffect } from "react";
import { useAuth } from "@ic-reactor/react";
import { Account } from "@/declarations/ck_btc/ck_btc.did";
import DualLabel from "../common/DualLabel";
import { aprToApy } from "../../utils/lending";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";
import { formatAmountCompact } from "../../utils/conversions/token";
import { REPAY_SLIPPAGE_RATIO, UNDEFINED_SCALAR } from "../../constants";
import HealthFactor from "./HealthFactor";
import { useProtocolContext } from "../context/ProtocolContext";

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

  const { parameters } = useProtocolContext();

  const { call: previewBorrowOperation } = protocolActor.useUpdateCall({
    functionName: 'preview_borrow_operation',
  });

  const { call: runBorrowOperation } = protocolActor.useUpdateCall({
    functionName: 'run_borrow_operation',
  });

  const { data: userSupply, call: refreshUserSupply } = protocolActor.useQueryCall({
    functionName: "get_user_supply",
    args: [{ account }],
  });

  // Refresh APY data when component mounts
  useEffect(() => {
    refreshIndexerState();
    refreshLoanPosition();
    refreshUserSupply();
  }, []);

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

  // Calculate the maximum withdrawable amount based on the collateral and max LTV
  // @todo: ideally this should be done in the backend to be consistent.
  const computeMaxWithdrawableUsd = (
    collateralUsd: number | undefined,
    borrowedUsd: number | undefined,
    maxLtv: number | undefined
  ): number => {
    if (
      collateralUsd === undefined ||
      borrowedUsd === undefined ||
      maxLtv === undefined ||
      maxLtv <= 0
    ) {
      return 0;
    }
    // max withdrawal in USD terms
    const maxWithdrawUsd = Math.max(0, collateralUsd - borrowedUsd / maxLtv);
    return maxWithdrawUsd;
  }

  // Calculate the maximum borrowable amount based on the collateral, borrowed amount, and max LTV
  // @todo: ideally this should be done in the backend to be consistent.
  const computeMaxBorrowableUsd = (
    collateralUsd: number | undefined,
    borrowedUsd: number | undefined,
    maxLtv: number | undefined
  ): number => {
    if (
      collateralUsd === undefined ||
      borrowedUsd === undefined ||
      maxLtv === undefined ||
      maxLtv <= 0
    ) {
      return 0;
    }

    const maxTotalBorrowUsd = collateralUsd * maxLtv;
    const remainingBorrowCapacity = maxTotalBorrowUsd - borrowedUsd;

    return Math.max(0, remainingBorrowCapacity);
  };

  const { collateral, currentOwed, maxWithdrawable, maxBorrowable, netWorth, netApy } = useMemo(() => {

    const collateral = loanPosition?.collateral ?? 0n;
    const loan = fromNullableExt(loanPosition?.loan);
    const currentOwed = BigInt(Math.ceil(loan?.current_owed ?? 0));

    const collateralUsd = collateralLedger.convertToUsd(collateral);
    const borrowedUsd = supplyLedger.convertToUsd(currentOwed);
    const suppliedUsd = supplyLedger.convertToUsd(userSupply?.amount ?? 0n);
    
    const borrowApy = indexerState?.borrow_rate ? aprToApy(indexerState?.borrow_rate) : 0;
    const supplyApy = userSupply?.apr ? aprToApy(userSupply?.apr) : 0;

    let netWorth = 0;
    let netApy = undefined;
    if (collateralUsd !== undefined && borrowedUsd !== undefined && suppliedUsd !== undefined) {
      netWorth = suppliedUsd + collateralUsd - borrowedUsd ;
      if (netWorth !== 0) {
        netApy = (suppliedUsd * supplyApy - borrowedUsd * borrowApy) / netWorth;
      }
    }

    const maxWithdrawableUsd = computeMaxWithdrawableUsd(collateralUsd, borrowedUsd, parameters?.lending.max_ltv);
    const maxWithdrawable = collateralLedger.convertFromUsd(maxWithdrawableUsd) || 0n;

    const maxBorrowableUsd = computeMaxBorrowableUsd(collateralUsd, borrowedUsd, parameters?.lending.max_ltv);
    const maxBorrowable = supplyLedger.convertFromUsd(maxBorrowableUsd) || 0n;

    return {
      collateral,
      currentOwed,
      netWorth,
      netApy,
      maxWithdrawable,
      maxBorrowable,
    };
  }, [loanPosition, indexerState]);

  return (
    <div className="flex flex-col justify-center mt-4 space-y-4">
      <div className="flex flex-row items-center p-2 space-x-4">
        <DualLabel top="Net worth" bottom={formatAmountCompact(netWorth, 2)} />
        <DualLabel top="Net APY" bottom={`${netApy === undefined ? UNDEFINED_SCALAR : (netApy * 100).toFixed(2) + "%"}`} />
        <div className="grid grid-rows-[2fr_3fr] place-items-start">
          <span className="text-gray-500 dark:text-gray-400 text-sm">Health factor</span>
          <HealthFactor loanPosition={loanPosition} />
        </div>
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
              maxLabel="Wallet balance"
              maxAmount={collateralLedger.userBalance ?? 0n }
            />
            <BorrowButton 
              title="Withdraw"
              ledger={collateralLedger}
              previewOperation={(amount) => previewOperation(amount, { "WITHDRAW_COLLATERAL": null })}
              runOperation={(amount) => runOperation(amount, { "WITHDRAW_COLLATERAL": null })}
              maxLabel="Available"
              maxAmount={maxWithdrawable}
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
              maxLabel="Available"
              maxAmount={maxBorrowable}
            />
            <BorrowButton 
              title="Repay"
              ledger={supplyLedger}
              previewOperation={(amount) => previewOperation(amount, { "REPAY_SUPPLY": { max_slippage_amount: BigInt(Math.ceil(REPAY_SLIPPAGE_RATIO * Number(amount))) } })}
              runOperation={(amount) => runOperation(amount, { "REPAY_SUPPLY": { max_slippage_amount: BigInt(Math.ceil(REPAY_SLIPPAGE_RATIO * Number(amount))) } })}
              maxLabel="Total owed"
              maxAmount={currentOwed}
            />
          </div>
        </div>
      </div>
    </div>
  );
}

export default BorrowTab;