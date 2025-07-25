import { formatDuration } from "../../utils/conversions/durationUnit";
import { niceFormatDate, timeToDate } from "../../utils/conversions/date";

import { MOBILE_MAX_WIDTH_QUERY } from "../../constants";
import { get_current, get_timeline_diff, interpolate_now, map_timeline_hack, to_number_timeline, to_time_left } from "../../utils/timeline";
import DurationChart, { CHART_COLORS, SerieInput } from "../charts/DurationChart";
import { unwrapLock } from "../../utils/conversions/ballot";

import { SBallotType } from "@/declarations/protocol/protocol.did";
import { useEffect, useMemo, useState } from "react";
import ChevronUpIcon from "../icons/ChevronUpIcon";
import ChevronDownIcon from "../icons/ChevronDownIcon";
import { useMediaQuery } from "react-responsive";
import { useNavigate } from "react-router-dom";
import { backendActor } from "../../actors/BackendActor";
import { fromNullable } from "@dfinity/utils";
import { toEnum } from "../../utils/conversions/yesnochoice";
import ChoiceView from "../ChoiceView";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";
import { createThumbnailUrl } from "../../utils/thumbnail";

enum CHART_TOGGLE {
    DURATION,
    CONSENT,
    CONTRIBUTION,
    DISCERNMENT
}

interface ChartCardProps {
  title: string;
  value: string;
  diff?: string;
  toggleKey: CHART_TOGGLE;
  chartTimelines: Map<string, SerieInput>;
  formatValue: (value: number) => string;
  valueClassName?: string;
  yMin?: number;
  yMax?: number;
  setChartToggle: (toggleKey: CHART_TOGGLE | undefined) => void;
  chartToggle: CHART_TOGGLE | undefined;
  isMobile: boolean;
}

const ChartCard : React.FC<ChartCardProps> = ({ title, value, diff, toggleKey, chartTimelines, formatValue, valueClassName, yMin, yMax, setChartToggle, chartToggle, isMobile }) => (
  <div
    className="flex flex-col items-center justify-center space-y-5 w-full rounded-lg py-3 px-3 sm:px-6 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800 hover:cursor-pointer"
    onClick={() => setChartToggle(chartToggle === toggleKey ? undefined : toggleKey)}
  >
    <div className="flex flex-row w-full gap-x-2 px-2">
      <span className="text-base grow">{title}</span>
      <span className={`font-semibold ${valueClassName}`}>{value}</span>
      {diff && <span className="italic text-gray-700 dark:text-gray-300">{diff}</span>}
      {chartToggle === toggleKey ? <ChevronUpIcon /> : <ChevronDownIcon />}
    </div>
    {chartToggle === toggleKey && (
      <div className={`w-full ${isMobile ? "h-[200px]" : "h-[300px]"}`}>
        <DurationChart
          duration_timelines={chartTimelines}
          format_value={formatValue}
          fillArea={true}
          y_min={yMin}
          y_max={yMax}
        />
      </div>
    )}
  </div>
);

interface BallotDetailsProps {
  ballot: SBallotType;
  now: bigint;
  isMobile: boolean;
}

const BallotDetails : React.FC<BallotDetailsProps> = ({ ballot, now, /*contribution,*/ isMobile }) => {

    const releaseTimestamp = ballot.YES_NO.timestamp + unwrapLock(ballot.YES_NO).duration_ns.current.data;

    const [chartToggle, setChartToggle] = useState<CHART_TOGGLE | undefined>(undefined);

    const chartData = useMemo(() => {

      let duration_diff = get_timeline_diff(unwrapLock(ballot.YES_NO).duration_ns);
      let consent_diff = get_timeline_diff(ballot.YES_NO.consent);

      return [
        {
          title: "Consent:",
          value: ballot.YES_NO.consent.current.data.toFixed(3),
          diff: consent_diff !== undefined && Math.abs(consent_diff) > 0 ? `(${consent_diff > 0 ? "+" : ""}${consent_diff.toFixed(3)})` : undefined,
          toggleKey: CHART_TOGGLE.CONSENT,
          chartTimelines: new Map([
            ["Consent", { timeline: interpolate_now(ballot.YES_NO.consent, now), color: CHART_COLORS.BLUE }],
          ]),
          formatValue: (value: number) => value.toString(),
          yMin: 0,
          yMax: 1.0,
        },
        {
          title: releaseTimestamp > now ? "Time left:" : "Duration:",
          value:
            releaseTimestamp > now
              ? formatDuration(releaseTimestamp - now)
              : formatDuration(get_current(unwrapLock(ballot.YES_NO).duration_ns).data),
          diff: duration_diff !== undefined ? `(+ ${formatDuration(duration_diff)})` : undefined,
          toggleKey: CHART_TOGGLE.DURATION,
          chartTimelines:
            releaseTimestamp > now
              ? new Map([
                  [
                    "time_left",
                    {
                      timeline: to_number_timeline(to_time_left(unwrapLock(ballot.YES_NO).duration_ns, now)),
                      color: CHART_COLORS.PURPLE,
                    },
                  ],
                ])
              : new Map([
                  [
                    "duration",
                    {
                      timeline: to_number_timeline(unwrapLock(ballot.YES_NO).duration_ns),
                      color: CHART_COLORS.PURPLE,
                    },
                  ],
                ]),
          formatValue: (value: number) => formatDuration(BigInt(value)),
        },
      ];

    }, [ballot]);

    return (
      <div className="flex flex-col justify-items-center w-full mt-2 space-y-1">
        {chartData.map((item, index) => (
          <ChartCard key={index} {...item} chartToggle={chartToggle} setChartToggle={setChartToggle} isMobile={isMobile}/>
        ))}
      </div>
    );
}

