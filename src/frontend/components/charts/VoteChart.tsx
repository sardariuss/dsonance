import { useContext, useEffect, useMemo, useRef, useState } from "react";
import { DecayParameters, STimeline_3, YesNoAggregate }     from "@/declarations/protocol/protocol.did";
import { SYesNoVote }                                       from "@/declarations/backend/backend.did";
import { EYesNoChoice }                                     from "../../utils/conversions/yesnochoice";
import { AreaBumpSerie, ResponsiveAreaBump }                from "@nivo/bump";
import { BallotInfo }                                       from "../types";
import { DurationUnit, toNs }                               from "../../utils/conversions/duration";
import { CHART_CONFIGURATIONS, computeInterval }            from ".";
import IntervalPicker                                       from "./IntervalPicker";
import { useCurrencyContext }                               from "../CurrencyContext";
import { ThemeContext }                                     from "../App";
import { useProtocolInfoContext }                           from "../ProtocolInfoContext";

// WATCHOUT: This component uses an IntractiveAreaBump chart which uses X as a category, not as a time value, hence it is 
// up to the coder to make it so the interval between the time values are constant.

interface Size {
  width: number;
  height: number;
}

interface ComputeChartPropsArgs {
  currentTime: bigint;
  decayParams: DecayParameters;
  duration: DurationUnit;
  aggregate: STimeline_3;
}

type ChartData = AreaBumpSerie<{x: number; y: number;}, {id: string; data: {x: number; y: number;}[]}>[];
type ChartProperties = { chartData: ChartData, total: { maximum: number, current: number }, priceLevels: number[], dateTicks: number[] };

