import { TokenLabel } from "../common/TokenLabel";
import { BallotListContent } from "./BallotList";

export const ViewsContent = ({
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
      <div className="flex flex-col w-full">
        <span className="text-xl font-semibold">Locked</span>
        <div className="flex flex-row items-center gap-4 mt-4">
          <TokenLabel metadata={supplyLedger.metadata}/>
          <div className="flex flex-col">
            <span className="text-lg font-bold"> { supplyLedger.formatAmount(userSupply?.amount) } </span>
            <span className="text-xs text-gray-400"> { supplyLedger.formatAmountUsd(userSupply?.amount) } </span>
          </div>
        </div>
      </div>
      <BallotListContent user={user} />
    </div>
  );
};
