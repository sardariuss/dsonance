import { TokenLabel } from "../common/TokenLabel";
import ActionButton from "../common/ActionButton";
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

  return (
    <div className="bg-white dark:bg-slate-800 shadow-md rounded-md p-2 sm:p-4 md:p-6 border border-slate-300 dark:border-slate-700 space-y-6">
      <div className="flex flex-col w-full gap-4">
        <span className="text-xl font-semibold">Your mining rewards</span>
        <div className="flex flex-col lg:flex-row justify-between items-start lg:items-center w-full gap-4">
          <div className="flex flex-row items-center gap-4">
            <TokenLabel metadata={participationLedger.metadata}/>
            <div className="flex flex-col">
              <span className="text-lg font-bold"> { participationLedger.formatAmount(tracker.owed) } </span>
              <span className="text-xs text-gray-400"> { participationLedger.formatAmountUsd(tracker.owed) } </span>
            </div>
          </div>
          <div className="flex flex-row gap-2 lg:w-auto w-full">
            <div className="flex-1">
              <ActionButton
                title="Withdraw"
                onClick={onWithdraw}
                disabled={tracker.owed === 0n}
                loading={withdrawLoading}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
