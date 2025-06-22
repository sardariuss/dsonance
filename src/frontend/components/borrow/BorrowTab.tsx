import { ckUsdtActor } from "../../actors/CkUsdtActor";
import { protocolActor } from "../../actors/ProtocolActor";
import { ckBtcActor } from "../../actors/CkBtcActor";
import { formatCurrency, fromFixedPoint } from "../../utils/conversions/token";
import { useCurrencyContext } from "../CurrencyContext";
import { fromNullableExt } from "../../utils/conversions/nullable";
import { TokenLabel } from "../common/TokenLabel";
import BorrowButton from "./BorrowButton";
import { Result } from "../../../declarations/protocol/protocol.did";
import { useMemo } from "react";
import { useAuth } from "@ic-reactor/react";
import { Account } from "@/declarations/ck_btc/ck_btc.did";
import { a } from "vitest/dist/chunks/suite.d.FvehnV49";

const BorrowTab = () => {

  const { identity } = useAuth({});

  if (!identity) {
    return null;
  }

  const account : Account= useMemo(() => ({
    owner: identity?.getPrincipal(),
    subaccount: []
  }), [identity]);

  const { satoshisToCurrency } = useCurrencyContext(); // @todo: not gonna work for usdt

  const { data: usdtMetadata } = ckUsdtActor.useQueryCall({
    functionName: 'icrc1_metadata'
  });
  
  const { data: btcMetadata } = ckBtcActor.useQueryCall({
    functionName: 'icrc1_metadata'
  });

  const { data: loanPosition, call: refreshLoanPosition } = protocolActor.useQueryCall({
    functionName: 'get_loan_position',
    args: [account]
  });

  const { call: supply } = protocolActor.useUpdateCall({
    functionName: 'supply_collateral',
  });
  const { call: withdraw } = protocolActor.useUpdateCall({
    functionName: 'withdraw_collateral',
  });
  const { call: borrow } = protocolActor.useUpdateCall({
    functionName: 'borrow',
  });
  const { call: repay } = protocolActor.useUpdateCall({
    functionName: 'repay',
  });

  const supplyFunction = (amount: bigint) : Promise<Result | undefined>=> {
    return supply([{ amount, subaccount: [] }]).then((result) =>{
      if (result !== undefined && "ok" in result) {
        refreshLoanPosition(); // Refresh the loan position after supply
      }
      return result;
    });
  };
  const withdrawFunction = (amount: bigint) : Promise<Result | undefined> => {
    return withdraw([{ amount, subaccount: [] }]).then((result) =>{
      if (result !== undefined && "ok" in result) {
        refreshLoanPosition(); // Refresh the loan position after supply
      }
      return result;
    });
  };
  const borrowFunction = (amount: bigint) : Promise<Result | undefined> => {
    return borrow([{ amount, subaccount: [] }]).then((result) =>{
      if (result !== undefined && "ok" in result) {
        refreshLoanPosition(); // Refresh the loan position after supply
      }
      return result;
    });
  };
  // @todo: Ideally we would like to have a repay function that accepts both full and partial repayments.
  const repayFunction = (amount: bigint) : Promise<Result | undefined> => {
    return repay([{ repayment: { "PARTIAL" : amount }, subaccount: [] }]).then((result) =>{
      if (result !== undefined && "ok" in result) {
        refreshLoanPosition(); // Refresh the loan position after supply
      }
      return result;
    });
  };

  const { collateral, raw_borrowed, current_owed, ltv, health, required_repayment } = useMemo(() => {

    let loan = fromNullableExt(loanPosition?.loan);

    return {
      collateral: loanPosition?.collateral ?? 0n,
      raw_borrowed: loan?.raw_borrowed ?? 0,
      current_owed: loan?.current_owed ?? 0,
      ltv: loan?.ltv ?? 0,
      health: loan?.health ?? 0,
      required_repayment: loan?.required_repayment ?? 0,
    };
  }, [loanPosition]);

  // @todo: if loan data is undefined, use 0 as amountCollateral and amountBorrowed; do not display LTV nor health factor.

  return (
    <div className="flex flex-col justify-center bg-slate-200 dark:bg-gray-800 rounded mt-4 p-6 space-y-6">
      <div className="flex flex-col justify-center w-full">
        <span className="text-xl font-semibold">Your collateral</span>
        <div className="grid grid-cols-[1fr_1fr_1fr_1fr_1fr] items-center gap-6 w-full max-w-5xl mt-4">
          <TokenLabel metadata={usdtMetadata}/>
          <div className="relative flex flex-col">
            <span className="text-lg font-bold"> { formatCurrency(fromFixedPoint(collateral, 6), "")} </span>
            <span className="absolute top-6 text-xs text-gray-400"> { formatCurrency(fromFixedPoint(collateral, 6), "$") } </span>
          </div>
          <span>{/*spacer*/}</span>
          <BorrowButton title="Supply" tokenMetadata={usdtMetadata} onConfirm={supplyFunction} tokenDecimals={6} amountInUsd={amount => fromFixedPoint(amount, 6)}/>
          <BorrowButton title="Withdraw" tokenMetadata={usdtMetadata} onConfirm={withdrawFunction} tokenDecimals={6} amountInUsd={amount => fromFixedPoint(amount, 6)}/>
        </div>
      </div>
      <div className="border-b border-gray-300 dark:border-gray-700 w-full"></div>
      <div className="flex flex-col justify-center w-full">
        <span className="text-xl font-semibold">Your borrow</span>
        <div className="grid grid-cols-[1fr_1fr_1fr_1fr_1fr] items-center gap-6 w-full max-w-5xl mt-4">
          <TokenLabel metadata={btcMetadata}/>
          <div className="relative flex flex-col">
            <span className="text-lg font-bold"> { formatCurrency(fromFixedPoint(raw_borrowed, 8), "")} </span>
            <span className="absolute top-6 text-xs text-gray-400"> { formatCurrency(satoshisToCurrency(raw_borrowed), "$")} </span>
          </div>
          <span>{/*spacer*/}</span>
          <BorrowButton title="Borrow" tokenMetadata={btcMetadata} onConfirm={borrowFunction} tokenDecimals={8} amountInUsd={amount => satoshisToCurrency(amount)}/>
          <BorrowButton title="Repay" tokenMetadata={btcMetadata} onConfirm={repayFunction} tokenDecimals={8} amountInUsd={amount => satoshisToCurrency(amount)}/>
        </div>
      </div>
    </div>
  );
}

export default BorrowTab;