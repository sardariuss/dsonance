import { formatDuration } from "../../utils/conversions/durationUnit";
import { niceFormatDate, timeToDate } from "../../utils/conversions/date";

import { DSONANCE_COIN_SYMBOL, MOBILE_MAX_WIDTH_QUERY } from "../../constants";
import { get_current, get_timeline_diff, interpolate_now, map_timeline_hack, to_number_timeline, to_time_left } from "../../utils/timeline";
import DurationChart, { CHART_COLORS, SerieInput } from "../charts/DurationChart";
import { unwrapLock } from "../../utils/conversions/ballot";
import { formatBalanceE8s } from "../../utils/conversions/token";

import { SBallotType, STimeline_4 } from "@/declarations/protocol/protocol.did";
import { useEffect, useMemo, useState } from "react";
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
import { protocolActor } from "../../actors/ProtocolActor";

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
}

const ChartCard : React.FC<ChartCardProps> = ({ title, value, diff, toggleKey, chartTimelines, formatValue, valueClassName, yMin, yMax, setChartToggle, chartToggle }) => (
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
      <DurationChart
        duration_timelines={chartTimelines}
        format_value={formatValue}
        fillArea={true}
        y_min={yMin}
        y_max={yMax}
      />
    )}
  </div>
);

interface BallotDetailsProps {
  ballot: SBallotType;
  now: bigint;
  contribution: STimeline_4 | undefined;
}

const BallotDetails : React.FC<BallotDetailsProps> = ({ ballot, now, contribution }) => {

    if (!contribution) {
      return (
        <div className="w-full mt-3">
          <div className="w-full h-12 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
        </div>
      );
    }

    const releaseTimestamp = ballot.YES_NO.timestamp + unwrapLock(ballot).duration_ns.current.data;

    const [chartToggle, setChartToggle] = useState<CHART_TOGGLE | undefined>(undefined);

    const chartData = useMemo(() => {

      let duration_diff = get_timeline_diff(unwrapLock(ballot).duration_ns);
      let consent_diff = get_timeline_diff(ballot.YES_NO.consent);

      // TODO: hack to avoid first value
      let apr_diff = undefined;
      const foresight = ballot.YES_NO.foresight;
      if (foresight.history.length > 1) {
        const diff = foresight.current.data.apr.current - foresight.history[1].data.apr.current;
        if (diff !== 0) {
          apr_diff = diff;
        }
      }

      return [
        {
          title: "APR:",
          value: ballot.YES_NO.foresight.current.data.apr.current.toFixed(2) + "%",
          diff: apr_diff !== undefined ? `(${apr_diff > 0 ? "+" : ""}${apr_diff.toFixed(2)}%)` : undefined,
          toggleKey: CHART_TOGGLE.DISCERNMENT,
          chartTimelines: new Map([
            [
              "current",
              {
                timeline: interpolate_now(
                  map_timeline_hack(ballot.YES_NO.foresight, (foresight) => Number(foresight.apr.current)),
                  now
                ),
                color: CHART_COLORS.GREEN,
              },
            ],
          ]),
          formatValue: (value: number) => value.toFixed(2),
          valueClassName: "[text-shadow:0px_0px_10px_rgb(59,130,246)]"
        },
        {
          title: "Mining earned:",
          value: formatBalanceE8s(
            BigInt(Math.floor(contribution.current.data.earned)),
            DSONANCE_COIN_SYMBOL,
            2
          ),
          toggleKey: CHART_TOGGLE.CONTRIBUTION,
          chartTimelines: new Map([
            [
              "earned",
              { timeline: map_timeline_hack(contribution, (contribution) => contribution.earned), color: CHART_COLORS.BLUE },
            ],
            [
              "pending",
              { timeline: map_timeline_hack(contribution, (contribution) => contribution.pending), color: CHART_COLORS.PURPLE },
            ],
          ]),
          formatValue: (value: number) => formatBalanceE8s(BigInt(value), DSONANCE_COIN_SYMBOL, 2),
        },
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
              : formatDuration(get_current(unwrapLock(ballot).duration_ns).data),
          diff: duration_diff !== undefined ? `(+ ${formatDuration(duration_diff)})` : undefined,
          toggleKey: CHART_TOGGLE.DURATION,
          chartTimelines:
            releaseTimestamp > now
              ? new Map([
                  [
                    "time_left",
                    {
                      timeline: to_number_timeline(to_time_left(unwrapLock(ballot).duration_ns, now)),
                      color: CHART_COLORS.PURPLE,
                    },
                  ],
                ])
              : new Map([
                  [
                    "duration",
                    {
                      timeline: to_number_timeline(unwrapLock(ballot).duration_ns),
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
          <ChartCard key={index} {...item} chartToggle={chartToggle} setChartToggle={setChartToggle} />
        ))}
      </div>
    );
}

const BallotView : React.FC<BallotDetailsProps> = ({ ballot, now }) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const navigate = useNavigate();
  const { formatSatoshis } = useCurrencyContext();

  const { data: vote, call: refreshVote } = backendActor.useQueryCall({
      functionName: 'get_vote',
      args: [{ vote_id: ballot.YES_NO.vote_id }],
  });

  const { data: debtInfo, call: refreshDebtInfo } = protocolActor.useQueryCall({
    functionName: "get_debt_info",
    args: [ballot.YES_NO.ballot_id],
    onSuccess: (b) => console.log("Debt info", b)
  });

  useEffect(() => {
    refreshVote();
    refreshDebtInfo();
  }
  , [ballot]);

  const actualVote = useMemo(() => {
    return vote ? fromNullable(vote) : undefined;
  }
  , [vote]);

  const actualDebtInfo = useMemo(() => {
    return debtInfo ? fromNullable(debtInfo) : undefined;
  }
  , [debtInfo]);

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
      <BallotDetails ballot={ballot} now={now} contribution={actualDebtInfo?.amount}/>
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