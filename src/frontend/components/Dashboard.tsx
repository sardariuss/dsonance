import { useEffect } from "react";
import { useSearchParams } from "react-router-dom";
import SupplyDashboard from "./dashboard/SupplyDashboard";
import { TabButton } from "./TabButton";
import MiningDashboard from "./dashboard/MiningDashboard";
import CollateralDashboard from "./dashboard/CollateralDashboard";

// @todo: perfect layout for mobile
const Dashboard = () => {

  const [searchParams, setSearchParams] = useSearchParams();
  const tabs = [
    { key: "supply", label: "Supply" },
    { key: "collateral", label: "Collateral" },
    { key: "mining", label: "Mining" },
  ];

  // Get the current tab or default to "votes"
  let selectedTab = searchParams.get("tab") || "supply";

  // Ensure the tab is valid, otherwise reset to "supply"
  useEffect(() => {
    if (!tabs.some(tab => tab.key === selectedTab)) {
      setSearchParams({ tab: "supply" }, { replace: true });
    }
  }, [selectedTab, setSearchParams]);

  return (
    <div className="w-full sm:w-4/5 md:w-11/12 lg:w-5/6 xl:w-4/5 mx-auto px-3 pb-3">
      { /* Tabs */}
      <ul className="flex flex-wrap gap-x-3 sm:gap-x-6 gap-y-2 my-4 sm:my-6">
        {tabs.map((tab) => (
          <li key={tab.key} className="min-w-max text-center">
            <TabButton
              label={tab.label}
              setIsCurrent={() => setSearchParams({ tab: tab.key })}
              isCurrent={selectedTab === tab.key}
            />
          </li>
        ))}
      </ul>
      {/* Content */}
      <div className="w-full min-h-[600px]">
        {selectedTab === "supply" ? <SupplyDashboard/> : selectedTab === "collateral" ? <CollateralDashboard/> : <MiningDashboard/>}
      </div>
    </div>
  );
}

export default Dashboard;