import { Principal } from "@dfinity/principal";
import { Link, useParams, useSearchParams } from "react-router-dom";
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
import { Account } from "@/declarations/ck_btc/ck_btc.did";
import { fromNullable, uint8ArrayToHexString } from "@dfinity/utils";
import LogoutIcon from "../icons/LogoutIcon";

const accountToString = (account: Account | undefined) : string =>  {
  let str = "";
  if (account !== undefined) {
    str = account.owner.toString();
    let subaccount = fromNullable(account.subaccount);
    if (subaccount !== undefined) {
      str += " " + uint8ArrayToHexString(subaccount); 
    }
  }
  return str;
}

const User = () => {
  
  const { principal } = useParams();
  const { identity, logout } = useAuth();
  const [searchParams, setSearchParams] = useSearchParams();
  const ballotRefs = useRef<Map<string, (HTMLLIElement | null)>>(new Map());
  const [triggerScroll, setTriggerScroll] = useState(false);
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  if (!principal || !identity) {
    return <div>Invalid principal</div>;
  }
  
  const account : Account = useMemo(() => ({
    owner: identity?.getPrincipal(),
    subaccount: []
  }), [identity]);
  
  const [copied, setCopied] = useState(false);
  const handleCopy = () => {
    navigator.clipboard.writeText(accountToString(account));
    setCopied(true);
    setTimeout(() => setCopied(false), 2000); // Hide tooltip after 2 seconds
  };

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
    <div className="flex flex-col gap-y-2 items-center bg-slate-50 dark:bg-slate-850 p-2 my-4 rounded-md w-full sm:w-4/5 md:w-3/4 lg:w-2/3">
      <div className="relative group">
        <div className="flex flex-row items-center space-x-2">
          <span
            className="text-gray-800 hover:text-black dark:text-gray-200 dark:hover:text-white font-medium self-center hover:cursor-pointer"
            onClick={handleCopy}
          >
            {accountToString(account)}
          </span>
          { identity.getPrincipal().toString() === principal && 
            <Link 
              className="self-end fill-gray-800 hover:fill-black dark:fill-gray-200 dark:hover:fill-white p-2.5 rounded-lg hover:cursor-pointer"
              onClick={()=>{logout()}}
              to="/">
              <LogoutIcon />
            </Link>
          }
        </div>
        { copied && (
          <div
            className={`absolute -top-6 left-1/2 z-50 transform -translate-x-1/2 bg-white text-black text-xs rounded px-2 py-1 transition-opacity duration-500 ${
              copied ? "opacity-100" : "opacity-0"
            }`}
          >
            Copied!
          </div>
        )}
      </div>
      {
        !identity.getPrincipal().isAnonymous() && identity.getPrincipal().toString() === principal &&
          <div className="flex flex-col items-center w-full bg-slate-100 dark:bg-slate-900 rounded-md shadow-md">
            <Wallet/>
          </div>
      }
      {
        isMobile && 
          <div className="flex flex-row justify-center w-full bg-slate-100 dark:bg-slate-900 rounded-md shadow-md">
            <CurrencyConverter/>
            <ThemeToggle/>
          </div>
      }
      { ballots && ballots?.length > 0 && 
        <div className="flex flex-col items-center w-full bg-slate-100 dark:bg-slate-900 rounded-md shadow-md py-2">
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
      { ballots && ballots?.length > 0 && 
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
      }
    </div>
  );
}

export default User;