import BorrowInfoPanel from "./BorrowInfoPanel";
import InterestRateModel from "./InterestRateModel";
import SupplyInfoPanel from "./SupplyInfoPanel";


const BorrowTab = () => {
  return (
    <div className="flex flex-col justify-center bg-slate-200 dark:bg-gray-800 rounded mt-4 p-6 space-y-6">
      <div className="text-xl font-semibold">Reserve status & configuration</div>
      <div className="grid grid-cols-[150px_1fr] gap-y-4 gap-x-6 w-full max-w-5xl">
        <span className="text-base font-semibold text-white self-start">
          Supply info
        </span>
        <SupplyInfoPanel
          supplyCap={3_000_000}
          totalSupplied={2_640_000}
          apy={1.93}
          supplyUsd={6.7}
          capUsd={7.61}
          maxLtv={80.5}
          liquidationThreshold={83.0}
          liquidationPenalty={5.0}
        />
        <div className="border-b border-gray-300 dark:border-gray-700 w-full col-span-2"></div>
        <span className="text-base font-semibold text-white self-start">Borrow info</span>
        <BorrowInfoPanel
          borrowCap={2_700_000}
          totalBorrowed={2_290_000}
          apy={2.63}
          borrowUsd={5.72}
          capUsd={6.76}
          reserveFactor={15.0}
        />
        <div className="border-b border-gray-300 dark:border-gray-700 w-full col-span-2"></div>
        <span className="text-base font-semibold text-white self-start">Interest rate model</span>
        <InterestRateModel
          utilizationRate={0.85} // Example utilization rate
        />
      </div>
    </div>
  );
}

export default BorrowTab;