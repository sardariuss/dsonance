import { formatDuration } from "../../utils/conversions/durationUnit";
import { dateToTime, niceFormatDate, timeToDate } from "../../utils/conversions/date";

import { LOCK_EMOJI, DSONANCE_TOKEN_SYMBOL, CONSENT_EMOJI, PARTICIPATION_EMOJI, DISCERNMENT_EMOJI, TIMESTAMP_EMOJI, DISSENT_EMOJI } from "../../constants";
import { get_current, map_timeline, to_number_timeline } from "../../utils/timeline";
import DurationChart, { CHART_COLORS } from "../charts/DurationChart";
import { unwrapLock } from "../../utils/conversions/ballot";
import { formatBalanceE8s } from "../../utils/conversions/token";

import 'katex/dist/katex.min.css';
import { InlineMath } from "react-katex";
import { SBallotType } from "@/declarations/protocol/protocol.did";
import { useState } from "react";
import ChevronUpIcon from "../icons/ChevronUpIcon";
import ChevronDownIcon from "../icons/ChevronDownIcon";

interface BallotDetailsProps {
  ballot: SBallotType;
  now: bigint;
  releaseTimestamp: bigint;
}

enum CHART_TOGGLE {
    DURATION,
    CONSENT,
    PARTICIPATION,
    DISCERNMENT
}

export const DesktopBallotDetails : React.FC<BallotDetailsProps> = ({ ballot, now, releaseTimestamp }) => {
    
    return (
        <div className="grid grid-cols-2 gap-x-2 gap-y-2 justify-items-center w-full mt-2">

          <div className="flex flex-row space-x-1 items-baseline justify-center w-full border border-gray-200 dark:border-gray-800 py-1">
            <span>{TIMESTAMP_EMOJI}</span>
            <span className="italic text-gray-600 dark:text-gray-400 text-sm">Locked:</span> 
            <span>{niceFormatDate(timeToDate(ballot.YES_NO.timestamp), timeToDate(now)) }</span>
          </div>

          <div className="flex flex-row space-x-1 items-baseline justify-center w-full border border-gray-200 dark:border-gray-800 py-1">
            <span>{DISSENT_EMOJI}</span>
            <span className="italic text-gray-600 dark:text-gray-400 text-sm">Dissent:</span> 
            <span>{ ballot.YES_NO.dissent.toFixed(3) }</span>
          </div>

          <div className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-200 dark:border-gray-800 py-1">
            <div className="flex flex-row space-x-1 items-baseline">
              <span>{LOCK_EMOJI}</span>
              <span className="italic text-gray-600 dark:text-gray-400 text-sm">Duration:</span> 
              <span>{formatDuration(ballot.YES_NO.timestamp + get_current(unwrapLock(ballot).duration_ns).data - dateToTime(new Date(Number(ballot.YES_NO.timestamp)/ 1_000_000))) }</span>
            </div>
            <DurationChart 
              duration_timeline={to_number_timeline(unwrapLock(ballot).duration_ns)} 
              format_value={ (value: number) => formatDuration(BigInt(value)) } 
              fillArea={true}
              color={CHART_COLORS.PURPLE}
              last_timestamp={releaseTimestamp <= now ? now : releaseTimestamp }
            />
          </div>

          <div className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-200 dark:border-gray-800 py-1">
            
            <div className="flex flex-row space-x-1 items-baseline">
              <span>{CONSENT_EMOJI}</span>
              <span className="italic text-gray-600 dark:text-gray-400 text-sm">Consent:</span> 
              <span>{ ballot.YES_NO.consent.current.data.toFixed(3) }</span>
            </div>
            <DurationChart 
              duration_timeline={ballot.YES_NO.consent}
              format_value={ (value: number) => value.toString() }
              fillArea={true}
              color={CHART_COLORS.BLUE}
              y_min={0}
              y_max={1.0}
              last_timestamp={releaseTimestamp <= now ? now : releaseTimestamp }
            />
          </div>
          
          <div className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-200 dark:border-gray-800 py-1">
            <div className="flex flex-row space-x-1 items-baseline">
              <span>{PARTICIPATION_EMOJI}</span>
              <span className="italic text-gray-600 dark:text-gray-400 text-sm">Participation:</span>
              <span>{ formatBalanceE8s(BigInt(Math.floor(ballot.YES_NO.rewards.current.data.participation)), DSONANCE_TOKEN_SYMBOL, 2) }</span>
            </div>
            <DurationChart 
              duration_timeline={map_timeline(ballot.YES_NO.rewards, (reward) => reward.participation ) } 
              format_value={ (value: number) => (formatBalanceE8s(BigInt(value), DSONANCE_TOKEN_SYMBOL, 2)) } 
              fillArea={true}
              color={CHART_COLORS.GREEN}
              last_timestamp={releaseTimestamp <= now ? now : releaseTimestamp }
            />
            <InlineMath math="P(t) = lock\_amount \cdot \int_{t_0}^t participation\_rate(t) \, dt" />
          </div>
          
          <div className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-200 dark:border-gray-800 py-1">
            <div className="flex flex-row space-x-1 items-baseline">
              <span>{DISCERNMENT_EMOJI}</span>
              <span className="italic text-gray-600 dark:text-gray-400 text-sm">Discernment:</span>
              <span>{ formatBalanceE8s(BigInt(Math.floor(ballot.YES_NO.rewards.current.data.discernment)), DSONANCE_TOKEN_SYMBOL, 2)}</span>
            </div>
            <DurationChart 
              duration_timeline={map_timeline(ballot.YES_NO.rewards, (reward) => reward.discernment ) } 
              format_value={ (value: number) => (formatBalanceE8s(BigInt(value), DSONANCE_TOKEN_SYMBOL, 2)) }
              fillArea={true}
              color={CHART_COLORS.GREEN}
              last_timestamp={releaseTimestamp <= now ? now : releaseTimestamp }
            />
            <InlineMath math="D(t) = discernment\_factor * P(t) * dissent_{t_0} * consent(t)" />
          </div>
        </div>
    );
}

