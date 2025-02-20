import { formatDuration } from "../../utils/conversions/durationUnit";
import { dateToTime, niceFormatDate, timeToDate } from "../../utils/conversions/date";

import { LOCK_EMOJI, DSONANCE_COIN_SYMBOL, CONSENT_EMOJI, CONTRIBUTION_EMOJI, DISCERNMENT_EMOJI, TIMESTAMP_EMOJI, DISSENT_EMOJI } from "../../constants";
import { get_current, map_timeline, to_number_timeline } from "../../utils/timeline";
import DurationChart, { CHART_COLORS } from "../charts/DurationChart";
import { unwrapLock } from "../../utils/conversions/ballot";
import { formatBalanceE8s } from "../../utils/conversions/token";

import { SBallotType } from "@/declarations/protocol/protocol.did";
import { useState } from "react";
import ChevronUpIcon from "../icons/ChevronUpIcon";
import ChevronDownIcon from "../icons/ChevronDownIcon";
import { useCurrencyContext } from "../CurrencyContext";

interface BallotDetailsProps {
  ballot: SBallotType;
  now: bigint;
  releaseTimestamp: bigint;
}

enum CHART_TOGGLE {
    DURATION,
    CONSENT,
    CONTRIBUTION,
    DISCERNMENT
}

export const DesktopBallotDetails : React.FC<BallotDetailsProps> = ({ ballot, now, releaseTimestamp }) => {

    const { formatSatoshis } = useCurrencyContext();
    
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
              duration_timelines={ new Map([["todo", to_number_timeline(unwrapLock(ballot).duration_ns) ]]) }
              format_value={ (value: number) => formatDuration(BigInt(value)) } 
              fillArea={true}
              color={CHART_COLORS.PURPLE}
              last_timestamp={releaseTimestamp <= now ? releaseTimestamp : now }
            />
          </div>

          <div className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-200 dark:border-gray-800 py-1">
            
            <div className="flex flex-row space-x-1 items-baseline">
              <span>{CONSENT_EMOJI}</span>
              <span className="italic text-gray-600 dark:text-gray-400 text-sm">Consent:</span> 
              <span>{ ballot.YES_NO.consent.current.data.toFixed(3) }</span>
            </div>
            <DurationChart 
              duration_timelines={ new Map([["todo", ballot.YES_NO.consent ]]) }
              format_value={ (value: number) => value.toString() }
              fillArea={true}
              color={CHART_COLORS.BLUE}
              y_min={0}
              y_max={1.0}
              last_timestamp={releaseTimestamp <= now ? releaseTimestamp : now }
            />
          </div>
          
          <div className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-200 dark:border-gray-800 py-1">
            <div className="flex flex-row space-x-1 items-baseline">
              <span>{CONTRIBUTION_EMOJI}</span>
              <span className="italic text-gray-600 dark:text-gray-400 text-sm">Earned contribution:</span>
              <span>{ formatBalanceE8s(BigInt(Math.floor(ballot.YES_NO.contribution.current.data.earned)), DSONANCE_COIN_SYMBOL, 2) }</span>
            </div>
            <DurationChart 
              duration_timelines={ new Map([["todo", map_timeline(ballot.YES_NO.contribution, (contribution) => contribution.earned )  ]]) }
              format_value={ (value: number) => (formatBalanceE8s(BigInt(value), DSONANCE_COIN_SYMBOL, 2)) } 
              fillArea={true}
              color={CHART_COLORS.GREEN}
            />
          </div>

          <div className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-200 dark:border-gray-800 py-1">
            <div className="flex flex-row space-x-1 items-baseline">
              <span>{CONTRIBUTION_EMOJI}</span>
              <span className="italic text-gray-600 dark:text-gray-400 text-sm">Pending contribution:</span>
              <span>{ formatBalanceE8s(BigInt(Math.floor(ballot.YES_NO.contribution.current.data.pending)), DSONANCE_COIN_SYMBOL, 2) }</span>
            </div>
            <DurationChart 
              duration_timelines={ new Map([["todo", map_timeline(ballot.YES_NO.contribution, (contribution) => contribution.pending )  ]]) }
              format_value={ (value: number) => (formatBalanceE8s(BigInt(value), DSONANCE_COIN_SYMBOL, 2)) } 
              fillArea={true}
              color={CHART_COLORS.GREEN}
            />
          </div>

          <div className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-200 dark:border-gray-800 py-1">
            <div className="flex flex-row space-x-1 items-baseline">
              <span>{DISCERNMENT_EMOJI}</span>
              <span className="italic text-gray-600 dark:text-gray-400 text-sm">APR:</span>
              <span>{ ballot.YES_NO.foresight.current.data.apr.potential.toFixed(2) + "%" }</span>
            </div>
            <DurationChart 
              duration_timelines={ new Map([
                ["current", map_timeline(ballot.YES_NO.foresight, (foresight) => Number(foresight.apr.current) )  ],
                ["potential", map_timeline(ballot.YES_NO.foresight, (foresight) => Number(foresight.apr.potential) )  ]
              ]) }
              format_value={ (value: number) => (value.toFixed(2)) }
              fillArea={false}
              color={CHART_COLORS.GREEN}
            />
          </div>

        </div>
    );
}

