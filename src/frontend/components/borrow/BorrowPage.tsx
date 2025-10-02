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
    <div className="bg-white dark:bg-slate-800 shadow-md rounded-md p-2 sm:p-4 md:p-6 border border-slate-300 dark:border-slate-700">
      <div className="flex flex-col lg:flex-row justify-between w-full gap-4">
        <div className="flex flex-col w-full">
          <span className="text-xl font-semibold">Locked positions</span>
          <div className="flex flex-row items-center gap-4 mt-4">
            <TokenLabel metadata={supplyLedger.metadata}/>
            <div className="flex flex-col">
              <span className="text-lg font-bold"> { supplyLedger.formatAmount(userSupply?.amount) } </span>
              <span className="text-xs text-gray-400"> { supplyLedger.formatAmountUsd(userSupply?.amount) } </span>
            </div>
          </div>
        </div>
      </div>
      <BallotListContent user={user} />
      <div className="flex flex-col lg:flex-row justify-between w-full gap-4">
        <div className="flex flex-col">
          <span className="text-xl font-semibold">Withdrawable</span>
          <div className="flex flex-row items-center gap-4 mt-4">
            <TokenLabel metadata={supplyLedger.metadata}/>
            <div className="flex flex-col">
              {/* TODO: for now user supply is always 0 because the positions are automatically transferred back at resolution. */}
              <span className="text-lg font-bold"> { supplyLedger.formatAmount(0) } </span>
              <span className="text-xs text-gray-400"> { supplyLedger.formatAmountUsd(0) } </span>
            </div>
          </div>
        </div>
        <div className="flex flex-row gap-2 lg:w-auto w-full lg:min-w-[300px]">
          <div className="flex-1">
            <ActionButton title="Withdraw" disabled />
          </div>
        </div>
      </div>
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
      <div className="flex flex-col lg:flex-row justify-between w-full gap-4">
        <div className="flex flex-col">
          <span className="text-xl font-semibold">Your borrow</span>
          <div className="flex flex-row items-center gap-4 mt-4">
            <TokenLabel metadata={supplyLedger.metadata}/>
            <div className="flex flex-col">
              <span className="text-lg font-bold"> { supplyLedger.formatAmount(currentOwed) } </span>
              <span className="text-xs text-gray-400"> { supplyLedger.formatAmountUsd(currentOwed) } </span>
            </div>
          </div>
        </div>
        <div className="flex flex-row gap-2 lg:w-auto w-full lg:min-w-[300px]">
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
      <div className="border-b border-gray-300 dark:border-gray-700 w-full"></div>
      <div className="flex flex-col lg:flex-row justify-between w-full gap-4">
        <div className="flex flex-col">
          <span className="text-xl font-semibold">Your collateral</span>
          <div className="flex flex-row items-center gap-4 mt-4">
            <TokenLabel metadata={collateralLedger.metadata}/>
            <div className="flex flex-col">
              <span className="text-lg font-bold"> { collateralLedger.formatAmount(collateral) } </span>
              <span className="text-xs text-gray-400"> { collateralLedger.formatAmountUsd(collateral) } </span>
            </div>
          </div>
        </div>
        <div className="flex flex-row gap-2 lg:w-auto w-full lg:min-w-[300px]">
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
  );
};

