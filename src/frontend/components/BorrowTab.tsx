import SupplyInfoPanel from "./SupplyInfoPanel";


const BorrowTab = () => {
  return (
    <div className="flex flex-col items-center justify-center h-full">
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
    </div>
  );
}

export default BorrowTab;