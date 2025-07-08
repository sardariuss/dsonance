import React from "react";
import { FungibleLedger } from "../hooks/useFungibleLedger";
import ProgressCircle from "../ui/ProgressCircle";

interface BorrowInfoProps {
  ledger: FungibleLedger;
  borrowCap: number; // e.g., 2_700_000
  totalBorrowed: number; // e.g., 2_290_000
  apy: number; // e.g., 2.63
  reserveFactor: number; // e.g., 15.0
}

const BorrowInfoPanel: React.FC<BorrowInfoProps> = ({
  ledger,
  borrowCap,
  totalBorrowed,
  apy,
  reserveFactor,
}) => {

  const usagePercent = (totalBorrowed / borrowCap) * 100;

  return (
    <div className="flex flex-col px-6 max-w-3xl w-full space-y-6">
      <div className="flex flex-row items-center justify-start gap-6">
        {/* Left circle */}
        <div className="flex items-center space-x-4">
          <ProgressCircle percentage={usagePercent} />
        </div>

        {/* Borrowed amount */}
        <div className="grid grid-rows-3 gap-1 h-full">
            <span className="text-sm text-gray-500 dark:text-gray-400">Total borrowed</span>
            <span className="text-lg font-bold">
              {`${ledger.formatAmount(totalBorrowed)} of ${ledger.formatAmount(borrowCap)}`}
            </span>
            <span className="text-xs text-gray-500 dark:text-gray-400">
              {`${ledger.formatAmountUsd(totalBorrowed)} of ${ledger.formatAmountUsd(borrowCap)}`}
            </span>
          </div>

        <div className="border-l border-gray-300 dark:border-gray-700 h-1/2"></div>

        {/* Right APY */}
        <div className="grid grid-rows-3 gap-1 h-full">
          <span className="text-sm text-gray-500 dark:text-gray-400">APY</span>
          <span className="text-lg font-bold">{(apy * 100).toFixed(2)}%</span>
          <span></span>
        </div>
      </div>

      {/* Reserve factor */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
        <div className="p-4 rounded-md flex flex-col border border-gray-700">
          <span className="text-gray-500 dark:text-gray-400">Reserve factor</span>
          <span className="font-semibold">{(reserveFactor * 100).toFixed(2)}%</span>
        </div>
      </div>
    </div>
  );
};

export default BorrowInfoPanel;