const computeChartProps = ({ currentTime, decayParams, duration, aggregate } : ComputeChartPropsArgs) : ChartProperties => {

  let chartData : ChartData = [
    { id: EYesNoChoice.Yes, data: [] },
    { id: EYesNoChoice.No, data: [] },
  ];

  const { dates, ticks } = computeInterval(currentTime, duration, decayParams);

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
    dateTicks: ticks
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

const MARGIN = 50;

interface VoteChartrops {
  vote: SYesNoVote;
  ballot: BallotInfo;
}

const VoteChart: React.FC<VoteChartrops> = ({ vote, ballot }) => {

  const { theme } = useContext(ThemeContext);
  const [duration, setDuration] = useState<DurationUnit>(DurationUnit.WEEK);
  
  const [containerSize, setContainerSize] = useState<Size | undefined>(undefined); // State to store the size of the div
  const containerRef = useRef<HTMLDivElement>(null); // Ref for the div element

  useEffect(() => {
    // Function to update the size
    const updateSize = () => {
      if (containerRef.current) {
        setContainerSize({ 
          width: containerRef.current.offsetWidth - 20, // 20 px to make room for the slider bar if any
          height: containerRef.current.offsetWidth * 0.5
        });
      }
    };

    // Set initial size
    updateSize();

    // Update size on window resize
    window.addEventListener('resize', updateSize);

    return () => {
      window.removeEventListener('resize', updateSize);
    };
  }, []);

  const { formatSatoshis } = useCurrencyContext();

  const { info: { currentTime, decayParams} } = useProtocolInfoContext();
     
  const voteData = useMemo<ChartProperties>(() => {
    if (!currentTime || !decayParams) {
      return ({ chartData: [], total: { current: 0, maximum: 0 }, priceLevels: [], dateTicks: [] });
    }
    return computeChartProps({ 
      currentTime,
      decayParams,
      duration,
      aggregate: vote.aggregate 
    });
  }, 
  [currentTime, decayParams, duration]);

  useEffect(() => {
    // Set the duration based on the current time
    if (currentTime){
      let timeDifference = currentTime - vote.aggregate.history[0].timestamp;
      if (timeDifference < toNs(1, DurationUnit.WEEK)){
        setDuration(DurationUnit.WEEK);
      } else if (timeDifference < toNs(1, DurationUnit.MONTH)){
        setDuration(DurationUnit.MONTH);
      } else {
        setDuration(DurationUnit.YEAR);
      }
    }
  }
  , [currentTime]);

  const { chartData, total, priceLevels, dateTicks } = useMemo<ChartProperties>(() => {
    const newTotal = { maximum : voteData.total.maximum, current: voteData.total.current + Number(ballot.amount) };
    return {
      chartData : voteData.chartData.slice().map((serie) => {
        if (serie.id === (ballot.choice.toString())) {
          const lastPoint = serie.data[serie.data.length - 1];
          const newLastPoint = { x: lastPoint.x, y: lastPoint.y + Number(ballot.amount) };
          return { id: serie.id, data: [...serie.data.slice(0, serie.data.length - 1), newLastPoint] };
        };
        return serie;
      }),
      total: newTotal,
      priceLevels: computePriceLevels(0, Math.max(newTotal.maximum, newTotal.current)),
      dateTicks: voteData.dateTicks
    };
  }, [voteData, ballot]);

  
  const getHeightLine = (levels: number[]) => {
    if (containerSize === undefined) {
      throw new Error("Container size is undefined");
    }
    return (containerSize.height - 2 * MARGIN) / (levels.length - 1);
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
    const height = containerSize.height - 2 * MARGIN;
    return height * ratio;
  }

  return (
    <div className="flex flex-col items-center space-y-2 w-full" ref={containerRef}>
      { containerSize &&
      <div style={{ position: 'relative', width: `${containerSize.width}px`, height: `${containerSize.height}px` }}>
        <div style={{ position: 'absolute', top: MARGIN, right: 59, bottom: MARGIN, left: 59 }} className="flex flex-col border-x border-slate-300 z-10">
          <ul className="flex flex-col w-full" key={vote.vote_id}>
            {
              priceLevels.slice().reverse().map((price, index) => (
                <li key={index}>
                  {
                    (index < (priceLevels.length - 1)) ? 
                    <div className={`flex flex-col w-full`} style={{ height: `${getHeightLine(priceLevels)}px` }}>
                      <div className="flex flex-row w-full items-end" style={{ position: 'relative' }}>
                        <div className="text-xs" style={{ position: 'absolute', left: -55, bottom: -7 }}>{ formatSatoshis(BigInt(price)) }</div>
                        <div className="flex w-full h-[0.5px] bg-slate-500 dark:bg-white opacity-50" style={{ position: 'absolute', bottom: 0 }}/>
                      </div>
                    </div> : <></>
                  }
                </li>
              ))
            }
          </ul>
        </div>
        <ResponsiveAreaBump
          isInteractive={false}
          animate={false}
          enableGridX={false}
          startLabel={false}
          endLabel={false}
          interpolation="linear"
          xPadding={0} // Important to avoid "bump effects" in the chart (because AreaBump consider the x values as categories)
          align= "end"
          data={chartData}
          margin={{ top: MARGIN + marginTop(priceLevels, Math.max(total.maximum, total.current)), right: 60, bottom: MARGIN, left: 0 }}
          spacing={0}
          colors={["rgb(7 227 68)", "rgb(0 203 253)"]} // brand-true, brand-false
          blendMode="normal"
          borderColor={theme === "dark" ? "rgba(255, 255, 255, 0.5)" : "rgba(0, 0, 0, 0.5)"}
          axisTop={null}
          axisBottom={{
            tickSize: 5,
            tickPadding: 5,
            tickRotation: 0,
            tickValues: dateTicks,
            legend: '',
            legendPosition: 'middle',
            legendOffset: 0,
            renderTick: ({ x, y, value }) => (
              <g transform={`translate(${x},${y})`}>
                <text
                  x={0}
                  y={16}
                  textAnchor="middle"
                  dominantBaseline="central"
                  style={{
                    fontSize: '12px',
                    fill: theme === "dark" ? "white" : "rgb(30 41 59)", // slate-800
                  }}
                >
                  { CHART_CONFIGURATIONS.get(duration)!.format(new Date(value)) }
                </text>
              </g>
            ),
          }}
        />
      </div>
      }
      <IntervalPicker duration={duration} setDuration={setDuration} availableDurations={[DurationUnit.WEEK, DurationUnit.MONTH, DurationUnit.YEAR]} />
    </div>
  );
}

export default VoteChart;