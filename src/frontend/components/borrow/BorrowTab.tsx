import { ckUsdtActor } from "../../actors/CkUsdtActor";
import { protocolActor } from "../../actors/ProtocolActor";
import { ckBtcActor } from "../../actors/CkBtcActor";
import { formatCurrency, fromFixedPoint } from "../../utils/conversions/token";
import { useCurrencyContext } from "../CurrencyContext";
import { fromNullableExt } from "../../utils/conversions/nullable";
import { TokenLabel } from "../common/TokenLabel";
import BorrowButton, { MaxChoiceType } from "./BorrowButton";
import { OperationKindArgs, Result_1 } from "../../../declarations/protocol/protocol.did";
import { useMemo } from "react";
import { useAuth } from "@ic-reactor/react";
import { Account } from "@/declarations/ck_btc/ck_btc.did";
import DualLabel from "../common/DualLabel";
import { aprToApy, getHealthColor } from "../../utils/lending";
import { useAllowanceContext } from "../AllowanceContext";

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

  const { data: lockedAmount, call: refreshLockedAmount } = protocolActor.useQueryCall({
    functionName: "get_locked_amount",
    args: [{ account }],
  });

  const { btcAllowance, usdtAllowance } = useAllowanceContext();

  const previewOperation = (args: OperationKindArgs) : Promise<Result_1 | undefined> => {
    return previewBorrowOperation([{ subaccount: [], args }]);
  }

  const runOperation = (args: OperationKindArgs) : Promise<Result_1 | undefined>=> {
    return runBorrowOperation([{ subaccount: [], args }]).then((result) => {
      if (result !== undefined && "ok" in result) {
        refreshLoanPosition(); // Refresh the loan position after supply
        refreshIndexerState(); // Refresh the indexer state after supply
      }
      return result;
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
    
    const netWorth = fromFixedPoint(collateral, 6) - satoshisToCurrency(rawBorrowed);

    const borrowApy = indexerState?.borrow_rate ? aprToApy(indexerState?.borrow_rate) : 0;
    const netApy = -(satoshisToCurrency(rawBorrowed) * borrowApy) / netWorth;

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
        <DualLabel top="Net worth" bottom={formatCurrency(netWorth, "$")} />
        <DualLabel top="Net APY" bottom={`${(netApy * 100).toFixed(2)}%`} />
        <DualLabel top="Health factor" bottom={health.toFixed(2)} bottomClassName={`${getHealthColor(health)}`}/>
      </div>
      <div className="flex flex-col justify-center bg-slate-200 dark:bg-gray-800 rounded p-6 space-y-6">
        <div className="flex flex-col justify-center w-full">
          <span className="text-xl font-semibold">Your supply</span>
          <div className="grid grid-cols-[1fr_1fr_1fr_1fr_1fr] items-center gap-6 w-full max-w-5xl mt-4">
            <TokenLabel metadata={btcMetadata}/>
            <div className="relative flex flex-col">
              <span className="text-lg font-bold"> { formatCurrency(fromFixedPoint(lockedAmount, 8), "")} </span>
              <span className="absolute top-6 text-xs text-gray-400"> { formatCurrency(satoshisToCurrency(lockedAmount), "$") } </span>
            </div>
          </div>
        </div>
      </div>
      <div className="flex flex-col justify-center bg-slate-200 dark:bg-gray-800 rounded p-6 space-y-6">
        <div className="flex flex-col justify-center w-full">
          <span className="text-xl font-semibold">Your collateral</span>
          <div className="grid grid-cols-[1fr_1fr_1fr_1fr_1fr] items-center gap-6 w-full max-w-5xl mt-4">
            <TokenLabel metadata={usdtMetadata}/>
            <div className="relative flex flex-col">
              <span className="text-lg font-bold"> { formatCurrency(fromFixedPoint(collateral, 6), "")} </span>
              <span className="absolute top-6 text-xs text-gray-400"> { formatCurrency(fromFixedPoint(collateral, 6), "$") } </span>
            </div>
            <span>{/*spacer*/}</span>
            <BorrowButton 
              title="Supply"
              tokenMetadata={usdtMetadata}
              previewOperation={(amount) => previewOperation({ "PROVIDE_COLLATERAL": { amount } })}
              runOperation={(amount) => runOperation({ "PROVIDE_COLLATERAL": { amount } })}
              tokenDecimals={6}
              amountInUsd={amount => fromFixedPoint(amount, 6)}
              health={health}
              maxChoice={{type: MaxChoiceType.WalletBalance, value: usdtAllowance ?? 0n, formatValue: (value) => formatCurrency(fromFixedPoint(value, 6), "$")}}
            />
            <BorrowButton 
              title="Withdraw"
              tokenMetadata={usdtMetadata}
              previewOperation={(amount) => previewOperation({ "WITHDRAW_COLLATERAL": { amount } })}
              runOperation={(amount) => runOperation({ "WITHDRAW_COLLATERAL": { amount } })}
              tokenDecimals={6}
              amountInUsd={amount => fromFixedPoint(amount, 6)}
              health={health}
              maxChoice={{type: MaxChoiceType.Available, value: usdtAllowance ?? 0n, formatValue: (value) => formatCurrency(fromFixedPoint(value, 6), "$")/* @todo: not use allowance*/}}
            />
          </div>
        </div>
        <div className="border-b border-gray-300 dark:border-gray-700 w-full"></div>
        <div className="flex flex-col justify-center w-full">
          <span className="text-xl font-semibold">Your borrow</span>
          <div className="grid grid-cols-[1fr_1fr_1fr_1fr_1fr] items-center gap-6 w-full max-w-5xl mt-4">
            <TokenLabel metadata={btcMetadata}/>
            <div className="relative flex flex-col">
              <span className="text-lg font-bold"> { formatCurrency(fromFixedPoint(rawBorrowed, 8), "")} </span>
              <span className="absolute top-6 text-xs text-gray-400"> { formatCurrency(satoshisToCurrency(rawBorrowed), "$")} </span>
            </div>
            <span>{/*spacer*/}</span>
            <BorrowButton 
              title="Borrow"
              tokenMetadata={btcMetadata}
              previewOperation={(amount) => previewOperation({ "BORROW_SUPPLY": { amount } })}
              runOperation={(amount) => runOperation({ "BORROW_SUPPLY": { amount } })}
              tokenDecimals={8}
              amountInUsd={amount => satoshisToCurrency(amount)}
              health={health}
              maxChoice={{type: MaxChoiceType.Available, value: btcAllowance ?? 0n, formatValue: (value) => formatCurrency(fromFixedPoint(value, 8), "") /* @todo: not use allowance*/}}
            />
            <BorrowButton 
              title="Repay"
              tokenMetadata={btcMetadata}
              previewOperation={(amount) => previewOperation({ "REPAY_SUPPLY": { repayment: { "PARTIAL" : amount } } })}
              runOperation={(amount) => runOperation({ "REPAY_SUPPLY": { repayment: { "PARTIAL" : amount } } })}
              tokenDecimals={8}
              amountInUsd={amount => satoshisToCurrency(amount)}
              health={health}
              maxChoice={{type: MaxChoiceType.WalletBalance, value: btcAllowance ?? 0n, formatValue: (value) => formatCurrency(fromFixedPoint(value, 8), "")}}
            />
          </div>
        </div>
      </div>
    </div>
  );
}

export default BorrowTab;