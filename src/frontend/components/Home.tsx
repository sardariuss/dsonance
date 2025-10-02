import { useNavigate, useSearchParams } from "react-router-dom";
import { useEffect } from "react";
import { TabButton } from "./TabButton";
import VoteList from "./VoteList";
import BallotList from "./user/BallotList";
import UserVotes from "./user/UserVotes";

const Home = () => {

  const navigate = useNavigate();

  const [searchParams, setSearchParams] = useSearchParams();
  const tabs = [
    { key: "pools", label: "Consensus pools" },
    { key: "your_views", label: "Your views" },
    { key: "opened_pools", label: "Your opened pools" },
  ];

  // Get the current tab or default to "votes"
  let selectedTab = searchParams.get("tab") || "pools";

  // Ensure the tab is valid, otherwise reset to "votes"
  useEffect(() => {
    if (!tabs.some(tab => tab.key === selectedTab)) {
      setSearchParams({ tab: "pools" }, { replace: true });
    }
  }, [selectedTab, setSearchParams]);

  return (
    <div className="flex flex-col w-full sm:w-4/5 md:w-11/12 lg:w-5/6 xl:w-4/5 mx-auto px-3">
      {/* Tabs */}
      <ul className="flex flex-wrap gap-x-3 sm:gap-x-6 gap-y-2 my-4 sm:my-6 items-center">
        {tabs.map((tab) => (
          <li key={tab.key} className="min-w-max text-center">
            <TabButton
              label={tab.label}
              setIsCurrent={() => setSearchParams({ tab: tab.key })}
              isCurrent={selectedTab === tab.key}
            />
          </li>
        ))}
        {/* New Button to the right */}
        <li className="ml-auto" onClick={() => navigate("/new")}>
          <button className="button-simple text-base font-semibold">Open new market</button>
        </li>
      </ul>

      {/* Content */}
      <div className="w-full">
        {selectedTab === "pools" ? <VoteList /> : selectedTab === "your_views" ? <BallotList/> : <UserVotes/>}
      </div>
    </div>
  );
};

export default Home;
