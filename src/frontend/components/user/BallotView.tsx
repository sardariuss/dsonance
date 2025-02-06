import { niceFormatDate, timeDifference, timeToDate } from "../../utils/conversions/date";
import { backendActor } from "../../actors/BackendActor";

import { MOBILE_MAX_WIDTH_QUERY, DSONANCE_TOKEN_SYMBOL } from "../../constants";
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

  const releaseTimestamp = ballot.YES_NO.timestamp + (unwrapLock(ballot).duration_ns).current.data;

  const onVoteClick = () => {
    if (isSelected) {
      navigate(`/vote/${ballot.YES_NO.vote_id}`);
    } else {
      selectBallot();
    }
  }

  return (
    now === undefined ? <></> :
    <div className="border-b dark:border-gray-700 border-gray-300 py-2 px-2 hover:bg-slate-50 dark:hover:bg-slate-850 hover:cursor-pointer w-full">
      <div className="flex flex-col w-full" onClick={() => selectBallot() }>
        <div className="flex flex-row space-x-1 items-baseline">
          <span>{formatSatoshis(ballot.YES_NO.amount)}</span>
          <div className="flex self-center h-4 w-4">
            <BitcoinIcon/>
          </div>
          <span className="text-gray-600 dark:text-gray-400 text-sm">on</span>
          <ChoiceView ballot={ballot}/>
          <span className="text-gray-600 dark:text-gray-400 text-sm">{" · "}</span>
          <span className="text-gray-600 dark:text-gray-400 text-sm">
            {releaseTimestamp <= now ? 
              `${niceFormatDate(timeToDate(releaseTimestamp), timeToDate(now))}` : 
              `${timeDifference(timeToDate(releaseTimestamp), timeToDate(now))} left`
            }
          </span>
        </div>

        <div className="flex flex-row space-x-1 items-baseline">
          { releaseTimestamp <= now ?
            <div className="flex flex-row space-x-1 items-baseline">
              <span>{formatBalanceE8s(BigInt(Math.floor(ballot.YES_NO.rewards.current.data.participation + ballot.YES_NO.rewards.current.data.discernment)), DSONANCE_TOKEN_SYMBOL, 2)}</span>
            </div> :
            <div className="flex flex-row space-x-1 items-baseline">
              <span>{formatBalanceE8s(BigInt(Math.floor(ballot.YES_NO.rewards.current.data.participation)), DSONANCE_TOKEN_SYMBOL, 2)}</span>
              <span className="italic text-gray-600 dark:text-gray-400 animate-pulse">{`+ ${formatBalanceE8s(BigInt(Math.floor(ballot.YES_NO.rewards.current.data.discernment)), DSONANCE_TOKEN_SYMBOL, 2)}`}</span>
            </div>
          }
          <div className="flex self-center h-4 w-4">
            <DsonanceCoinIcon/>
          </div>
        </div>

        <div className="flex flex-row space-x-1 items-top w-full justify-between grow" onClick={(e) => { e.stopPropagation(); onVoteClick(); } }>
          <VoteConsensus vote_id={ballot.YES_NO.vote_id} is_selected={isSelected}/>
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