import { useContext, useMemo } from "react";
import { STimeline_2, YesNoAggregate }                      from "@/declarations/protocol/protocol.did";
import { SYesNoVote }                                       from "@/declarations/backend/backend.did";
import { EYesNoChoice }                                     from "../../utils/conversions/yesnochoice";
import { AreaBumpSerie, ResponsiveAreaBump }                from "@nivo/bump";
import { BallotInfo }                                       from "../types";
import { DurationUnit, toNs }                                     from "../../utils/conversions/durationUnit";
import { CHART_CONFIGURATIONS, chartTheme, computeInterval, DurationParameters } from ".";
import { ThemeContext }                                     from "../App";
import { useProtocolContext }                               from "../context/ProtocolContext";
import { useMediaQuery }                                    from "react-responsive";
import { BRAND_FALSE_COLOR, BRAND_TRUE_COLOR, BRAND_TRUE_COLOR_DARK, 
  MOBILE_MAX_WIDTH_QUERY, TICK_TEXT_COLOR_DARK, TICK_TEXT_COLOR_LIGHT,
  CHART_MOBILE_HORIZONTAL_MARGIN } from "../../constants";
import { useContainerSize } from "../hooks/useContainerSize";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";

// WATCHOUT: This component uses an IntractiveAreaBump chart which uses X as a category, not as a time value, hence it is 
// up to the coder to make it so the interval between the time values are constant.

interface ComputeChartPropsArgs {
  theme: string;
  currentTime: bigint;
  computeDecay: (time: bigint) => number;
  durationWindow: DurationUnit | undefined;
  aggregate: STimeline_2;
}

type ChartData = AreaBumpSerie<{x: number; y: number;}, {id: string; data: {x: number; y: number;}[], color: string}>[];
type ChartProperties = { chartData: ChartData, total: { maximum: number, current: number }, priceLevels: number[], dateTicks: number[], dateFormat: (date: Date) => string; };

// TODO: this is very convoluted, we should try to simplify it
const computeChartProps = ({ theme, currentTime, computeDecay, durationWindow, aggregate } : ComputeChartPropsArgs) : ChartProperties => {

  let chartData : ChartData = [
    { id: EYesNoChoice.Yes, data: [], color: theme === "dark" ? BRAND_TRUE_COLOR_DARK : BRAND_TRUE_COLOR },
    { id: EYesNoChoice.No, data: [], color: BRAND_FALSE_COLOR },
  ];

  let durationParameters : DurationParameters | undefined = undefined;

  if (durationWindow !== undefined) {
    durationParameters = CHART_CONFIGURATIONS.get(durationWindow)!;
  } else {
    let start = aggregate.history.length > 0 ? aggregate.history[0].timestamp : aggregate.current.timestamp;
    const duration = currentTime - start;
    
    let durationUnit = DurationUnit.YEAR;
    if (duration <= toNs(1, DurationUnit.WEEK)){
      durationUnit = DurationUnit.DAY;
    } else if (duration <= toNs(1, DurationUnit.MONTH)) {
      durationUnit = DurationUnit.WEEK;
    } else if (duration <= toNs(1, DurationUnit.YEAR)) {
      durationUnit = DurationUnit.MONTH;
    }

    const { sample, tick, format } = CHART_CONFIGURATIONS.get(durationUnit)!;
    durationParameters = { duration, sample, tick, format };
  }

  let { dates } = computeInterval(currentTime, durationParameters.duration, durationParameters.sample, durationParameters.tick, computeDecay);
  let ticks = dates.filter((_, index) => index % Math.floor(dates.length / 10) === 0).map((date) => date.date);

  let max = 0;
  let total = 0;
  let aggregateIndex = 0;
  let currentAggregate : YesNoAggregate = { 
    total_yes: 0n,
    total_no: 0n,
    current_yes: { "DECAYED" : 0 },
    current_no: { "DECAYED" : 0 }
  };

  let aggregate_history = [...aggregate.history, aggregate.current];
  
  dates.forEach(({ date, decay }) => {
    // Update aggregate while the next timestamp is within range
    while (
      aggregateIndex < aggregate_history.length &&
      date >= Number(aggregate_history[aggregateIndex].timestamp / 1_000_000n)
    ) {
      currentAggregate = aggregate_history[aggregateIndex++].data;
    }

    const yesAggregate = currentAggregate.current_yes.DECAYED / decay;
    const noAggregate = currentAggregate.current_no.DECAYED / decay;

    // Update max total
    total = yesAggregate + noAggregate;
    if (total > max) max = total;
  
    // Push the current data points to chartData
    chartData[0].data.push({ x: date, y: yesAggregate });
    chartData[1].data.push({ x: date, y: noAggregate });
  });

  return {
    chartData,
    total: { maximum: max, current: total },
    priceLevels: computePriceLevels(0, max),
    dateTicks: ticks,
    dateFormat: durationParameters.format,
  }
}