export const MobileBallotDetails : React.FC<BallotDetailsProps> = ({ ballot, now, releaseTimestamp }) => {

    const { formatSatoshis } = useCurrencyContext();
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
                { chartToggle === CHART_TOGGLE.DURATION ? <ChevronUpIcon/> : <ChevronDownIcon/> }
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
                    duration_timelines={ new Map([["todo", to_number_timeline(unwrapLock(ballot).duration_ns) ]]) }
                    format_value={ (value: number) => formatDuration(BigInt(value)) } 
                    fillArea={true}
                    color={CHART_COLORS.PURPLE}
                    last_timestamp={releaseTimestamp <= now ? releaseTimestamp : now }
                />
            }
          </div>

          <div
            className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-200 dark:border-gray-800 py-1"
            onClick={() => setChartToggle(chartToggle === CHART_TOGGLE.CONSENT ? undefined : CHART_TOGGLE.CONSENT )} 
          >
            <div className="grid grid-cols-9 items-center text-center justify-center w-full pl-2 pr-10">
                { chartToggle === CHART_TOGGLE.CONSENT ? <ChevronUpIcon/> : <ChevronDownIcon/> }
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
                    duration_timelines={ new Map([["todo", ballot.YES_NO.consent ]]) }
                    format_value={ (value: number) => value.toString() }
                    fillArea={true}
                    color={CHART_COLORS.BLUE}
                    y_min={0}
                    y_max={1.0}
                    last_timestamp={releaseTimestamp <= now ? releaseTimestamp : now }
                />
            }
          </div>
          
          <div 
            className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-200 dark:border-gray-800 py-1"
            onClick={() => setChartToggle(chartToggle === CHART_TOGGLE.CONTRIBUTION ? undefined : CHART_TOGGLE.CONTRIBUTION )} 
          >
            <div className="grid grid-cols-9 items-center text-center justify-center w-full pl-2 pr-10">
                { chartToggle === CHART_TOGGLE.CONTRIBUTION ? <ChevronUpIcon/> : <ChevronDownIcon/> }
                <span className="flex flex-row space-x-1 col-span-4">
                    <span>{CONTRIBUTION_EMOJI}</span>
                    <span className="italic text-gray-600 dark:text-gray-400 text-sm">Earned contribution:</span> 
                </span>
                <span className="col-span-4 justify-self-end">
                    { formatBalanceE8s(BigInt(Math.floor(ballot.YES_NO.contribution.current.data.earned)), DSONANCE_COIN_SYMBOL, 2) }
                </span>
            </div>
            { (chartToggle === CHART_TOGGLE.CONTRIBUTION) && 
              <DurationChart 
                  duration_timelines={ new Map([["todo", map_timeline(ballot.YES_NO.contribution, (contribution) => contribution.earned )  ]]) }
                  format_value={ (value: number) => (formatBalanceE8s(BigInt(value), DSONANCE_COIN_SYMBOL, 2)) } 
                  fillArea={true}
                  color={CHART_COLORS.GREEN}
                  last_timestamp={releaseTimestamp <= now ? releaseTimestamp : now }
              />
            }
          </div>
          
          <div 
            className="flex flex-col items-center justify-center space-x-1 w-full border border-gray-200 dark:border-gray-800 py-1"
            onClick={() => setChartToggle(chartToggle === CHART_TOGGLE.DISCERNMENT ? undefined : CHART_TOGGLE.DISCERNMENT )} 
          >
            <div className="grid grid-cols-9 items-center text-center justify-center w-full pl-2 pr-10">
                { chartToggle === CHART_TOGGLE.DISCERNMENT ? <ChevronUpIcon/> : <ChevronDownIcon/> }
                <span className="flex flex-row space-x-1 col-span-4">
                    <span>{DISCERNMENT_EMOJI}</span>
                    <span className="italic text-gray-600 dark:text-gray-400 text-sm">Current foresight:</span> 
                </span>
                <span className="col-span-4 justify-self-end">
                    { formatSatoshis(ballot.YES_NO.foresight.current.data.reward)}
                </span>
            </div>
            { (chartToggle === CHART_TOGGLE.DISCERNMENT) && 
              <DurationChart 
                  duration_timelines={ new Map([["todo", map_timeline(ballot.YES_NO.foresight, (foresight) => Number(foresight.reward) )  ]]) }
                  format_value={ (value: number) => (formatSatoshis(BigInt(value)) ?? "") }
                  fillArea={true}
                  color={CHART_COLORS.GREEN}
                  last_timestamp={releaseTimestamp <= now ? releaseTimestamp : now }
              />
            }
          </div>
        </div>
    );
}