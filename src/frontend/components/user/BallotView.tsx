import { formatDuration } from "../../utils/conversions/durationUnit";
import { niceFormatDate, timeDifference, timeToDate } from "../../utils/conversions/date";

import { DSONANCE_COIN_SYMBOL, MOBILE_MAX_WIDTH_QUERY } from "../../constants";
import { get_current, map_timeline_hack, to_number_timeline, to_time_left } from "../../utils/timeline";
import DurationChart, { CHART_COLORS } from "../charts/DurationChart";
import { unwrapLock } from "../../utils/conversions/ballot";
import { formatBalanceE8s } from "../../utils/conversions/token";

import { SBallotType } from "@/declarations/protocol/protocol.did";
import { useMemo, useState } from "react";
import ChevronUpIcon from "../icons/ChevronUpIcon";
import ChevronDownIcon from "../icons/ChevronDownIcon";
import { useMediaQuery } from "react-responsive";
import BackArrowIcon from "../icons/BackArrowIcon";
import { useNavigate } from "react-router-dom";
import { backendActor } from "../../actors/BackendActor";
import { fromNullable } from "@dfinity/utils";
import { toEnum } from "../../utils/conversions/yesnochoice";
import { useCurrencyContext } from "../CurrencyContext";
import ChoiceView from "../ChoiceView";

interface Props {
  ballot: SBallotType;
  now: bigint;
}

enum CHART_TOGGLE {
    DURATION,
    CONSENT,
    CONTRIBUTION,
    DISCERNMENT
}

