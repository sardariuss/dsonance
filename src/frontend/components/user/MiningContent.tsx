import { TokenLabel } from "../common/TokenLabel";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";

interface MiningContentProps {
  tracker: {
    received: bigint;
    owed: bigint;
  } | undefined;
  formatAmount: (amount: bigint) => string | undefined;
  onWithdraw: () => void;
  withdrawLoading: boolean;
}

export const MiningContent = ({ tracker, formatAmount, onWithdraw, withdrawLoading }: MiningContentProps) => {

  const { participationLedger } = useFungibleLedgerContext();

  if (!tracker) {
    return (
      <div className="text-center text-gray-500 dark:text-gray-400">
        <p>No mining data available</p>
      </div>
    );
  }

  const lifetimeMined = tracker.received + tracker.owed;

  return (
    <div className="bg-white dark:bg-slate-800 shadow-md rounded-md p-2 sm:p-4 md:p-6 border border-slate-300 dark:border-slate-700 space-y-6">
      <div className="flex flex-col lg:flex-row justify-between w-full gap-4">
        <div className="flex flex-col">
          <span className="text-xl font-semibold">Your mining rewards</span>
          <div className="flex flex-row items-center gap-4 mt-4">
            <TokenLabel metadata={participationLedger.metadata}/>
            <div className="flex flex-col">
              <span className="text-lg font-bold"> { participationLedger.formatAmount(tracker.owed) } </span>
              <span className="text-xs text-gray-400"> { participationLedger.formatAmountUsd(tracker.owed) } </span>
            </div>
          </div>
        </div>
        <div className="flex flex-row gap-2 lg:w-auto w-full lg:min-w-[300px]">
          <div className="flex-1">
            {tracker.owed > 0n && (
              <button
                onClick={onWithdraw}
                disabled={withdrawLoading}
                className="w-full mt-4 px-4 py-2.5 bg-blue-500 hover:bg-blue-600 disabled:bg-gray-400 disabled:cursor-not-allowed text-white font-medium rounded-md transition-colors shadow-sm"
              >
                {withdrawLoading ? "Withdrawing..." : "Withdraw"}
              </button>
            )}
          </div>  
        </div>
      </div>
    </div>
  );
};
