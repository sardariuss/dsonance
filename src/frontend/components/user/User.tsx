import { Principal } from "@dfinity/principal";
import { useParams, useSearchParams } from "react-router-dom";
import { useEffect, useMemo, useRef, useState } from "react";
import LockChart from "../charts/LockChart";
import { protocolActor } from "../../actors/ProtocolActor";
import Wallet from "../Wallet";
import { useCurrencyContext } from "../CurrencyContext";
import BitcoinIcon from "../icons/BitcoinIcon";

import BallotView from "./BallotView";
import { unwrapLock } from "../../utils/conversions/ballot";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../../../frontend/constants";
import CurrencyConverter from "../CurrencyConverter";
import ThemeToggle from "../ThemeToggle";
import { useAuth } from "@ic-reactor/react";
import { useProtocolContext } from "../ProtocolContext";

const User = () => {
  
  const { principal } = useParams();
  const { identity } = useAuth();
  const [searchParams, setSearchParams] = useSearchParams();
  const ballotRefs = useRef<Map<string, (HTMLLIElement | null)>>(new Map());
  const [triggerScroll, setTriggerScroll] = useState(false);
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  if (!principal || !identity) {
    return <div>Invalid principal</div>;
  }

//  if (principal !== identity.getPrincipal().toString()) {
//    return <div>Unauthorized</div>;
//  }

  const selectedBallotId = useMemo(() => searchParams.get("ballotId"), [searchParams]);

  const selectBallot = (ballotId: string | null) => {
    setSearchParams(ballotId ? { ballotId: ballotId } : {});
  }

  const { formatSatoshis } = useCurrencyContext();

  const { info, refreshInfo } = useProtocolContext();

  const { data: ballots, call: refreshBallots } = protocolActor.useQueryCall({
    functionName: "get_ballots",
    args: [{ owner: Principal.fromText(principal), subaccount: [] }],
  });

  useEffect(() => {
    refreshInfo();
    refreshBallots();
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
    <div className="flex flex-col gap-y-2 items-center bg-slate-50 dark:bg-slate-850 px-2 rounded-md w-full sm:w-4/5 md:w-3/4 lg:w-2/3">
      <div className="flex flex-col items-center w-full bg-slate-100 dark:bg-slate-900 rounded-md shadow-md">
        <Wallet/>
      </div>
      {
        isMobile && 
          <div className="flex flex-row justify-center w-full bg-slate-100 dark:bg-slate-900 rounded-md shadow-md">
            <CurrencyConverter/>
            <ThemeToggle/>
          </div>
      }
      { ballots && ballots?.length > 0 && 
        <div className="flex flex-col items-center w-full bg-slate-100 dark:bg-slate-900 rounded-md shadow-md">
          <div className="flex flex-row w-full space-x-1 justify-center items-baseline">
            <span>Total locked:</span>
            <span className="text-lg">{ totalLocked !== undefined ? formatSatoshis(totalLocked) : "N/A" }</span>
            <div className="flex self-center">
              <BitcoinIcon/>
            </div>
          </div>
          <LockChart ballots={ballots} select_ballot={(id) => { setTriggerScroll(!triggerScroll); selectBallot(id); }} selected={selectedBallotId}/>
        </div>
      }
      <ul className="w-full flex flex-col gap-y-2">
        {
          /* Size of the header is 26 on mobile and 22 on desktop */
          ballots?.map((ballot, index) => (
            <li key={index} ref={(el) => (ballotRefs.current.set(ballot.YES_NO.ballot_id, el))} className="w-full scroll-mt-[104px] sm:scroll-mt-[88px]"> 
              <BallotView 
                ballot={ballot}
                isSelected={selectedBallotId === ballot.YES_NO.ballot_id}
                selectBallot={() => selectBallot(selectedBallotId === ballot.YES_NO.ballot_id ? null : ballot.YES_NO.ballot_id)}
                now={info?.current_time}
              />
            </li>
          ))
        }
      </ul>
    </div>
  );
}

export default User;