const BallotDetails : React.FC<Props> = ({ ballot, now }) => {

    const releaseTimestamp = ballot.YES_NO.timestamp + unwrapLock(ballot).duration_ns.current.data;

    const [chartToggle, setChartToggle] = useState<CHART_TOGGLE | undefined>(undefined);

    const { duration_diff, consent_diff, apr_diff } = useMemo(() => {
        let duration_diff : bigint | undefined = undefined;
        const duration_ns = unwrapLock(ballot).duration_ns;
        if (duration_ns.history.length > 0) {
          duration_diff = get_current(duration_ns).data - duration_ns.history[0].data;
        }

        let consent_diff : number | undefined = undefined;
        const consent = ballot.YES_NO.consent;
        if (consent.history.length > 0) {
          consent_diff = get_current(consent).data - consent.history[0].data;
        }

        let apr_diff : number | undefined = undefined;
        const foresight = ballot.YES_NO.foresight;
        if (foresight.history.length > 1) { // TODO: hack to avoid first value
          apr_diff = foresight.current.data.apr.current - foresight.history[1].data.apr.current;
        }

        return { duration_diff, consent_diff, apr_diff };
    }, [ballot]);
    
    return (
        <div className="flex flex-col justify-items-center w-full mt-2 space-y-1">

          <div 
            className="flex flex-col items-center justify-center space-y-5 w-full rounded-lg py-3 px-3 sm:px-6 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800 hover:cursor-pointer"
            onClick={() => setChartToggle(chartToggle === CHART_TOGGLE.DISCERNMENT ? undefined : CHART_TOGGLE.DISCERNMENT )} 
          >
            <div className="flex flex-row w-full gap-x-2 px-2">
                <span className="text-base grow">APR:</span> 
                <span className="font-semibold [text-shadow:0px_0px_10px_rgb(59,130,246)]">{ ballot.YES_NO.foresight.current.data.apr.current.toFixed(2) + "%" }</span>
                { apr_diff !== undefined && <span className="italic text-gray-700 dark:text-gray-300">{`(${apr_diff > 0 ? "+" : ""}${apr_diff.toFixed(2)}%)`}</span> }
                { chartToggle === CHART_TOGGLE.DISCERNMENT ? <ChevronUpIcon/> : <ChevronDownIcon/> }
            </div>
            { (chartToggle === CHART_TOGGLE.DISCERNMENT) && 
              <DurationChart 
                duration_timelines={ new Map([
                  ["current", { timeline: map_timeline_hack(ballot.YES_NO.foresight, (foresight) => Number(foresight.apr.current) ), color: CHART_COLORS.GREEN }],
                ]) }
                format_value={ (value: number) => (value.toFixed(2)) }
                fillArea={true}
              />
            }
          </div>

          <div 
            className="flex flex-col items-center justify-center space-y-5 w-full rounded-lg py-3 px-3 sm:px-6 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800 hover:cursor-pointer"
            onClick={() => setChartToggle(chartToggle === CHART_TOGGLE.CONTRIBUTION ? undefined : CHART_TOGGLE.CONTRIBUTION )} 
          >
            <div className="flex flex-row w-full gap-x-2 px-2">
                <span className="text-base grow">Mining earned:</span> 
                { formatBalanceE8s(BigInt(Math.floor(ballot.YES_NO.contribution.current.data.earned)), DSONANCE_COIN_SYMBOL, 2) }
                { chartToggle === CHART_TOGGLE.CONTRIBUTION ? <ChevronUpIcon/> : <ChevronDownIcon/> }
            </div>
            { (chartToggle === CHART_TOGGLE.CONTRIBUTION) && 
              <DurationChart 
                duration_timelines={ new Map([
                  ["earned", { timeline: map_timeline_hack(ballot.YES_NO.contribution, (contribution) => contribution.earned ) , color: CHART_COLORS.BLUE }],
                  ["pending", { timeline: map_timeline_hack(ballot.YES_NO.contribution, (contribution) => contribution.pending ), color: CHART_COLORS.PURPLE }],
                ]) }
                format_value={ (value: number) => (formatBalanceE8s(BigInt(value), DSONANCE_COIN_SYMBOL, 2)) } 
                fillArea={true}
              />
            }
          </div>

          <div
            className="flex flex-col items-center justify-center space-y-5 w-full rounded-lg py-3 px-3 sm:px-6 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800 hover:cursor-pointer"
            onClick={() => setChartToggle(chartToggle === CHART_TOGGLE.CONSENT ? undefined : CHART_TOGGLE.CONSENT )} 
          >
            <div className="flex flex-row w-full gap-x-2 px-2">
                <span className="text-base grow">Consent:</span> 
                { ballot.YES_NO.consent.current.data.toFixed(3) }
                { consent_diff !== undefined && <span className="italic text-gray-700 dark:text-gray-300">{`(${consent_diff > 0 ? "+" : ""}${consent_diff.toFixed(3)})`}</span> }
                { chartToggle === CHART_TOGGLE.CONSENT ? <ChevronUpIcon/> : <ChevronDownIcon/> }
            </div>
            { (chartToggle === CHART_TOGGLE.CONSENT) && 
                <DurationChart 
                    duration_timelines={ new Map([["Consent", { timeline: ballot.YES_NO.consent, color: CHART_COLORS.BLUE } ]]) }
                    format_value={ (value: number) => value.toString() }
                    fillArea={true}
                    y_min={0}
                    y_max={1.0}
                />
            }
          </div>

          <div 
            className="flex flex-col items-center justify-center space-y-5 w-full rounded-lg py-3 px-3 sm:px-6 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800 hover:cursor-pointer"
            onClick={() => setChartToggle(chartToggle === CHART_TOGGLE.DURATION ? undefined : CHART_TOGGLE.DURATION )} 
          >
            <div className="flex flex-row w-full gap-x-2 px-2">
                <span className="text-base grow">{ releaseTimestamp > now ? "Time left:" : "Duration:"}</span> 
                <span>
                  { releaseTimestamp > now ? formatDuration(releaseTimestamp - now) : formatDuration(get_current(unwrapLock(ballot).duration_ns).data) }
                </span>
                { duration_diff !== undefined && 
                  <span className="italic text-gray-700 dark:text-gray-300">
                    {`(+ ${formatDuration(duration_diff)})`}
                  </span>
                }
                { chartToggle === CHART_TOGGLE.DURATION ? <ChevronUpIcon/> : <ChevronDownIcon/> }
            </div>
            { (chartToggle === CHART_TOGGLE.DURATION) && 
                <DurationChart 
                    duration_timelines={ releaseTimestamp > now ? 
                      new Map([["time_left", { timeline: to_number_timeline(to_time_left(unwrapLock(ballot).duration_ns, now)), color: CHART_COLORS.PURPLE} ]]) :
                      new Map([["duration", { timeline: to_number_timeline(unwrapLock(ballot).duration_ns), color: CHART_COLORS.PURPLE} ]])
                     }
                    format_value={ (value: number) => formatDuration(BigInt(value)) } 
                    fillArea={true}
                />
            }
          </div>
        </div>
    );
}

