import { useCallback, useEffect, useState } from "react";
import { protocolActor } from "../actors/ProtocolActor";

import PoolRow from "./PoolRow";
import PositionRow from "./PositionRow";
import { useProtocolContext } from "../context/ProtocolContext";
import { useAuth } from "@nfid/identitykit/react";
import { Account, SBallotType } from "@/declarations/protocol/protocol.did";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../../constants";
import { toNullable } from "@dfinity/utils";
import { toAccount } from "@/frontend/utils/conversions/account";

type BallotEntries = {
  ballots: SBallotType[];
  previous: string | undefined;
  hasMore: boolean;
};

const PositionsTab = ({ user }: { user: NonNullable<ReturnType<typeof useAuth>["user"]> }) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const [ballotEntries, setBallotEntries] = useState<BallotEntries>({ ballots: [], previous: undefined, hasMore: true });
  const [filterActive, setFilterActive] = useState(true);
  const limit = isMobile ? 8n : 10n;

  const { info, refreshInfo } = useProtocolContext();

  const { call: getBallots } = protocolActor.unauthenticated.useQueryCall({
    functionName: "get_ballots",
    onError: (error) => {
      console.error("Error fetching ballots:", error);
    },
    onSuccess: (data) => {
      console.log("Fetched ballots:", data);
    }
  });

  const fetchBallots = async (account: Account, entries: BallotEntries, filter_active: boolean) : Promise<BallotEntries> => {

    const fetchedBallots = await getBallots([{
      account,
      previous: toNullable(entries.previous), 
      limit,
      filter_active,
    }]);

    if (fetchedBallots && fetchedBallots.length > 0) {
      const mergedBallots = [...entries.ballots, ...fetchedBallots];
      const uniqueBallots = Array.from(new Map(mergedBallots.map(v => [v.YES_NO.ballot_id, v])).values());
      const previous = fetchedBallots[fetchedBallots.length - 1].YES_NO.ballot_id;
      const hasMore = (fetchedBallots.length === Number(limit));
      return { ballots: uniqueBallots, previous, hasMore };
    } else {
      return { ballots: entries.ballots, previous: entries.previous, hasMore: false };
    }
  };

  useEffect(() => {
    refreshInfo();
    fetchBallots(toAccount(user), ballotEntries, filterActive).then(setBallotEntries);
  }, []);

  const toggleFilterActive = useCallback((active: boolean) => {
    setFilterActive(active);
    fetchBallots(toAccount(user), { ballots: [], previous: undefined, hasMore: true }, active).then(setBallotEntries);
  }, [user]);
  
  return (
    <div className="flex flex-col w-full bg-white dark:bg-slate-800 shadow-md rounded-md p-2 sm:p-4 border border-slate-300 dark:border-slate-700 space-y-4">
      {/* Filter Toggle */}
      <div className="flex justify-end">
        <div className="inline-flex rounded-md border border-gray-300 dark:border-gray-600 bg-gray-100 dark:bg-gray-700">
          <button
            className={`px-4 py-1.5 rounded-l-md text-sm font-medium transition-colors ${
              filterActive
                ? 'bg-white dark:bg-gray-800 text-gray-900 dark:text-white shadow-sm'
                : 'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'
            }`}
            onClick={() => toggleFilterActive(true)}
          >
            Locked
          </button>
          <button
            className={`px-4 py-1.5 rounded-r-md text-sm font-medium transition-colors ${
              !filterActive
                ? 'bg-white dark:bg-gray-800 text-gray-900 dark:text-white shadow-sm'
                : 'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'
            }`}
            onClick={() => toggleFilterActive(false)}
          >
            Resolved
          </button>
        </div>
      </div>
      {/* Layout: Fixed column + Scrollable section */}
      <div className="w-full flex">
        {/* Fixed Pool column */}
        <div className="flex-shrink-0 flex flex-col w-[200px] sm:w-[700px]">
          {/* Pool header */}
          <span className="pb-2 text-sm text-gray-500 dark:text-gray-500">POOL</span>
          {/* Pool data rows */}
          <ul className="flex flex-col gap-y-2">
            {ballotEntries.ballots.map((ballot, index) => (
              <li
                key={index}
                className="scroll-mt-[104px] sm:scroll-mt-[88px]"
              >
                <PoolRow ballot={ballot} />
              </li>
            ))}
          </ul>
        </div>

        {/* Scrollable columns section (header + data together) */}
        <div className="flex-1 overflow-x-auto">
          <div className="min-w-[260px] flex flex-col">
            {/* Scrollable header */}
            <div className="grid grid-cols-3 gap-2 sm:gap-4 pb-2">
              <span className="text-sm text-gray-500 dark:text-gray-500 text-right">DISSENT</span>
              <span className="text-sm text-gray-500 dark:text-gray-500 text-right">{filterActive ? "TIME LEFT" : "UNLOCKED"}</span>
              <span className="text-sm text-gray-500 dark:text-gray-500 text-right">VALUE</span>
            </div>
            {/* Scrollable data rows */}
            <ul className="flex flex-col gap-y-2">
              {ballotEntries.ballots.map((ballot, index) => (
                <li key={index}>
                  <PositionRow ballot={ballot} now={info?.current_time} />
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
};

export default PositionsTab;