interface MiningContentProps {
  tracker: {
    received: bigint;
    owed: bigint;
  } | undefined;
  formatAmount: (amount: bigint) => string;
  onWithdraw: () => void;
  withdrawLoading: boolean;
}

export const MiningContent = ({ tracker, formatAmount, onWithdraw, withdrawLoading }: MiningContentProps) => {
  if (!tracker) {
    return (
      <div className="text-center text-gray-500 dark:text-gray-400">
        <p>No mining data available</p>
      </div>
    );
  }

  const lifetimeMined = tracker.received + tracker.owed;

  return (
    <div className="space-y-6">
      {/* Performance Section */}
      <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4 border border-gray-200 dark:border-gray-600">
        <h5 className="font-semibold text-gray-900 dark:text-white mb-3 text-sm uppercase tracking-wide">Performance</h5>
        <div className="space-y-3">
          <div className="flex justify-between items-center py-1">
            <span className="text-sm text-gray-600 dark:text-gray-400">Realized APY</span>
            <span className="font-semibold text-gray-900 dark:text-white">
              --%
            </span>
          </div>
          <div className="h-px bg-gray-200 dark:bg-gray-700"></div>
          <div className="flex justify-between items-center py-1">
            <span className="text-sm text-gray-600 dark:text-gray-400">Current APY</span>
            <span className="font-semibold text-gray-900 dark:text-white">
              --%
            </span>
          </div>
        </div>
      </div>

      {/* Rewards Section */}
      <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4 border border-gray-200 dark:border-gray-600">
        <h5 className="font-semibold text-gray-900 dark:text-white mb-3 text-sm uppercase tracking-wide">Rewards</h5>
        <div className="space-y-3">
          <div className="flex justify-between items-center py-1">
            <span className="text-sm text-gray-600 dark:text-gray-400">Lifetime mined</span>
            <span className="font-semibold text-gray-900 dark:text-white">
              {formatAmount(lifetimeMined)}
            </span>
          </div>
          <div className="h-px bg-gray-200 dark:bg-gray-700"></div>
          <div className="flex justify-between items-center py-1">
            <span className="text-sm text-gray-600 dark:text-gray-400">Already withdrawn</span>
            <span className="font-semibold text-gray-900 dark:text-white">
              {formatAmount(tracker.received)}
            </span>
          </div>
          <div className="h-px bg-gray-200 dark:bg-gray-700"></div>
          <div className="flex justify-between items-center py-1">
            <span className="text-sm text-gray-600 dark:text-gray-400">Available to withdraw</span>
            <span className="font-semibold text-gray-900 dark:text-white">
              {formatAmount(tracker.owed)}
            </span>
          </div>
        </div>

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
  );
};
