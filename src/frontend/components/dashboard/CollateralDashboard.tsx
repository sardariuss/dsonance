import { useEffect } from "react";
import { formatAmountCompact } from "../../utils/conversions/token";
import DualLabel from "../common/DualLabel";
import { FullTokenLabel } from "../common/TokenLabel";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";
import { DASHBOARD_CONTAINER, STATS_OVERVIEW_CONTAINER, VERTICAL_DIVIDER, METRICS_WRAPPER, CONTENT_PANEL } from "../../utils/styles";

const CollateralDashboard = () => {

  const { collateralLedger } = useFungibleLedgerContext();

  useEffect(() => {
    // Refresh any data if needed
  }, []);

  if (!collateralLedger.totalSupply) {
    return <div className="text-center text-gray-500">Loading...</div>;
  }

  return (
    <div className={DASHBOARD_CONTAINER}>
      <div className={STATS_OVERVIEW_CONTAINER}>
        <FullTokenLabel
          metadata={collateralLedger.metadata}
          canisterId={"mxzaz-hqaaa-aaaar-qaada-cai"}
        />
        <div className={VERTICAL_DIVIDER}></div>
        <div className={METRICS_WRAPPER}>
          <DualLabel
            top="Total Supply"
            bottom={collateralLedger.formatAmountUsd(collateralLedger.totalSupply)}
          />
          <DualLabel
            top="Oracle price"
            bottom={collateralLedger.price === undefined ? `` : `${formatAmountCompact(collateralLedger.price, 2)}`}
          />
        </div>
      </div>
      <div className={CONTENT_PANEL}>
        <div className="text-center text-gray-600 dark:text-gray-400">
          <p className="text-sm">
            ckBTC serves as collateral in the lending protocol. Users can deposit ckBTC to borrow against it.
          </p>
        </div>
      </div>
    </div>
  );
}

export default CollateralDashboard;