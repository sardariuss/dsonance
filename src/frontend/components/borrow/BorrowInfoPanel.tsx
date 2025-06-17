import React from "react";

interface BorrowInfoProps {
  borrowCap: number; // e.g., 2_700_000
  totalBorrowed: number; // e.g., 2_290_000
  apy: number; // e.g., 2.63
  borrowUsd: number; // e.g., 5.72 (billions)
  capUsd: number; // e.g., 6.76 (billions)
  reserveFactor: number; // e.g., 15.0
}

const BorrowInfoPanel: React.FC<BorrowInfoProps> = ({
  borrowCap,
  totalBorrowed,
  apy,
  borrowUsd,
  capUsd,
  reserveFactor,
}) => {
  const usagePercent = (totalBorrowed / borrowCap) * 100;

  return (
    <div className="flex flex-col text-white px-6 max-w-3xl w-full space-y-6">
      <div className="flex flex-row items-center justify-start gap-6">
        {/* Left circle */}
        <div className="flex items-center space-x-4">
          <div className="relative w-20 h-20">
            <svg viewBox="0 0 36 36" className="w-full h-full">
              <path
                className="text-gray-700"
                d="M18 2.0845
                   a 15.9155 15.9155 0 0 1 0 31.831
                   a 15.9155 15.9155 0 0 1 0 -31.831"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
              />
              <path
                className="text-green-400"
                d="M18 2.0845
                   a 15.9155 15.9155 0 0 1 0 31.831"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeDasharray={`${usagePercent}, 100`}
              />
            </svg>
            <div className="absolute inset-0 flex items-center justify-center text-sm font-semibold">
              {usagePercent.toFixed(2)}%
            </div>
          </div>
        </div>

        {/* Borrowed amount */}
        <div className="grid grid-rows-3 gap-1 h-full">
          <span className="text-sm text-gray-400">Total borrowed</span>
          <span className="text-lg font-bold">
            {formatAmount(totalBorrowed)} of {formatAmount(borrowCap)}
          </span>
          <span className="text-xs text-gray-400">
            ${borrowUsd.toFixed(2)}B of ${capUsd.toFixed(2)}B
          </span>
        </div>

        <div className="border-l border-gray-300 dark:border-gray-700 h-1/2"></div>

        {/* Right APY */}
        <div className="grid grid-rows-3 gap-1 h-full">
          <span className="text-sm text-gray-400">APY, variable</span>
          <span className="text-lg font-bold">{apy.toFixed(2)}%</span>
          <span></span>
        </div>

        <div className="border-l border-gray-300 dark:border-gray-700 h-1/2"></div>

        {/* Borrow cap */}
        <div className="grid grid-rows-3 gap-1 h-full">
          <span className="text-sm text-gray-400">Borrow cap</span>
          <span className="text-lg font-bold">{formatAmount(borrowCap)}</span>
          <span className="text-xs text-gray-400">${capUsd.toFixed(2)}B</span>
        </div>
      </div>

      {/* Reserve factor */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
        <div className="p-4 rounded-md flex flex-col border border-gray-700">
          <span className="text-gray-400">Reserve factor</span>
          <span className="font-semibold">{reserveFactor.toFixed(2)}%</span>
        </div>
      </div>
    </div>
  );
};

function formatAmount(amount: number): string {
  return (amount / 1_000_000).toFixed(2) + "M";
}

export default BorrowInfoPanel;
