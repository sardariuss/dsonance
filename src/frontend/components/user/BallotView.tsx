import { formatDuration } from "../../utils/conversions/duration";
import { dateToTime, niceFormatDate, nsToMs, timeDifference, timeToDate } from "../../utils/conversions/date";
import { backendActor } from "../../actors/BackendActor";

import { useEffect, useState } from "react";
import { LOCK_EMOJI, RESONANCE_TOKEN_SYMBOL, CONSENT_EMOJI, PARTICIPATION_EMOJI, DISCERNMENT_EMOJI, TIMESTAMP_EMOJI, DISSENT_EMOJI } from "../../constants";
import { get_current, map_timeline, to_number_timeline } from "../../utils/timeline";
import DurationChart, { CHART_COLORS } from "../charts/DurationChart";
import { fromNullable } from "@dfinity/utils";
import { unwrapLock } from "../../utils/conversions/ballot";
import { useCurrencyContext } from "../CurrencyContext";
import { formatBalanceE8s } from "../../utils/conversions/token";
import ChoiceView from "../ChoiceView";
import ConsensusView from "../ConsensusView";
import DateSpan from "../DateSpan";
import BitcoinIcon from "../icons/BitcoinIcon";

import 'katex/dist/katex.min.css';
import { InlineMath } from "react-katex";
import { SBallotType } from "@/declarations/protocol/protocol.did";
import { protocolActor } from "../../actors/ProtocolActor";
import ResonanceCoinIcon from "../icons/ResonanceCoinIcon";

interface VoteConsensusProps {
  vote_id: string;
}

const VoteConsensus = ({ vote_id }: VoteConsensusProps) => {
  
  const { data: opt_vote } = backendActor.useQueryCall({
    functionName: "get_vote",
    args: [{ vote_id }],
  });

  const vote = opt_vote ? fromNullable(opt_vote) : undefined;
  if (!vote) {
    return <div>Invalid vote</div>;
  }

  return <ConsensusView vote={vote} />;
}

interface BallotProps {
  ballot: SBallotType;
  isSelected: boolean;
  selectBallot: () => void;
}

