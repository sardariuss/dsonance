import { useEffect } from "react";
import { protocolActor } from "../actors/ProtocolActor";
import { formatAmountCompact } from "../utils/conversions/token";
import BorrowInfoPanel from "./borrow/BorrowInfoPanel";
import InterestRateModel from "./borrow/InterestRateModel";
import SupplyInfoPanel from "./borrow/SupplyInfoPanel";
import DualLabel from "./common/DualLabel";
import { FullTokenLabel } from "./common/TokenLabel";
import { aprToApy } from "../utils/lending";
import { Currency, LedgerType, useFungibleLedger } from "./hooks/useFungibleLedger";

const Dashboard = () => {

  const { data: lendingParams, call: refreshLendingParams } = protocolActor.useQueryCall({
    functionName: 'get_lending_parameters',
  });

  const { data: indexerState, call: refreshIndexerState } = protocolActor.useQueryCall({
    functionName: 'get_lending_index',
  });

  const { formatAmount, price, metadata } = useFungibleLedger(LedgerType.SUPPLY); // This will fetch the ckBTC supply ledger metadata and price

  useEffect(() => {
    refreshLendingParams();
    refreshIndexerState();
  }, []);

  if (!lendingParams || !indexerState) {
    return <div className="text-center text-gray-500">Loading...</div>;
  }

  return (
    <div className="flex flex-col justify-center my-4 p-6 space-y-6">
      <div className="flex flex-row text-center text-gray-800 dark:text-gray-200 px-6 space-x-8 items-center">
        <FullTokenLabel
          metadata={metadata}
        />
        <div className="border-r border-gray-300 dark:border-gray-700 h-full"></div>
        <DualLabel
          top="Reserve Size"
          bottom={formatAmount(indexerState.utilization.raw_supplied, Currency.USD)}
        />
        <DualLabel
          top="Available liquidity"
          bottom={formatAmount(indexerState.utilization.raw_supplied * (1 - indexerState.utilization.ratio), Currency.USD)}
        />
        <DualLabel
          top="Utilization Rate"
          bottom= {`${(indexerState.utilization.ratio * 100).toFixed(2)}%`}
        />
        <DualLabel
          top="Oracle price"
          bottom={ price === undefined ? `` : `$${formatAmountCompact(price, 2)}`}
        />
      </div>
      <div className="grid grid-cols-[150px_1fr] gap-y-4 gap-x-6 w-full max-w-5xl bg-slate-200 dark:bg-gray-800 rounded p-6">
        <span className="text-base font-semibold self-start">
          Supply info
        </span>
        <SupplyInfoPanel
          supplyCap={Number(lendingParams.supply_cap)}
          totalSupplied={indexerState.utilization.raw_supplied}
          apy={aprToApy(indexerState.supply_rate)}
          maxLtv={lendingParams.max_ltv}
          liquidationThreshold={lendingParams.liquidation_threshold}
          liquidationPenalty={lendingParams.liquidation_penalty}
          formatAmount={formatAmount}
        />
        <div className="border-b border-gray-300 dark:border-gray-700 w-full col-span-2"></div>
        <span className="text-base font-semibold self-start">Borrow info</span>
        <BorrowInfoPanel
          borrowCap={Number(lendingParams.borrow_cap)}
          totalBorrowed={indexerState.utilization.raw_borrowed}
          apy={aprToApy(indexerState.borrow_rate)}
          reserveFactor={lendingParams.lending_fee_ratio}
          formatAmount={formatAmount}
        />
        <div className="border-b border-gray-300 dark:border-gray-700 w-full col-span-2"></div>
        <span className="text-base font-semibold self-start">Interest rate model</span>
        <InterestRateModel
          utilizationRate={indexerState.utilization.ratio} // Example utilization rate
        />
      </div>
    </div>
  );
}

export default Dashboard;