const computePriceLevels = (min: number, max: number) : number[] => {
  const range = max - min;
  let interval = 10 ** Math.floor(Math.log10(range));
  let levels = [];
  let current = Math.floor(min / interval) * interval;
  while (current < max + interval) {
    levels.push(current);
    current += interval;
  }
  return levels;
}

interface CdvChartrops {
  vote: SYesNoVote;
  ballot: BallotInfo;
  durationWindow: DurationUnit | undefined;
}

const CdvChart: React.FC<CdvChartrops> = ({ vote, ballot, durationWindow }) => {

  const { theme } = useContext(ThemeContext);
  
  const { containerSize, containerRef } = useContainerSize();

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const AXIS_MARGIN = isMobile ? 20 : 30;

  const { supplyLedger: { formatAmountUsd } } = useFungibleLedgerContext();

  const { info, parameters, computeDecay } = useProtocolContext();
     
  const voteData = useMemo<ChartProperties>(() => {
    if (!info || !parameters || !computeDecay) {
      return ({ chartData: [], total: { current: 0, maximum: 0 }, priceLevels: [], dateTicks: [], dateFormat: () => "" });
    }
    return computeChartProps({
      theme,
      currentTime: info.current_time,
      computeDecay,
      durationWindow,
      aggregate: vote.aggregate 
    });
  }, 
  [info, parameters, computeDecay, durationWindow, vote.aggregate]);

  const { chartData, total, priceLevels, dateTicks, dateFormat } = useMemo<ChartProperties>(() => {
    const newTotal = { maximum : voteData.total.maximum, current: voteData.total.current + Number(ballot.amount) };
    return {
      chartData : voteData.chartData.slice().map((serie) => {
        if (serie.id === (ballot.choice.toString())) {
          const lastPoint = serie.data[serie.data.length - 1];
          const newLastPoint = { x: lastPoint.x, y: lastPoint.y + Number(ballot.amount) };
          return { id: serie.id, data: [...serie.data.slice(0, serie.data.length - 1), newLastPoint], color: serie.color };
        };
        return serie;
      }),
      total: newTotal,
      priceLevels: computePriceLevels(0, Math.max(newTotal.maximum, newTotal.current)),
      dateTicks: voteData.dateTicks,
      dateFormat: voteData.dateFormat,
    };
  }, [voteData, ballot]);

  
  const getHeightLine = (levels: number[]) => {
    if (containerSize === undefined) {
      throw new Error("Container size is undefined");
    }
    return (containerSize.height - 2 * AXIS_MARGIN) / (levels.length - 1);
  }

  const marginTop = (levels: number[], maxY: number) => {
    if (levels.length === 0) {
      return 0;
    }
    if (containerSize === undefined) {
      throw new Error("Container size is undefined");
    }
    const lastLine = levels[levels.length - 1];
    const ratio = ( lastLine - maxY ) / lastLine;
    const height = containerSize.height - 2 * AXIS_MARGIN;
    return height * ratio;
  }

  const pulseArea = useMemo(() => {
    if (parameters !== undefined && ballot.amount > parameters.minimum_ballot_amount){
      if (ballot.choice === EYesNoChoice.Yes){
        return "pulse-area-true";
      } else {
        return "pulse-area-false";
      }
    }
    return "";
  }
  , [ballot, parameters]);

  return (
    <div className={`flex flex-col items-center space-y-2 w-full h-full ${pulseArea}`} ref={containerRef}>
      { containerSize &&
      <div style={{ position: 'relative', width: `${containerSize.width}px`, height: `${containerSize.height}px`, zIndex: 10 }}>
        { /* TODO: fix opacity of price levels via a custom layer */ }
        <div style={{ position: 'absolute', top: AXIS_MARGIN, right: CHART_MOBILE_HORIZONTAL_MARGIN, bottom: AXIS_MARGIN, left: isMobile ? CHART_MOBILE_HORIZONTAL_MARGIN : 60, zIndex: 5 }} className="flex flex-col">
          <ul className="flex flex-col w-full" key={vote.vote_id}>
            {
              priceLevels.slice().reverse().map((price, index) => (
                <li key={index}>
                  {
                    (index < (priceLevels.length - 1)) ? 
                    <div className={`flex flex-col w-full`} style={{ height: `${getHeightLine(priceLevels)}px` }}>
                      <div className="flex flex-row w-full items-end" style={{ position: 'relative' }}>
                        { !isMobile && 
                          <div 
                            className="text-xs" 
                            style={{ position: 'absolute', left: -55, bottom: -7, color: theme === "dark" ? TICK_TEXT_COLOR_DARK : TICK_TEXT_COLOR_LIGHT }}>
                            { formatAmountUsd(BigInt(price)) }
                          </div> 
                        }
                        <div className="flex w-full h-[1px] bg-slate-500 dark:bg-white" style={{ position: 'absolute', bottom: 0, opacity: 0.3 }}/>
                      </div>
                    </div> : <></>
                  }
                </li>
              ))
            }
          </ul>
        </div>
        <ResponsiveAreaBump
          layers={['grid', 'areas', 'axes']}
          isInteractive={false}
          animate={false}
          enableGridX={false}
          startLabel={false}
          endLabel={false}
          interpolation="linear"
          xPadding={0} // Important to avoid "bump effects" in the chart (because AreaBump consider the x values as categories)
          align= "end"
          data={chartData}
          margin={{ top: AXIS_MARGIN + marginTop(priceLevels, Math.max(total.maximum, total.current)),  right: CHART_MOBILE_HORIZONTAL_MARGIN, bottom: AXIS_MARGIN, left: isMobile ? CHART_MOBILE_HORIZONTAL_MARGIN : 60 }}
          spacing={0}
          activeBorderOpacity={0.5}
          colors={(serie) => serie.color}
          borderColor={(serie) => serie.color}
          fillOpacity={0.8}
          borderWidth={0}
          blendMode="normal"
          axisTop={null}
          axisBottom={{
            tickSize: 5,
            tickPadding: 5,
            tickRotation: 0,
            tickValues: dateTicks,
            legend: '',
            legendPosition: 'middle',
            legendOffset: 0,
            renderTick: ({ tickIndex, x, y, value }) => {
              return (
                (isMobile || tickIndex % 2) ? <></> :
                <g transform={`translate(${x},${y})`}>
                  <text
                    x={0}
                    y={16}
                    textAnchor="middle"
                    dominantBaseline="central"
                    style={{
                      fontSize: '12px',
                      fill: theme === "dark" ? TICK_TEXT_COLOR_DARK : TICK_TEXT_COLOR_LIGHT,
                    }}
                  >
                    { dateFormat(new Date(value)) }
                  </text>
                </g>
              )}
          }}
          theme={chartTheme(theme)}
        />
      </div>
      }
    </div>
  );
}

export default CdvChart;