const BallotView : React.FC<Props> = ({ ballot, now }) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const navigate = useNavigate();
  const { formatSatoshis } = useCurrencyContext();

  const { data: vote } = backendActor.useQueryCall({
      functionName: 'get_vote',
      args: [{ vote_id: ballot.YES_NO.vote_id }],
  });

  const actualVote = vote ? fromNullable(vote) : undefined;

  return (
    <div className={`flex flex-col items-center ${isMobile ? "px-3 py-1 w-full" : "py-3 w-2/3"}`}>
      <div className={`grid grid-cols-3 space-x-1 mb-3 items-center w-full`}>
        <div className="hover:cursor-pointer justify-self-start" onClick={() => navigate(-1)}>
          <BackArrowIcon/>
        </div>
        <span className="text-xl font-semibold items-baseline justify-self-center">Ballot</span>
        <span className="grow">{/* spacer */}</span>
      </div>
      { actualVote ? 
        <div 
          className={`text-justify mb-3 mx-auto hover:cursor-pointer`}
          onClick={(e) => navigate(`/vote/${ballot.YES_NO.vote_id}`)}
        >
          { actualVote.info.text } 
        </div> :
        <div className="flex flex-col w-full space-y-2 mb-3">
          <div className="w-full h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"/>
          <div className="w-full h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"/>
          <div className="w-1/2 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"/>
        </div>
      }
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-x-2 gap-y-2 justify-items-center items-center w-full sm:w-2/3">
        <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">Placed</span>
          <span>{ niceFormatDate(timeToDate(ballot.YES_NO.timestamp), timeToDate(now)) }</span>
        </div>
        <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">Dissent</span>
          <span>{ ballot.YES_NO.dissent.toFixed(3) }</span>
        </div>
        <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">Amount</span>
          <span>{formatSatoshis(ballot.YES_NO.amount)}</span>
        </div>
        <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">Choice</span>
          <ChoiceView choice={toEnum(ballot.YES_NO.choice)}/>
        </div>
      </div>
      < BallotDetails ballot={ballot} now={now}/>
    </div>
    );
}

export default BallotView;

export const BallotViewSkeleton: React.FC = () => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY  });
  const navigate = useNavigate();

  return (
    <div className={`flex flex-col items-center ${isMobile ? "px-3 py-1 w-full" : "py-3 w-2/3"}`}>
    {/* Header */}
    <div className="grid grid-cols-3 space-x-1 mb-3 items-center w-full">
      <div className="hover:cursor-pointer justify-self-start" onClick={() => navigate(-1)}>
        <BackArrowIcon/>
      </div>
      <span className="text-xl font-semibold items-baseline justify-self-center">Ballot</span>
      <span className="grow">{/* spacer */}</span>
    </div>

    {/* Vote Text Placeholder */}
    <div className="flex flex-col w-full space-y-2 mb-3">
      <div className="w-full h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"/>
      <div className="w-full h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"/>
      <div className="w-1/2 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"/>
    </div>

    {/* Grid Section */}
    <div className="grid grid-cols-2 sm:grid-cols-4 gap-x-2 gap-y-2 justify-items-center items-center w-full sm:w-2/3">
      <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
        <span className="text-sm text-gray-600 dark:text-gray-400">Placed</span>
        <div className="w-20 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
      </div>
      <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
        <span className="text-sm text-gray-600 dark:text-gray-400">Dissent</span>
        <div className="w-12 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
      </div>
      <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
        <span className="text-sm text-gray-600 dark:text-gray-400">Amount</span>
        <div className="w-16 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
      </div>
      <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
        <span className="text-sm text-gray-600 dark:text-gray-400">Choice</span>
        <div className="w-10 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
      </div>
    </div>

    {/* Ballot Details Placeholder */}
    <div className="w-full mt-3">
      <div className="w-full h-12 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
    </div>
  </div>
  );
}