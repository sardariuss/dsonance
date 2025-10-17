import { TokenLabel } from "../common/TokenLabel";
import ActionButton from "../common/ActionButton";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";

interface MiningContentProps {
  tracker: {
    claimed: bigint;
    allocated: bigint;
  } | undefined;
  onWithdraw: () => void;
  withdrawLoading: boolean;
}

export const MiningContent = ({ tracker, onWithdraw, withdrawLoading }: MiningContentProps) => {

  const { participationLedger } = useFungibleLedgerContext();

  return (
    <div className="bg-white dark:bg-slate-800 shadow-md rounded-md p-2 sm:p-4 md:p-6 border border-slate-300 dark:border-slate-700 space-y-6">
      <div className="flex flex-col w-full gap-4">
        <span className="text-xl font-semibold">Your mining rewards</span>
        <div className="flex flex-col lg:flex-row justify-between items-start lg:items-center w-full gap-4">
          <div className="flex flex-row items-center gap-4">
            <TokenLabel metadata={participationLedger.metadata}/>
            <div className="flex flex-col">
              <span className="text-lg font-bold"> { participationLedger.formatAmount(tracker?.allocated || 0n) } </span>
              <span className="text-xs text-gray-400"> { participationLedger.formatAmountUsd(tracker?.allocated || 0n) } </span>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-2 w-full lg:w-[320px]">
            <div></div>
            <ActionButton
              title="Withdraw"
              onClick={onWithdraw}
              disabled={tracker === undefined || tracker?.allocated === 0n}
              loading={withdrawLoading}
            />
          </div>
        </div>
      </div>
    </div>
  );
};
