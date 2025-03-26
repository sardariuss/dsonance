import { useNavigate, useSearchParams } from "react-router-dom";
import { useEffect, useMemo, useRef, useState } from "react";
import LockChart from "../charts/LockChart";
import { protocolActor } from "../../actors/ProtocolActor";
import { useCurrencyContext } from "../CurrencyContext";
import BitcoinIcon from "../icons/BitcoinIcon";

import BallotRow from "./BallotRow";
import { useProtocolContext } from "../ProtocolContext";
import { useAuth } from "@ic-reactor/react";
import { Account, SBallotType } from "@/declarations/protocol/protocol.did";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../../constants";
import { toNullable } from "@dfinity/utils";
import AdaptiveInfiniteScroll from "../AdaptiveInfinitScroll";

type BallotEntries = {
  ballots: SBallotType[];
  previous: string | undefined;
  hasMore: boolean;
};

const BallotList = () => {
  
  const {login, identity} = useAuth();
  const [searchParams, setSearchParams] = useSearchParams();
  const ballotRefs = useRef<Map<string, (HTMLLIElement | null)>>(new Map());
  const [triggerScroll, setTriggerScroll] = useState(false);
  const navigate = useNavigate();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const [ballotEntries, setBallotEntries] = useState<BallotEntries>({ ballots: [], previous: undefined, hasMore: true });
  const [filterActive, setFilterActive] = useState(true);
  const limit = isMobile ? 8n : 10n;

  if (identity === null || identity?.getPrincipal().isAnonymous()) {
    return <div className="flex flex-col items-center bg-slate-50 dark:bg-slate-850 py-5 rounded-md w-full text-lg hover:cursor-pointer" onClick={() => login()}>
      Log in to see your ballots
    </div>;
  }

  const selectedBallotId = useMemo(() => searchParams.get("ballotId"), [searchParams]);

  const toggleBallot = (ballotId: string) => {
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
  }

  const selectBallot = (ballotId: string) => {
    setSearchParams((prevParams) => {
      const newParams = new URLSearchParams(prevParams);
      newParams.set("ballotId", ballotId);
      return newParams;
    });
  }

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

  const fetchNextBallots = () => {
    fetchBallots(account, ballotEntries, filterActive).then(setBallotEntries);
  }

  const { formatSatoshis } = useCurrencyContext();

  const { info, refreshInfo } = useProtocolContext();

  const { call: getBallots } = protocolActor.useQueryCall({
    functionName: "get_ballots",
  });

  const account : Account = useMemo(() => ({
    owner: identity?.getPrincipal(),
    subaccount: []
  }), [identity]);

  const { data: lockedAmount, call: refreshLockedAmount } = protocolActor.useQueryCall({
    functionName: "get_locked_amount",
    args: [{ account }],
  });

  useEffect(() => {
    refreshInfo();
    fetchBallots(account, ballotEntries, filterActive).then(setBallotEntries);
    refreshLockedAmount();
  }, []);

  const toggleFilterActive = (active: boolean) => {
    setFilterActive(active);
    fetchBallots(account, { ballots: [], previous: undefined, hasMore: true }, active).then(setBallotEntries);
  }

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
    <div className="flex flex-col items-center bg-slate-50 dark:bg-slate-850 p-2 rounded w-full">
      <div className="flex flex-row w-full space-x-1 justify-center items-baseline pt-5">
        <span>Total locked:</span>
        {
          lockedAmount !== undefined ?
          <div className="flex flex-row items-baseline space-x-1">
            <span className="text-lg">{ formatSatoshis(lockedAmount) }</span>
            <div className="flex self-center">
              <BitcoinIcon/>
            </div>
          </div>
            :
          <span className="w-12 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse self-center"/>
        }
      </div>
      { ballotEntries.ballots.length > 0 && 
        <div className="flex w-full py-8 sm:py-6">
          <LockChart ballots={ballotEntries.ballots} select_ballot={(id) => { setTriggerScroll(!triggerScroll); toggleBallot(id); }} selected={selectedBallotId}/>
        </div>
      }
      { ballotEntries.ballots.length > 0 && 
        <label className="inline-flex items-center me-5 cursor-pointer justify-self-end pb-5">
          <span className="mr-2 text-gray-900 dark:text-gray-100 truncate">Show unlocked</span>
          <input type="checkbox" value={(!filterActive).toString()} className="sr-only peer" onChange={(e) => toggleFilterActive(!filterActive)}/>
          <div className="relative w-11 h-6 bg-gray-200 rounded-full peer dark:bg-gray-700 peer-focus:ring-2 peer-focus:ring-purple-900 dark:peer-focus:ring-purple-900 peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-purple-900 dark:peer-checked:bg-purple-700"></div>
        </label>
      }
      <AdaptiveInfiniteScroll
        dataLength={ballotEntries.ballots.length}
        next={fetchNextBallots}
        hasMore={ballotEntries.hasMore}
        loader={<></>}
        className="w-full flex flex-col min-h-full overflow-auto"
        style={{ height: "auto", overflow: "visible" }}
      >
        <ul className="w-full flex flex-col gap-y-2">
          {
            /* Size of the header is 26 on mobile and 22 on desktop */
            ballotEntries.ballots.map((ballot, index) => (
              <li key={index} ref={(el) => (ballotRefs.current.set(ballot.YES_NO.ballot_id, el))} 
                className="w-full scroll-mt-[104px] sm:scroll-mt-[88px]" 
                onClick={(e) => { selectBallot(ballot.YES_NO.ballot_id); navigate(`/ballot/${ballot.YES_NO.ballot_id}`); }}>
                <BallotRow 
                  ballot={ballot}
                  now={info?.current_time}
                  selected={selectedBallotId === ballot.YES_NO.ballot_id}
                />
              </li>
            ))
          }
        </ul>
      </AdaptiveInfiniteScroll>
    </div>
  );
}

export default BallotList;