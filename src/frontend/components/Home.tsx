import { useNavigate, useSearchParams } from "react-router-dom";
import { useEffect } from "react";
import { TabButton } from "./TabButton";
import VoteList from "./VoteList";
import BallotList from "./user/BallotList";
import { useAuth } from "@ic-reactor/react";
import { Principal } from "@dfinity/principal";

const Home = () => {

  const { identity } = useAuth();
  const navigate = useNavigate();

  const [searchParams, setSearchParams] = useSearchParams();
  const tabs = [
    { key: "votes", label: "Browse statements" },
    { key: "ballots", label: "Your participations" },
  ];

  // Get the current tab or default to "votes"
  let selectedTab = searchParams.get("tab") || "votes";

  // Ensure the tab is valid, otherwise reset to "votes"
  useEffect(() => {
    if (!tabs.some(tab => tab.key === selectedTab)) {
      setSearchParams({ tab: "votes" }, { replace: true });
    }
  }, [selectedTab, setSearchParams]);

  return (
    <div className="flex flex-col w-full sm:w-4/5 md:w-3/4 lg:w-2/3 my-4">
      {/* Tabs */}
      <ul className="flex flex-row w-full gap-x-6 my-6 items-center">
        {tabs.map((tab) => (
          <li key={tab.key} className="text-center">
            <TabButton
              label={tab.label}
              setIsCurrent={() => setSearchParams({ tab: tab.key })}
              isCurrent={selectedTab === tab.key}
            />
          </li>
        ))}
        {/* New Button to the right */}
        <li className="ml-auto" onClick={() => navigate("/new")}>
          <button className="button-simple text-lg">Open new statement</button>
        </li>
      </ul>

      {/* Content */}
      <div className="w-full">
        {selectedTab === "votes" ? <VoteList /> : <BallotList principal={identity?.getPrincipal() ?? Principal.anonymous() }/>}
      </div>
    </div>
  );
};

export default Home;