const BallotView = ({ ballot, isSelected, selectBallot }: BallotProps) => {

  const { formatSatoshis } = useCurrencyContext();

  const { call: refreshNow, data: now } = protocolActor.useQueryCall({
      functionName: "get_time",
  });
  
  useEffect(() => {
    refreshNow();
  }, [ballot]);

  const releaseTimestamp = ballot.YES_NO.timestamp + (unwrapLock(ballot).duration_ns).current.data;

  return (
    now === undefined ? <></> :
    <div
      className="border-b dark:border-gray-700 border-gray-200 py-2 px-2 hover:bg-slate-50 dark:hover:bg-slate-850 hover:cursor-pointer"
      onClick={() => selectBallot()}
    >
      
      <div className="flex flex-row space-x-1 items-baseline">
        <span>{formatSatoshis(ballot.YES_NO.amount)}</span>
        <div className="flex self-center h-4 w-4">
          <BitcoinIcon/>
        </div>
        <span className="text-gray-400 text-sm">on</span>
        <ChoiceView ballot={ballot}/>
        <span className="text-gray-400 text-sm">{" · "}</span>
        <span className="text-gray-400 text-sm">
          {releaseTimestamp <= now ? 
            `${niceFormatDate(timeToDate(releaseTimestamp), timeToDate(now))}` : 
            `${timeDifference(timeToDate(releaseTimestamp), timeToDate(now))} left`
          }
        </span>
      </div>

      <div className="flex flex-row space-x-1 items-baseline">
        <span>{formatBalanceE8s(BigInt(Math.floor(ballot.YES_NO.rewards.current.data.participation)), RESONANCE_TOKEN_SYMBOL)}</span>
        <span className="italic text-gray-400 animate-pulse">{`+ ${formatBalanceE8s(BigInt(Math.floor(ballot.YES_NO.rewards.current.data.discernment)), RESONANCE_TOKEN_SYMBOL)}`}</span>
        <div className="flex self-center h-4 w-4">
          <ResonanceCoinIcon/>
        </div>
      </div>

      <VoteConsensus vote_id={ballot.YES_NO.vote_id}/>

      { isSelected && 
        <div className="grid grid-cols-2 gap-x-2 gap-y-2 justify-items-center w-full mt-4">

          <div className="flex flex-row space-x-1 items-baseline justify-center w-full border border-gray-800">
            <span>{TIMESTAMP_EMOJI}</span>
            <span className="italic text-gray-400 text-sm">Locked:</span> 
            <span>{niceFormatDate(timeToDate(ballot.YES_NO.timestamp), timeToDate(now)) }</span>
          </div>

          <div className="flex flex-row space-x-1 items-baseline justify-center w-full border border-gray-800">
            <span>{DISSENT_EMOJI}</span>
            <span className="italic text-gray-400 text-sm">Dissent:</span> 
            <span>{ ballot.YES_NO.dissent.toFixed(3) }</span>
          </div>

          <div className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-800">
            <div className="flex flex-row space-x-1 items-baseline">
              <span>{LOCK_EMOJI}</span>
              <span className="italic text-gray-400 text-sm">Duration:</span> 
              <span>{formatDuration(ballot.YES_NO.timestamp + get_current(unwrapLock(ballot).duration_ns).data - dateToTime(new Date(Number(ballot.YES_NO.timestamp)/ 1_000_000))) }</span>
            </div>
            <DurationChart 
              duration_timeline={to_number_timeline(unwrapLock(ballot).duration_ns)} 
              format_value={ (value: number) => formatDuration(BigInt(value)) } 
              fillArea={true}
              color={CHART_COLORS.BLUE}
            />
          </div>

          <div className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-800">
            
            <div className="flex flex-row space-x-1 items-baseline">
              <span>{CONSENT_EMOJI}</span>
              <span className="italic text-gray-400 text-sm">Consent:</span> 
              <span>{ ballot.YES_NO.consent.current.data.toFixed(3) }</span>
            </div>
            <DurationChart 
              duration_timeline={ballot.YES_NO.consent}
              format_value={ (value: number) => value.toString() }
              fillArea={true}
              color={CHART_COLORS.WHITE}
              y_min={0}
              y_max={1.0}
            />
          </div>
          
          <div className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-800">
            <div className="flex flex-row space-x-1 items-baseline">
              <span>{PARTICIPATION_EMOJI}</span>
              <span className="italic text-gray-400 text-sm">Participation:</span>
              <span>{ formatBalanceE8s(BigInt(Math.floor(ballot.YES_NO.rewards.current.data.participation)), RESONANCE_TOKEN_SYMBOL) }</span>
            </div>
            <DurationChart 
              duration_timeline={map_timeline(ballot.YES_NO.rewards, (reward) => reward.participation ) } 
              format_value={ (value: number) => (formatBalanceE8s(BigInt(value), RESONANCE_TOKEN_SYMBOL)) } 
              fillArea={true}
              color={CHART_COLORS.PURPLE}
            />
            <InlineMath math="P(t) = lock\_amount \cdot \int_{t_0}^t minting\_rate(t) \, dt" />
          </div>
          
          <div className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-800">
            <div className="flex flex-row space-x-1 items-baseline">
              <span>{DISCERNMENT_EMOJI}</span>
              <span className="italic text-gray-400 text-sm">Discernment:</span>
              <span>{ formatBalanceE8s(BigInt(Math.floor(ballot.YES_NO.rewards.current.data.discernment)), RESONANCE_TOKEN_SYMBOL)}</span>
            </div>
            <DurationChart 
              duration_timeline={map_timeline(ballot.YES_NO.rewards, (reward) => reward.discernment ) } 
              format_value={ (value: number) => (formatBalanceE8s(BigInt(value), RESONANCE_TOKEN_SYMBOL)) }
              fillArea={true}
              color={CHART_COLORS.PURPLE}
            />
            <InlineMath math="D(t) = k * P(t) * dissent_{t_0} * consent(t)" />
          </div>
        </div>
      }
    </div>
  );
}

export default BallotView;