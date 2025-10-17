import { useNavigate, useSearchParams } from "react-router-dom";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { protocolActor } from "../actors/ProtocolActor";

import PoolRow from "./PoolRow";
import PositionRow from "./PositionRow";
import { useProtocolContext } from "../context/ProtocolContext";
import { useAuth } from "@nfid/identitykit/react";
import { Account, SBallotType } from "@/declarations/protocol/protocol.did";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../../constants";
import { toNullable } from "@dfinity/utils";
import AdaptiveInfiniteScroll from "../AdaptiveInfinitScroll";
import IntervalPicker from "../charts/IntervalPicker";
import { DurationUnit } from "../../utils/conversions/durationUnit";
import LockChart from "../charts/LockChart";
import { toAccount } from "@/frontend/utils/conversions/account";
import LoginIcon from "../icons/LoginIcon";

type BallotEntries = {
  ballots: SBallotType[];
  previous: string | undefined;
  hasMore: boolean;
};

const PositionsTab = ({ user }: { user: NonNullable<ReturnType<typeof useAuth>["user"]> }) => {

  const [searchParams, setSearchParams] = useSearchParams();
  const ballotRefs = useRef<Map<string, (HTMLLIElement | null)>>(new Map());
  const [triggerScroll, setTriggerScroll] = useState(false);
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const [ballotEntries, setBallotEntries] = useState<BallotEntries>({ ballots: [], previous: undefined, hasMore: true });
  const [filterActive, setFilterActive] = useState(true);
  const limit = isMobile ? 8n : 10n;
  const [duration, setDuration] = useState<DurationUnit | undefined>(DurationUnit.MONTH);

  const selectedBallotId = useMemo(() => searchParams.get("ballotId"), [searchParams]);

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

  const toggleBallot = useCallback((ballotId: string) => {
    setSearchParams((prevParams) => {
      const newParams = new URLSearchParams(prevParams);
      if (selectedBallotId === ballotId) {
        // Remove voteId if it's already selected
        newParams.delete("ballotId");
      } else {
        // Set voteId if it's not selected
        newParams.set("ballotId", ballotId);
      }
      return newParams;
    });
  }, [selectedBallotId, setSearchParams]);

  const fetchBallots = async (account: Account, entries: BallotEntries, filter_active: boolean) : Promise<BallotEntries> => {

    console.log("Account owner:", account.owner.toText());

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

  const fetchNextBallots = useCallback(() => {
    fetchBallots(toAccount(user), ballotEntries, filterActive).then(setBallotEntries);
  }, [user, ballotEntries, filterActive]);

  useEffect(() => {
    refreshInfo();
    fetchBallots(toAccount(user), ballotEntries, filterActive).then(setBallotEntries);
  }, []);

  const toggleFilterActive = useCallback((active: boolean) => {
    setFilterActive(active);
    fetchBallots(toAccount(user), { ballots: [], previous: undefined, hasMore: true }, active).then(setBallotEntries);
  }, [user]);

  useEffect(() => {
    if (ballotEntries.ballots.length > 0 && selectedBallotId !== null) {
      const ballotElement = ballotRefs.current.get(selectedBallotId);
      
      if (ballotElement) {
        setTimeout(() => {
          ballotElement.scrollIntoView({
            behavior: "smooth",
            block: "start",
          });
        }, 50);
      }
    }
  }, [triggerScroll, ballotEntries]);
  
  return (
    <div className="flex flex-col w-full bg-white dark:bg-slate-800 shadow-md rounded-md p-2 sm:p-4 md:p-6 border border-slate-300 dark:border-slate-700 space-y-4">
      {/* Layout: Fixed column + Scrollable section */}
      <div className="w-full flex">
        {/* Fixed Pool column */}
        <div className="flex-shrink-0 flex flex-col w-[200px] sm:w-[700px]">
          {/* Pool header */}
          <div className="px-2 sm:px-3 pb-2">
            <span className="text-sm text-gray-500 dark:text-gray-500">POOL</span>
          </div>
          {/* Pool data rows */}
          <ul className="flex flex-col gap-y-2">
            {ballotEntries.ballots.map((ballot, index) => (
              <li
                key={index}
                ref={(el) => {
                  ballotRefs.current.set(ballot.YES_NO.ballot_id, el);
                }}
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
              <span className="text-sm text-gray-500 dark:text-gray-500 text-right">TIME LEFT</span>
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