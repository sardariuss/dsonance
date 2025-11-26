import { useCallback, useEffect, useMemo, useState } from "react";
import { protocolActor } from "../actors/ProtocolActor";

import PoolRow from "./PoolRow";
import PositionRow from "./PositionRow";
import { useProtocolContext } from "../context/ProtocolContext";
import { useAuth } from "@nfid/identitykit/react";
import { SPositionType } from "@/declarations/protocol/protocol.did";
import { toNullable } from "@dfinity/utils";
import { toAccount } from "@/frontend/utils/conversions/account";
import InfiniteScroll from "react-infinite-scroll-component";
import Spinner from "../Spinner";

type PositionEntries = {
  positions: SPositionType[];
  previous: string | undefined;
  hasMore: boolean;
};

const PositionsTab = ({ user }: { user: NonNullable<ReturnType<typeof useAuth>["user"]> }) => {

  const [positionEntries, setPositionEntries] = useState<PositionEntries>({ positions: [], previous: undefined, hasMore: true });
  const [filterActive, setFilterActive] = useState(true);
  const limit = 10n;
  const { refreshInfo } = useProtocolContext();

  const account = useMemo(() => toAccount(user), [user]);

  const { call: refreshPositions } = protocolActor.unauthenticated.useQueryCall({
    functionName: "get_positions",
    args: [{
      account,
      previous: toNullable(positionEntries.previous),
      limit,
      filter_active: filterActive,
      direction: { backward: null }
    }],
    onError: (error) => {
      console.error("Error fetching positions:", error);
    },
    onSuccess: (data) => {
      console.log("Fetched positions:", data);
      updatePositionEntries(data);
    }
  });

  const updatePositionEntries = (newPositions: SPositionType[]) => {
    setPositionEntries((prevEntries) => {
      const mergedPositions = [...prevEntries.positions, ...newPositions];
      const uniquePositions = Array.from(new Map(mergedPositions.map(v => [v.YES_NO.position_id, v])).values());
      const previous = newPositions.length > 0 ? newPositions[newPositions.length - 1].YES_NO.position_id : prevEntries.previous;
      const hasMore = newPositions.length === Number(limit);
      return { positions: uniquePositions, previous, hasMore };
    });
  };

  useEffect(() => {
    refreshInfo();
    refreshPositions();
  }, [user]);

  // Refetch when filter changes
  useEffect(() => {
    if (positionEntries.positions.length === 0 && positionEntries.previous === undefined) {
      refreshPositions();
    }
  }, [filterActive]);

  const toggleFilterActive = useCallback((active: boolean) => {
    setPositionEntries({ positions: [], previous: undefined, hasMore: true });
    setFilterActive(active);
  }, []);
  
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
      {positionEntries.positions.length === 0 ? (
        <div className="w-full text-center py-8 text-gray-500 dark:text-gray-400">
          No positions found.
        </div>
      ) : (
        <InfiniteScroll
          dataLength={positionEntries.positions.length}
          next={refreshPositions}
          hasMore={positionEntries.hasMore}
          loader={<Spinner size={"25px"} />}
          style={{ height: "auto", overflow: "visible" }}
        >
          <div className="w-full flex">
            {/* Fixed Pool column */}
            <div className="flex-shrink-0 flex flex-col w-[200px] sm:w-[700px]">
              {/* Pool header */}
              <span className="pb-2 text-sm text-gray-500 dark:text-gray-500">POOL</span>
              {/* Pool data rows */}
              <ul className="flex flex-col gap-y-2">
                {positionEntries.positions.map((position, index) => (
                  <li
                    key={index}
                    className="scroll-mt-[104px] sm:scroll-mt-[88px]"
                  >
                    <PoolRow position={position} />
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
                  {positionEntries.positions.map((position, index) => (
                    <li key={index}>
                      <PositionRow position={position} />
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          </div>
        </InfiniteScroll>
      )}
    </div>
  );
};

export default PositionsTab;