export const MobileBallotDetails : React.FC<BallotDetailsProps> = ({ ballot, now, releaseTimestamp }) => {

    const [chartToggle, setChartToggle] = useState<CHART_TOGGLE | undefined>(undefined);
    
    return (
        <div className="flex flex-col justify-items-center w-full mt-2 space-y-1">

          <div className="grid grid-cols-9 items-center text-center justify-center w-full border border-gray-200 dark:border-gray-800 py-1 pl-2 pr-10">
            <span/>
            <span className="flex flex-row space-x-1 col-span-4">
                <span>{TIMESTAMP_EMOJI}</span>
                <span className="italic text-gray-600 dark:text-gray-400 text-sm">Locked:</span> 
            </span>
            <span className="col-span-4 justify-self-end">{niceFormatDate(timeToDate(ballot.YES_NO.timestamp), timeToDate(now)) }</span>
          </div>

          <div className="grid grid-cols-9 items-center text-center justify-center w-full border border-gray-200 dark:border-gray-800 py-1 pl-2 pr-10">
            <span/>
            <span className="flex flex-row space-x-1 col-span-4">
                <span>{DISSENT_EMOJI}</span>
                <span className="italic text-gray-600 dark:text-gray-400 text-sm">Dissent:</span> 
            </span>
            <span className="col-span-4 justify-self-end">{ ballot.YES_NO.dissent.toFixed(3) }</span>
          </div>

          <div 
            className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-200 dark:border-gray-800 py-1"
            onClick={() => setChartToggle(chartToggle === CHART_TOGGLE.DURATION ? undefined : CHART_TOGGLE.DURATION )} 
          >
            <div className="grid grid-cols-9 items-center text-center justify-center w-full pl-2 pr-10">
                { chartToggle === CHART_TOGGLE.DURATION ? <ChevronDownIcon/> : <ChevronUpIcon/> }
                <span className="flex flex-row space-x-1 col-span-4">
                    <span>{LOCK_EMOJI}</span>
                    <span className="italic text-gray-600 dark:text-gray-400 text-sm">Duration:</span> 
                </span>
                <span className="col-span-4 justify-self-end">
                    {formatDuration(ballot.YES_NO.timestamp + get_current(unwrapLock(ballot).duration_ns).data - dateToTime(new Date(Number(ballot.YES_NO.timestamp)/ 1_000_000))) }
                </span>
            </div>
            { (chartToggle === CHART_TOGGLE.DURATION) && 
                <DurationChart 
                    duration_timeline={to_number_timeline(unwrapLock(ballot).duration_ns)} 
                    format_value={ (value: number) => formatDuration(BigInt(value)) } 
                    fillArea={true}
                    color={CHART_COLORS.PURPLE}
                    last_timestamp={releaseTimestamp <= now ? now : releaseTimestamp }
                />
            }
          </div>

          <div
            className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-200 dark:border-gray-800 py-1"
            onClick={() => setChartToggle(chartToggle === CHART_TOGGLE.CONSENT ? undefined : CHART_TOGGLE.CONSENT )} 
          >
            <div className="grid grid-cols-9 items-center text-center justify-center w-full pl-2 pr-10">
                { chartToggle === CHART_TOGGLE.CONSENT ? <ChevronDownIcon/> : <ChevronUpIcon/> }
                <span className="flex flex-row space-x-1 col-span-4">
                    <span>{CONSENT_EMOJI}</span>
                    <span className="italic text-gray-600 dark:text-gray-400 text-sm">Consent:</span> 
                </span>
                <span className="col-span-4 justify-self-end"> 
                    { ballot.YES_NO.consent.current.data.toFixed(3) }
                </span>
            </div>
            { (chartToggle === CHART_TOGGLE.CONSENT) && 
                <DurationChart 
                    duration_timeline={ballot.YES_NO.consent}
                    format_value={ (value: number) => value.toString() }
                    fillArea={true}
                    color={CHART_COLORS.BLUE}
                    y_min={0}
                    y_max={1.0}
                    last_timestamp={releaseTimestamp <= now ? now : releaseTimestamp }
                />
            }
          </div>
          
          <div 
            className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-200 dark:border-gray-800 py-1"
            onClick={() => setChartToggle(chartToggle === CHART_TOGGLE.PARTICIPATION ? undefined : CHART_TOGGLE.PARTICIPATION )} 
          >
            <div className="grid grid-cols-9 items-center text-center justify-center w-full pl-2 pr-10">
                { chartToggle === CHART_TOGGLE.PARTICIPATION ? <ChevronDownIcon/> : <ChevronUpIcon/> }
                <span className="flex flex-row space-x-1 col-span-4">
                    <span>{PARTICIPATION_EMOJI}</span>
                    <span className="italic text-gray-600 dark:text-gray-400 text-sm">Participation:</span> 
                </span>
                <span className="col-span-4 justify-self-end">
                    { formatBalanceE8s(BigInt(Math.floor(ballot.YES_NO.rewards.current.data.participation)), DSONANCE_TOKEN_SYMBOL, 2) }
                </span>
            </div>
            { (chartToggle === CHART_TOGGLE.PARTICIPATION) && 
                <div className="flex flex-col w-full">
                    <DurationChart 
                        duration_timeline={map_timeline(ballot.YES_NO.rewards, (reward) => reward.participation ) } 
                        format_value={ (value: number) => (formatBalanceE8s(BigInt(value), DSONANCE_TOKEN_SYMBOL, 2)) } 
                        fillArea={true}
                        color={CHART_COLORS.GREEN}
                        last_timestamp={releaseTimestamp <= now ? now : releaseTimestamp }
                    />
                    <div className="flex flex-col space-x-1 items-center text-sm">
                        <InlineMath math="P(t) = lock\_amount \cdot \int_{t_0}^t r(t) \, dt" />
                        <span>where:</span>
                        <InlineMath math="r(t) = participation\_rate(t)"/>
                    </div>
                </div>
            }
          </div>
          
          <div 
            className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-200 dark:border-gray-800 py-1"
            onClick={() => setChartToggle(chartToggle === CHART_TOGGLE.DISCERNMENT ? undefined : CHART_TOGGLE.DISCERNMENT )} 
          >
            <div className="grid grid-cols-9 items-center text-center justify-center w-full pl-2 pr-10">
                { chartToggle === CHART_TOGGLE.DISCERNMENT ? <ChevronDownIcon/> : <ChevronUpIcon/> }
                <span className="flex flex-row space-x-1 col-span-4">
                    <span>{DISCERNMENT_EMOJI}</span>
                    <span className="italic text-gray-600 dark:text-gray-400 text-sm">Discernment:</span> 
                </span>
                <span className="col-span-4 justify-self-end">
                    { formatBalanceE8s(BigInt(Math.floor(ballot.YES_NO.rewards.current.data.discernment)), DSONANCE_TOKEN_SYMBOL, 2)}
                </span>
            </div>
            { (chartToggle === CHART_TOGGLE.DISCERNMENT) && 
                <div className="flex flex-col w-full">
                    <DurationChart 
                        duration_timeline={map_timeline(ballot.YES_NO.rewards, (reward) => reward.discernment ) } 
                        format_value={ (value: number) => (formatBalanceE8s(BigInt(value), DSONANCE_TOKEN_SYMBOL, 2)) }
                        fillArea={true}
                        color={CHART_COLORS.GREEN}
                        last_timestamp={releaseTimestamp <= now ? now : releaseTimestamp }
                    />
                    <div className="flex flex-col space-x-1 items-center text-sm">
                        <InlineMath math="D(t) = K * P(t) * dissent_{t_0} * consent(t)"/>
                        <span>where:</span>
                        <InlineMath math="K = discernment\_factor"/>
                    </div>
                </div>
            }
          </div>
        </div>
    );
}