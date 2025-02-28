import { useNavigate, useSearchParams } from "react-router-dom";
import { useEffect, useMemo, useRef, useState } from "react";
import LockChart from "../charts/LockChart";
import { protocolActor } from "../../actors/ProtocolActor";
import { useCurrencyContext } from "../CurrencyContext";
import BitcoinIcon from "../icons/BitcoinIcon";

import BallotRow from "./BallotRow";
import { unwrapLock } from "../../utils/conversions/ballot";
import { useProtocolContext } from "../ProtocolContext";
import { useAuth } from "@ic-reactor/react";
import { SBallotType } from "@/declarations/protocol/protocol.did";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../../constants";
import { toNullable } from "@dfinity/utils";
import InfiniteScroll from "react-infinite-scroll-component";

const BallotList = () => {
  
  const {login, identity} = useAuth();
  const [searchParams, setSearchParams] = useSearchParams();
  const ballotRefs = useRef<Map<string, (HTMLLIElement | null)>>(new Map());
  const [triggerScroll, setTriggerScroll] = useState(false);
  const navigate = useNavigate();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const [ballots, setBallots] = useState<SBallotType[]>([]);
  const [previous, setPrevious] = useState<string | undefined>(undefined);
  const [hasMore, setHasMore] = useState(true);
  const limit = isMobile ? 8n : 10n;

  if (identity === null || identity?.getPrincipal().isAnonymous()) {
    return <div className="flex flex-col items-center bg-slate-50 dark:bg-slate-850 py-5 rounded-md w-full text-lg hover:cursor-pointer" onClick={() => login()}>
      Log in to see your ballots
    </div>;
  }

  const selectedBallotId = useMemo(() => searchParams.get("ballotId"), [searchParams]);

  const selectBallot = (ballotId: string) => {
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

  const fetchAndSetBallots = async () => {

    const fetchedBallots = await fetchBallots([{
      account: { owner: identity.getPrincipal(), subaccount: [] },
      previous: toNullable(previous), 
      limit 
    }]);

    if (fetchedBallots && fetchedBallots.length > 0) {
      setBallots((prevBallots) => {
        const mergedBallots = [...prevBallots, ...fetchedBallots];
        const uniqueBallots = Array.from(new Map(mergedBallots.map(v => [v.YES_NO.ballot_id, v])).values());
        return uniqueBallots;
      });

      setPrevious(fetchedBallots[fetchedBallots.length - 1].YES_NO.ballot_id);
    } else {
      setHasMore(false);
    }
  };  

  const { formatSatoshis } = useCurrencyContext();

  const { info, refreshInfo } = useProtocolContext();

  const { call: fetchBallots } = protocolActor.useQueryCall({
    functionName: "get_ballots",
  });

  useEffect(() => {
    refreshInfo();
    fetchAndSetBallots();
  }, []);

  const totalLocked = info && ballots?.reduce((acc, ballot) =>
    acc + ((ballot.YES_NO.timestamp + unwrapLock(ballot).duration_ns.current.data) > info.current_time ? ballot.YES_NO.amount : 0n)
  , 0n);

  useEffect(() => {
    if (ballots && selectedBallotId !== null) {
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
  }, [triggerScroll, ballots]);
  
  return (
    <>
      {
      ballots !== undefined && ( !hasMore && ballots.length === 0 ?
        <div className="text-center bg-slate-50 dark:bg-slate-850 p-2 rounded-md w-full">
          After you vote, your ballots will appear here.
        </div>
      : ( ballots.length > 0 && 
        <div className="flex flex-col items-center bg-slate-50 dark:bg-slate-850 p-2 rounded w-full">
          <div className="flex flex-col items-center w-full pt-5 pb-2">
            <div className="flex flex-row w-full space-x-1 justify-center items-baseline">
              <span>Total locked:</span>
              <span className="text-lg">{ totalLocked !== undefined ? formatSatoshis(totalLocked) : "N/A" }</span>
              <div className="flex self-center">
                <BitcoinIcon/>
              </div>
            </div>
            <LockChart ballots={ballots} select_ballot={(id) => { setTriggerScroll(!triggerScroll); selectBallot(id); }} selected={selectedBallotId}/>
          </div>
          <InfiniteScroll
            dataLength={ballots.length}
            next={fetchAndSetBallots}
            hasMore={hasMore}
            loader={<></>}
            className="w-full flex flex-col min-h-full overflow-auto"
            style={{ height: "auto", overflow: "visible" }}
          >
            <ul className="w-full flex flex-col gap-y-2">
              {
                /* Size of the header is 26 on mobile and 22 on desktop */
                ballots?.map((ballot, index) => (
                  <li key={index} ref={(el) => (ballotRefs.current.set(ballot.YES_NO.ballot_id, el))} 
                    className="w-full scroll-mt-[104px] sm:scroll-mt-[88px]" 
                    onClick={(e) => { selectBallot(ballot.YES_NO.ballot_id); navigate(`/ballot/${ballot.YES_NO.ballot_id}`); }}>
                    <BallotRow 
                      ballot={ballot}
                      now={info?.current_time}
                    />
                  </li>
                ))
              }
            </ul>
          </InfiniteScroll>
        </div>
      ))}
      </>
  );
}

export default BallotList;