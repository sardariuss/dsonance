import { niceFormatDate, timeDifference, timeToDate } from "../../utils/conversions/date";
import { backendActor } from "../../actors/BackendActor";

import { MOBILE_MAX_WIDTH_QUERY, DSONANCE_COIN_SYMBOL } from "../../constants";
import { fromNullable } from "@dfinity/utils";
import { unwrapLock } from "../../utils/conversions/ballot";
import { useCurrencyContext } from "../CurrencyContext";
import { formatBalanceE8s } from "../../utils/conversions/token";
import ChoiceView from "../ChoiceView";
import ConsensusView from "../ConsensusView";
import BitcoinIcon from "../icons/BitcoinIcon";

import { SBallotType } from "@/declarations/protocol/protocol.did";
import DsonanceCoinIcon from "../icons/DsonanceCoinIcon";
import { compute_vote_details } from "../../utils/conversions/votedetails";
import { DesktopBallotDetails, MobileBallotDetails } from "./BallotDetails";
import { useMediaQuery } from "react-responsive";
import { useProtocolContext } from "../ProtocolContext";
import { useMemo } from "react";
import { useNavigate } from "react-router-dom";
import ChevronDownIcon from "../icons/ChevronDownIcon";
import ChevronUpIcon from "../icons/ChevronUpIcon";

interface VoteConsensusProps {
  is_selected: boolean;
  vote_id: string;
}

const VoteConsensus = ({ is_selected, vote_id }: VoteConsensusProps) => {
  
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
    vote === undefined || voteDetails === undefined ? 
      <span>Loading...</span> : is_selected ? 
        <ConsensusView voteDetails={voteDetails} text={vote.info.text} timestamp={vote.date} /> :
        <span className="truncate">{vote.info.text}</span>
  )
}

interface BallotProps {
  ballot: SBallotType;
  isSelected: boolean;
  selectBallot: () => void;
  now: bigint | undefined;
}

const BallotView = ({ ballot, isSelected, selectBallot, now }: BallotProps) => {

  const { formatSatoshis } = useCurrencyContext();
  const navigate = useNavigate();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const { releaseTimestamp, contribution, foresightAPR } = useMemo(() => {
      return {
        contribution: BigInt(Math.floor(ballot.YES_NO.contribution.current.data.earned)),
        foresightAPR: ballot.YES_NO.foresight.current.data.apr.potential * 100 / Number(ballot.YES_NO.amount),
        releaseTimestamp: ballot.YES_NO.timestamp + unwrapLock(ballot).duration_ns.current.data 
      }
    },
    [ballot]
  );

  return (
    now === undefined ? <></> :
    <div className="bg-slate-100 dark:bg-slate-900 hover:cursor-pointer w-full rounded-md shadow-md">
      <div className="grid grid-cols-[minmax(100px,1fr)_minmax(60px,auto)_minmax(60px,auto)_minmax(60px,auto)_minmax(60px,auto)_minmax(60px,auto)_minmax(60px,auto)] gap-10 w-full items-center pl-5">

        <div className="flex flex-row space-x-1" onClick={(e) => navigate(`/vote/${ballot.YES_NO.vote_id}`) }>
          <VoteConsensus vote_id={ballot.YES_NO.vote_id} is_selected={isSelected}/>
        </div>

        <div className="grid grid-rows-2 w-full justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">Vote</span>
          <ChoiceView ballot={ballot}/>
        </div>

        <div className="grid grid-rows-2 w-full justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">Lock</span>
          <span>{formatSatoshis(ballot.YES_NO.amount)}</span>
        </div>

        <div className="grid grid-rows-2 w-full justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">Contribution</span>
          <span>
            {formatBalanceE8s(contribution, DSONANCE_COIN_SYMBOL, 2)}
          </span>
        </div>

        <div className="grid grid-rows-2 w-full justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">APR</span>
          <span className="text-brand-true">
            {`${foresightAPR.toFixed(2)}%`}
          </span>
        </div>

        <div className="grid grid-rows-2 w-full justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">Time left</span>
          <span>
            {releaseTimestamp <= now ? 
              `expired` : 
              `${timeDifference(timeToDate(releaseTimestamp), timeToDate(now))}`
            }
          </span>
        </div>
        
        <div className="flex flex-col items-center justify-center bg-gray-100 dark:bg-gray-800 rounded-full p-1 w-8 h-8" onClick={(e) => { e.stopPropagation(); selectBallot(); }}>
          { isSelected ? <ChevronUpIcon /> : <ChevronDownIcon /> }
        </div>

      </div>

      { isSelected && (
          isMobile ? 
          <MobileBallotDetails ballot={ballot} now={now} releaseTimestamp={releaseTimestamp}/> :
          <DesktopBallotDetails ballot={ballot} now={now} releaseTimestamp={releaseTimestamp}/>
        )
      }
    </div>
  );
}

export default BallotView;