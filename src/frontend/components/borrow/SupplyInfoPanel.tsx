import { formatAmountUsd } from "../../utils/conversions/token";
import React from "react";
import { FungibleLedger } from "../hooks/useFungibleLedger";

interface SupplyInfoProps {
  ledger: FungibleLedger;
  supplyCap: number; // e.g., 3_000_000
  totalSupplied: number; // e.g., 2_640_000
  apy: number; // e.g., 1.93
  maxLtv: number;
  liquidationThreshold: number;
  liquidationPenalty: number;
}

const SupplyInfoPanel: React.FC<SupplyInfoProps> = ({
  ledger,
  supplyCap,
  totalSupplied,
  apy,
  maxLtv,
  liquidationThreshold,
  liquidationPenalty,
}) => {

  const usagePercent = (totalSupplied / supplyCap) * 100;

  return (
    <div className="flex flex-col px-6 max-w-3xl w-full space-y-6">
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

        <div className="grid grid-rows-3 gap-1 h-full">
          <span className="text-sm text-gray-500 dark:text-gray-400">Total supplied</span>
          <span className="text-lg font-bold">
            { `${ledger.formatAmount(totalSupplied)} of ${ledger.formatAmount(supplyCap)}` }
          </span>
          <span className="text-xs text-gray-500 dark:text-gray-400">
            { `${formatAmountUsd(ledger.convertToUsd(totalSupplied))} of ${formatAmountUsd(ledger.convertToUsd(supplyCap))}` }
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

      {/* Risk parameters */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-sm">
        <div className="p-4 rounded-md flex flex-col border border-gray-700">
          <span className="text-gray-500 dark:text-gray-400">Max LTV</span>
          <span className="font-semibold">{(maxLtv * 100).toFixed(2)}%</span>
        </div>
        <div className="p-4 rounded-md flex flex-col border border-gray-700">
          <span className="text-gray-500 dark:text-gray-400">Liquidation threshold</span>
          <span className="font-semibold">{(liquidationThreshold * 100).toFixed(2)}%</span>
        </div>
        <div className="p-4 rounded-md flex flex-col border border-gray-700">
          <span className="text-gray-500 dark:text-gray-400">Liquidation penalty</span>
          <span className="font-semibold">{(liquidationPenalty * 100).toFixed(2)}%</span>
        </div>
      </div>
    </div>
  );
};

export default SupplyInfoPanel;
