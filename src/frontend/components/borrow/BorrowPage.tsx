import { TokenLabel } from "../common/TokenLabel";
import BorrowButton from "./BorrowButton";
import ActionButton from "../common/ActionButton";
import { OperationKind, Result_1 } from "../../../declarations/protocol/protocol.did";
import { REPAY_SLIPPAGE_RATIO } from "../../constants";
import { BallotListContent } from "../user/BallotList";

export const SupplyContent = ({
  user,
  userSupply,
  supplyLedger
}: {
  user: any;
  userSupply: any;
  supplyLedger: any;
}) => {
  return (
    <div className="bg-white dark:bg-slate-800 shadow-md rounded-md p-2 sm:p-4 md:p-6 border border-slate-300 dark:border-slate-700 space-y-4">
      {/* Beta Limitation Notice */}
      <div className="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 p-4 rounded-lg">
        <div className="flex items-center gap-3">
          <span className="text-amber-600 dark:text-amber-400 text-xl mt-0.5">ℹ️</span>
          <div className="flex-1">
            <p className="text-sm text-gray-700 dark:text-gray-300">
              <span className="font-semibold">Beta limitation:</span> Resolved positions are currently sent straight to your wallet at resolution. In the future, they'll remain in the supply pool to keep accumulating the base supply APR and be withdrawable at any moment.
            </p>
          </div>
        </div>
      </div>

      <div className="flex flex-col w-full gap-4">
        <div className="flex flex-col gap-1">
          <span className="text-xl font-semibold">Withdrawable</span>
        </div>
        <div className="flex flex-col lg:flex-row justify-between items-start lg:items-center w-full">
          <div className="flex flex-row items-center gap-4">
            <TokenLabel metadata={supplyLedger.metadata}/>
            <div className="flex flex-col">
              <span className="text-lg font-bold"> { supplyLedger.formatAmount(0) } </span>
              <span className="text-xs text-gray-400"> { supplyLedger.formatAmountUsd(0) } </span>
            </div>
          </div>
          <div className="flex flex-row gap-2 lg:w-auto w-full">
            <div className="flex-1">
              <ActionButton title="Withdraw" disabled />
            </div>
          </div>
        </div>
      </div>
      <div className="flex flex-col lg:flex-row justify-between w-full">
        <div className="flex flex-col w-full gap-4">
          <div className="flex flex-col gap-1">
            <span className="text-xl font-semibold">Locked</span>
          </div>
          <div className="flex flex-row items-center gap-4">
            <TokenLabel metadata={supplyLedger.metadata}/>
            <div className="flex flex-col">
              <span className="text-lg font-bold"> { supplyLedger.formatAmount(userSupply?.amount) } </span>
              <span className="text-xs text-gray-400"> { supplyLedger.formatAmountUsd(userSupply?.amount) } </span>
            </div>
          </div>
        </div>
      </div>
      <BallotListContent user={user} />
    </div>
  );
};

export const BorrowContent = ({
  collateral,
  currentOwed,
  maxWithdrawable,
  maxBorrowable,
  collateralLedger,
  supplyLedger,
  previewOperation,
  runOperation
}: {
  collateral: bigint;
  currentOwed: bigint;
  maxWithdrawable: bigint;
  maxBorrowable: bigint;
  collateralLedger: any;
  supplyLedger: any;
  previewOperation: (amount: bigint, kind: OperationKind) => Promise<Result_1 | undefined>;
  runOperation: (amount: bigint, kind: OperationKind) => Promise<Result_1 | undefined>;
}) => {
  return (
    <div className="bg-white dark:bg-slate-800 shadow-md rounded-md p-2 sm:p-4 md:p-6 border border-slate-300 dark:border-slate-700 space-y-6">
      <div className="flex flex-col w-full gap-4">
        <span className="text-xl font-semibold">Your borrow</span>
        <div className="flex flex-col lg:flex-row justify-between items-start lg:items-center w-full gap-4">
          <div className="flex flex-row items-center gap-4">
            <TokenLabel metadata={supplyLedger.metadata}/>
            <div className="flex flex-col">
              <span className="text-lg font-bold"> { supplyLedger.formatAmount(currentOwed) } </span>
              <span className="text-xs text-gray-400"> { supplyLedger.formatAmountUsd(currentOwed) } </span>
            </div>
          </div>
          <div className="flex flex-row gap-2 lg:w-auto w-full">
            <div className="flex-1">
              <BorrowButton
                title="Borrow"
                ledger={supplyLedger}
                previewOperation={(amount) => previewOperation(amount, { "BORROW_SUPPLY": null })}
                runOperation={(amount) => runOperation(amount, { "BORROW_SUPPLY": null })}
                maxLabel="Available"
                maxAmount={maxBorrowable}
              />
            </div>
            <div className="flex-1">
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
      <div className="border-b border-gray-300 dark:border-gray-700 w-full"></div>
      <div className="flex flex-col w-full gap-4">
        <span className="text-xl font-semibold">Your collateral</span>
        <div className="flex flex-col lg:flex-row justify-between items-start lg:items-center w-full gap-4">
          <div className="flex flex-row items-center gap-4">
            <TokenLabel metadata={collateralLedger.metadata}/>
            <div className="flex flex-col">
              <span className="text-lg font-bold"> { collateralLedger.formatAmount(collateral) } </span>
              <span className="text-xs text-gray-400"> { collateralLedger.formatAmountUsd(collateral) } </span>
            </div>
          </div>
          <div className="flex flex-row gap-2 lg:w-auto w-full">
            <div className="flex-1">
              <BorrowButton
                title="Supply"
                ledger={collateralLedger}
                previewOperation={(amount) => previewOperation(amount, { "PROVIDE_COLLATERAL" : null })}
                runOperation={(amount) => runOperation(amount, { "PROVIDE_COLLATERAL" : null })}
                maxLabel="Wallet balance"
                maxAmount={collateralLedger.userBalance ?? 0n }
              />
            </div>
            <div className="flex-1">
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
        </div>
      </div>
    </div>
  );
};

