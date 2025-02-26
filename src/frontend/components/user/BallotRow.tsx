import { timeDifference, timeToDate } from "../../utils/conversions/date";
import { backendActor } from "../../actors/BackendActor";

import { DSONANCE_COIN_SYMBOL, MOBILE_MAX_WIDTH_QUERY } from "../../constants";
import { fromNullable } from "@dfinity/utils";
import { unwrapLock } from "../../utils/conversions/ballot";
import { useCurrencyContext } from "../CurrencyContext";
import { formatBalanceE8s } from "../../utils/conversions/token";
import ChoiceView from "../ChoiceView";

import { SBallotType } from "@/declarations/protocol/protocol.did";
import { compute_vote_details } from "../../utils/conversions/votedetails";
import { useProtocolContext } from "../ProtocolContext";
import { useMemo } from "react";
import { useNavigate } from "react-router-dom";
import { toEnum } from "../../utils/conversions/yesnochoice";
import { useMediaQuery } from "react-responsive";

interface VoteTextProps {
  vote_id: string;
}

const VoteText = ({ vote_id }: VoteTextProps) => {
  
  const { data: opt_vote } = backendActor.useQueryCall({
    functionName: "get_vote",
    args: [{ vote_id }],
  });

  const { computeDecay } = useProtocolContext();
  
  const vote = useMemo(() => {
    return opt_vote ? fromNullable(opt_vote) : undefined;
  }, [opt_vote]);

  const voteDetails = useMemo(() => {
    if (vote === undefined || computeDecay === undefined) {
      return undefined;
    }
    return compute_vote_details(vote, computeDecay);
  }, [vote, computeDecay]);

  return (
    <div className="flex items-center h-[4.5em] sm:h-[3em]">
      <span className="line-clamp-3 sm:line-clamp-2 overflow-hidden">
        { vote === undefined || voteDetails === undefined ? "Loading..." : vote.info.text}
      </span>
    </div>
  )
}

interface BallotProps {
  ballot: SBallotType;
  now: bigint | undefined;
}

const BallotRow = ({ ballot, now }: BallotProps) => {

  const { formatSatoshis } = useCurrencyContext();
  const navigate = useNavigate();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const { releaseTimestamp, contribution, foresightAPR } = useMemo(() => {
      return {
        contribution: BigInt(Math.floor(ballot.YES_NO.contribution.current.data.earned)),
        foresightAPR: ballot.YES_NO.foresight.current.data.apr.current,
        releaseTimestamp: ballot.YES_NO.timestamp + unwrapLock(ballot).duration_ns.current.data 
      }
    },
    [ballot]
  );

  return (
    now === undefined ? <></> :
    <div 
      className="rounded-lg p-2 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800 hover:cursor-pointer"
      onClick={(e) => navigate(`/ballot/${ballot.YES_NO.ballot_id}`)}
    >
      <div className={`grid ${isMobile ? "grid-cols-[minmax(100px,1fr)_repeat(1,minmax(60px,auto))]" : "grid-cols-[minmax(100px,1fr)_repeat(5,minmax(60px,auto))]"} gap-2 sm:gap-x-8 w-full items-center px-2 sm:px-3`}>

        <VoteText vote_id={ballot.YES_NO.vote_id}/>

        { !isMobile && <div className="grid grid-rows-2 w-full justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">Time left</span>
          <span>
            {releaseTimestamp <= now ? 
              `expired` : 
              `${timeDifference(timeToDate(releaseTimestamp), timeToDate(now))}`
            }
          </span>
        </div> }

        { !isMobile && <div className="grid grid-rows-2 w-full justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">Amount</span>
          <span>{formatSatoshis(ballot.YES_NO.amount)}</span>
        </div> }

        { !isMobile && <div className="grid grid-rows-2 w-full justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">Choice</span>
          <ChoiceView choice={toEnum(ballot.YES_NO.choice)}/>
        </div> }

        { !isMobile && <div className="grid grid-rows-2 w-full justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">Mining earned</span>
          <span>
            {formatBalanceE8s(contribution, DSONANCE_COIN_SYMBOL, 2)}
          </span>
        </div> }

        <div className="grid grid-rows-2 w-full justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">APR</span>
          <span className="font-semibold [text-shadow:0px_0px_10px_rgb(59,130,246)]">
            {`${foresightAPR.toFixed(2)}%`}
          </span>
        </div>

      </div>

    </div>
  );
}

export default BallotRow;