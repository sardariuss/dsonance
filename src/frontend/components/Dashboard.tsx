import { useEffect } from "react";
import { useSearchParams } from "react-router-dom";
import SupplyDashboard from "./dashboard/SupplyDashboard";
import { TabButton } from "./TabButton";
import ParticipationDashboard from "./dashboard/ParticipationDashboard";
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
    <div className="w-full max-w-5xl mx-auto">
      { /* Tabs */}
      <ul className="flex flex-wrap gap-x-3 sm:gap-x-6 gap-y-2 my-4 sm:my-6 items-center justify-center">
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
        {selectedTab === "supply" ? <SupplyDashboard/> : selectedTab === "collateral" ? <CollateralDashboard/> : <ParticipationDashboard/>}
      </div>
    </div>
  );
}

export default Dashboard;