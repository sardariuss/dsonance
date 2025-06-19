import { protocolActor } from "../../actors/ProtocolActor";
import BorrowInfoPanel from "./BorrowInfoPanel";
import InterestRateModel from "./InterestRateModel";
import SupplyInfoPanel from "./SupplyInfoPanel";

const BorrowTab = () => {

  const { data: lendingParams } = protocolActor.useQueryCall({
    functionName: 'get_lending_parameters',
  });

  const { data: indexerState } = protocolActor.useQueryCall({
    functionName: 'get_indexer_state',
  });

  if (!lendingParams || !indexerState) {
    return <div className="text-center text-gray-500">Loading...</div>;
  }

  return (
    <div className="flex flex-col justify-center bg-slate-200 dark:bg-gray-800 rounded mt-4 p-6 space-y-6">
      <div className="text-xl font-semibold">Reserve status & configuration</div>
      <div className="grid grid-cols-[150px_1fr] gap-y-4 gap-x-6 w-full max-w-5xl">
        <span className="text-base font-semibold text-white self-start">
          Supply info
        </span>
        <SupplyInfoPanel
          supplyCap={Number(lendingParams.supply_cap)}
          totalSupplied={indexerState.utilization.raw_supplied}
          apy={aprToApy(indexerState.supply_rate)}
          maxLtv={lendingParams.max_ltv}
          liquidationThreshold={lendingParams.liquidation_threshold}
          liquidationPenalty={lendingParams.liquidation_penalty}
        />
        <div className="border-b border-gray-300 dark:border-gray-700 w-full col-span-2"></div>
        <span className="text-base font-semibold text-white self-start">Borrow info</span>
        <BorrowInfoPanel
          borrowCap={Number(lendingParams.borrow_cap)}
          totalBorrowed={indexerState.utilization.raw_borrowed}
          apy={aprToApy(indexerState.borrow_rate)}
          reserveFactor={lendingParams.reserve_liquidity}
        />
        <div className="border-b border-gray-300 dark:border-gray-700 w-full col-span-2"></div>
        <span className="text-base font-semibold text-white self-start">Interest rate model</span>
        <InterestRateModel
          utilizationRate={indexerState.utilization.ratio} // Example utilization rate
        />
      </div>
    </div>
  );
}

function aprToApy(rate: number, compoundingPerYear = 365 * 24 * 60 * 60): number {
  return Math.pow(1 + rate / compoundingPerYear, compoundingPerYear) - 1;
}

export default BorrowTab;