interface BallotViewProps {
  ballot: SBallotType;
  now: bigint;
}

const BallotView : React.FC<BallotViewProps> = ({ ballot, now }) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const navigate = useNavigate();
  const { supplyLedger: { formatAmountUsd } } = useFungibleLedgerContext();

  const { data: vote, call: refreshVote } = backendActor.useQueryCall({
      functionName: 'get_vote',
      args: [{ vote_id: ballot.YES_NO.vote_id }],
  });

  useEffect(() => {
    refreshVote();
  }
  , [ballot]);

  const actualVote = useMemo(() => {
    return vote ? fromNullable(vote) : undefined;
  }
  , [vote]);

  const thumbnailUrl = useMemo(() => {
    if (actualVote === undefined) {
      return undefined;
    }
    return createThumbnailUrl(actualVote.info.thumbnail)
  }, [vote]);

  return (
    <div className={`flex flex-col items-center ${isMobile ? "px-3 py-1 w-full" : "py-3 w-2/3"}`}>
      {/* Top Row: Image and Vote Text */}
      <div className="w-full flex items-center gap-4 mb-4">
        {/* Thumbnail Image */}
        <img 
          className="w-20 h-20 bg-contain bg-no-repeat bg-center rounded-md" 
          src={thumbnailUrl}
          alt="Vote Thumbnail"
        />
        {/* Vote Text */}
        { actualVote ? 
          <div 
            className="flex-grow text-gray-800 dark:text-gray-200 font-medium text-lg"
            onClick={(e) => navigate(`/vote/${ballot.YES_NO.vote_id}`)}
          >
            { actualVote.info.text }
          </div> : 
          <div className="flex-grow h-6 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
        }
      </div>
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-x-2 gap-y-2 justify-items-center items-center w-full sm:w-2/3">
        <div className="grid grid-rows-2 justify-items-center w-full">
          <span className="text-sm text-gray-600 dark:text-gray-400">Choice</span>
          <ChoiceView choice={toEnum(ballot.YES_NO.choice)}/>
        </div>
        <div className="grid grid-rows-2 justify-items-center w-full">
          <span className="text-sm text-gray-600 dark:text-gray-400">Placed</span>
          <span>{ niceFormatDate(timeToDate(ballot.YES_NO.timestamp), timeToDate(now)) }</span>
        </div>
        <div className="grid grid-rows-2 justify-items-center w-full">
          <span className="text-sm text-gray-600 dark:text-gray-400">Dissent</span>
          <span>{ ballot.YES_NO.dissent.toFixed(3) }</span>
        </div>
        <div className="grid grid-rows-2 justify-items-center w-full">
          <span className="text-sm text-gray-600 dark:text-gray-400">Amount</span>
          <span>{formatAmountUsd(ballot.YES_NO.amount)}</span>
        </div>
      </div>
      <BallotDetails ballot={ballot} now={now} /*contribution={actualDebtInfo?.amount}*/ isMobile={isMobile}/>
    </div>
    );
}

export default BallotView;

export const BallotViewSkeleton: React.FC = () => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  return (
    <div className={`flex flex-col items-center ${isMobile ? "px-3 py-1 w-full" : "py-3 w-2/3"}`}>
      {/* Top Row: Placeholder Image and Vote Text */}
      <div className="w-full flex items-center gap-4 mb-4">
        <div className="w-20 h-20 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
        <div className="flex-grow h-6 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
      </div>

      {/* Grid Section */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-x-2 gap-y-2 justify-items-center items-center w-full sm:w-2/3">
        <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">Choice</span>
          <div className="w-10 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
        </div>
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
      </div>

      {/* Ballot Details Placeholder */}
      <div className="w-full mt-3">
        <div className="w-full h-12 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
      </div>
    </div>
  );
}