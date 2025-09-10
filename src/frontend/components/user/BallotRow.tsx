import { timeDifference, timeToDate } from "../../utils/conversions/date";
import { backendActor } from "../actors/BackendActor";

import { MOBILE_MAX_WIDTH_QUERY } from "../../constants";
import { fromNullable } from "@dfinity/utils";
import { unwrapLock } from "../../utils/conversions/ballot";
import ChoiceView from "../ChoiceView";

import { SBallotType } from "@/declarations/protocol/protocol.did";
import { compute_vote_details } from "../../utils/conversions/votedetails";
import { useProtocolContext } from "../context/ProtocolContext";
import { useMemo } from "react";
import { toEnum } from "../../utils/conversions/yesnochoice";
import { useMediaQuery } from "react-responsive";
import { SYesNoVote } from "@/declarations/backend/backend.did";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";
import { createThumbnailUrl } from "../../utils/thumbnail";
import { aprToApy } from "../../utils/lending";

interface VoteTextProps {
  vote: SYesNoVote | undefined;
}

const VoteText = ({ vote }: VoteTextProps) => {

  const { computeDecay, info } = useProtocolContext();

  const voteDetails = useMemo(() => {
    if (vote === undefined || computeDecay === undefined || info === undefined) {
      return undefined;
    }
    return compute_vote_details(vote, computeDecay(info.current_time));
  }, [vote, computeDecay]);

  return (
    <div className="flex items-center h-[4.5em] sm:h-[3em]">
      { vote === undefined || voteDetails === undefined ? 
        <span className="w-full h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"/> :
        <span className="line-clamp-3 sm:line-clamp-2 overflow-hidden"> {vote.info.text} </span>
      }
    </div>
  )
}

interface BallotProps {
  ballot: SBallotType;
  now: bigint | undefined;
  selected: boolean;
}

const BallotRow = ({ ballot, now, selected }: BallotProps) => {

  const { supplyLedger: { formatAmountUsd } } = useFungibleLedgerContext();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const { releaseTimestamp, foresightAPR } = useMemo(() => {

      return {
        foresightAPR: ballot.YES_NO.foresight.apr.current,
        releaseTimestamp: ballot.YES_NO.timestamp + unwrapLock(ballot.YES_NO).duration_ns.current.data 
      }
    },
    [ballot]
  );

  const { data: opt_vote } = backendActor.unauthenticated.useQueryCall({
    functionName: "get_vote",
    args: [{ vote_id: ballot.YES_NO.vote_id }],
  });

  const vote = useMemo(() => {
    return opt_vote ? fromNullable(opt_vote) : undefined;
  }, [opt_vote]);

  const thumbnailUrl = useMemo(() => {
    if (vote === undefined) {
      return undefined;
    }
    return createThumbnailUrl(vote.info.thumbnail)
  }, [vote]);

  return (
    now === undefined ? <></> :
    <div className={`rounded-lg p-2 shadow-sm bg-slate-200 dark:bg-gray-800 hover:cursor-pointer w-full ${ selected ? "border-2 dark:border-gray-500 border-gray-500" : "border dark:border-gray-700 border-gray-300"}`}>
      <div className={`grid ${isMobile ? "grid-cols-[auto_minmax(100px,1fr)_repeat(1,minmax(60px,auto))]" : "grid-cols-[auto_minmax(100px,1fr)_repeat(4,minmax(60px,auto))]"} gap-2 gap-x-2 sm:gap-x-4 w-full items-center px-2 sm:px-3`}>

        {/* Thumbnail Image */}
        <img 
          className="w-10 h-10 min-w-10 min-h-10 bg-contain bg-no-repeat bg-center rounded-md" 
          src={thumbnailUrl}
          alt="Vote Thumbnail"
        />

        <VoteText vote={vote}/>

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
          <span>{formatAmountUsd(ballot.YES_NO.amount)}</span>
        </div> }

        { !isMobile && <div className="grid grid-rows-2 w-full justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">Choice</span>
          <ChoiceView choice={toEnum(ballot.YES_NO.choice)}/>
        </div> }

        <div className="grid grid-rows-2 w-full justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">APY</span>
          <span className="font-semibold">
            {`${(aprToApy(foresightAPR) * 100).toFixed(2)}%`}
          </span>
        </div>

      </div>

    </div>
  );
}

export default BallotRow;