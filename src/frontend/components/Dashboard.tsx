import { useEffect, useMemo } from "react";
import { protocolActor } from "../actors/ProtocolActor";
import { formatAmountCompact } from "../utils/conversions/token";
import BorrowInfoPanel from "./borrow/BorrowInfoPanel";
import InterestRateModel from "./borrow/InterestRateModel";
import SupplyInfoPanel from "./borrow/SupplyInfoPanel";
import DualLabel from "./common/DualLabel";
import { FullTokenLabel } from "./common/TokenLabel";
import { aprToApy } from "../utils/lending";
import { useFungibleLedgerContext } from "./context/FungibleLedgerContext";
import { useProtocolContext } from "./context/ProtocolContext";

// @todo: perfect layout for mobile
const Dashboard = () => {

  const { parameters } = useProtocolContext();

  const { data: indexerState, call: refreshIndexerState } = protocolActor.useQueryCall({
    functionName: 'get_lending_index',
  });

  const { supplyLedger } = useFungibleLedgerContext();

  useEffect(() => {
    refreshIndexerState();
  }, []);

  // @todo: need to also get the actual liquidity from the ledger and show both in a detail panel that can be expanded
  const realLiquidity = useMemo(() => {
    if (!indexerState) {
      return undefined;
    }
    const realSupplied = indexerState.utilization.raw_supplied + indexerState.accrued_interests.supply;
    const realBorrowed = indexerState.utilization.raw_borrowed + indexerState.accrued_interests.borrow;
    return realSupplied - realBorrowed;
  }, [indexerState]);

  if (!parameters || !indexerState) {
    return <div className="text-center text-gray-500">Loading...</div>;
  }

  return (
    <div className="flex flex-col justify-center my-4 p-4 md:p-6 space-y-6">
      <div className="flex flex-col md:flex-row text-center text-gray-800 dark:text-gray-200 px-6 space-y-4 md:space-y-0 md:space-x-8 items-center">
        { /* TODO: fix hardcoded link to ckUSDT ledger */ }
        <FullTokenLabel
          metadata={supplyLedger.metadata}
          canisterId={"cngnf-vqaaa-aaaar-qag4q-cai"}
        />
        <div className="hidden md:block border-r border-gray-300 dark:border-gray-700 h-full"></div>
        <DualLabel
          top="Reserve Size"
          bottom={supplyLedger.formatAmountUsd(indexerState.utilization.raw_supplied)}
        />
        <DualLabel
          top="Available liquidity"
          bottom={supplyLedger.formatAmountUsd(indexerState.utilization.raw_supplied * (1 - indexerState.utilization.ratio))}
        />
        <DualLabel
          top="Utilization Rate"
          bottom= {`${(indexerState.utilization.ratio * 100).toFixed(2)}%`}
        />
        <DualLabel
          top="Oracle price"
          bottom={ supplyLedger.price === undefined ? `` : `${formatAmountCompact(supplyLedger.price, 2)}`}
        />
      </div>
      <div className="grid grid-cols-1 md:grid-cols-[150px_1fr] gap-y-4 md:gap-x-6 w-full max-w-5xl bg-slate-200 dark:bg-gray-800 rounded p-4 md:p-6">
        <span className="text-base font-semibold self-start">
          Supply info
        </span>
        <SupplyInfoPanel
          supplyCap={Number(parameters.lending.supply_cap)}
          totalSupplied={indexerState.utilization.raw_supplied}
          apy={aprToApy(indexerState.supply_rate)}
          maxLtv={parameters.lending.max_ltv}
          liquidationThreshold={parameters.lending.liquidation_threshold}
          liquidationPenalty={parameters.lending.liquidation_penalty}
          ledger={supplyLedger}
        />
        <div className="border-b border-gray-300 dark:border-gray-700 w-full col-span-1 md:col-span-2"></div>
        <span className="text-base font-semibold self-start">Borrow info</span>
        <BorrowInfoPanel
          borrowCap={Number(parameters.lending.borrow_cap)}
          totalBorrowed={indexerState.utilization.raw_borrowed}
          apy={aprToApy(indexerState.borrow_rate)}
          reserveFactor={parameters.lending.lending_fee_ratio}
          ledger={supplyLedger}
        />
        <div className="border-b border-gray-300 dark:border-gray-700 w-full col-span-1 md:col-span-2"></div>
        <span className="text-base font-semibold self-start">Interest rate model</span>
        <InterestRateModel
          utilizationRate={indexerState.utilization.ratio} // Example utilization rate
        />
      </div>
    </div>
  );
}

export default Dashboard;