import { useContext, useEffect, useMemo, useRef, useState } from "react";
import { STimeline_3, YesNoAggregate }                      from "@/declarations/protocol/protocol.did";
import { SYesNoVote }                                       from "@/declarations/backend/backend.did";
import { EYesNoChoice }                                     from "../../utils/conversions/yesnochoice";
import { AreaBumpSerie, ResponsiveAreaBump }                from "@nivo/bump";
import { BallotInfo }                                       from "../types";
import { DurationUnit, toNs }                               from "../../utils/conversions/durationUnit";
import { CHART_CONFIGURATIONS, computeInterval }            from ".";
import IntervalPicker                                       from "./IntervalPicker";
import { useCurrencyContext }                               from "../CurrencyContext";
import { ThemeContext }                                     from "../App";
import { useProtocolContext }                               from "../ProtocolContext";
import { useMediaQuery }                                    from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY }                           from "../../constants";

// WATCHOUT: This component uses an IntractiveAreaBump chart which uses X as a category, not as a time value, hence it is 
// up to the coder to make it so the interval between the time values are constant.

interface Size {
  width: number;
  height: number;
}

interface ComputeChartPropsArgs {
  currentTime: bigint;
  computeDecay: (time: bigint) => number;
  duration: DurationUnit;
  aggregate: STimeline_3;
}

type ChartData = AreaBumpSerie<{x: number; y: number;}, {id: string; data: {x: number; y: number;}[], color: string}>[];
type ChartProperties = { chartData: ChartData, total: { maximum: number, current: number }, priceLevels: number[], dateTicks: number[] };

const computeChartProps = ({ currentTime, computeDecay, duration, aggregate } : ComputeChartPropsArgs) : ChartProperties => {

  let chartData : ChartData = [
    { id: EYesNoChoice.Yes, data: [], color: "rgb(7 227 68)" },
    { id: EYesNoChoice.No, data: [], color: "rgb(0 203 253)" },
  ];

  const { dates, ticks } = computeInterval(currentTime, duration, computeDecay);

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

interface VoteChartrops {
  vote: SYesNoVote;
  ballot: BallotInfo;
}

const VoteChart: React.FC<VoteChartrops> = ({ vote, ballot }) => {

  const { theme } = useContext(ThemeContext);
  const [duration, setDuration] = useState<DurationUnit>(DurationUnit.WEEK);
  
  const [containerSize, setContainerSize] = useState<Size | undefined>(undefined); // State to store the size of the div
  const containerRef = useRef<HTMLDivElement>(null); // Ref for the div element

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const AXIS_MARGIN = isMobile ? 20 : 30;

  useEffect(() => {
    // Function to update the size
    const updateSize = () => {
      if (containerRef.current) {
        setContainerSize({ 
          width: containerRef.current.offsetWidth - 20, // 20 px to make room for the slider bar if any
          height: containerRef.current.offsetWidth * (isMobile ? 0.5 : 0.35)
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

  const { info, parameters, computeDecay } = useProtocolContext();
     
  const voteData = useMemo<ChartProperties>(() => {
    if (!info || !parameters || !computeDecay) {
      return ({ chartData: [], total: { current: 0, maximum: 0 }, priceLevels: [], dateTicks: [] });
    }
    return computeChartProps({ 
      currentTime: info.current_time,
      computeDecay,
      duration,
      aggregate: vote.aggregate 
    });
  }, 
  [info, parameters, computeDecay, duration]);

  useEffect(() => {
    // Set the duration based on the current time
    if (info){
      let timeDifference = info.current_time - vote.aggregate.history[0].timestamp;
      if (timeDifference < toNs(1, DurationUnit.WEEK)){
        setDuration(DurationUnit.WEEK);
      } else if (timeDifference < toNs(1, DurationUnit.MONTH)){
        setDuration(DurationUnit.MONTH);
      } else {
        setDuration(DurationUnit.YEAR);
      }
    }
  }
  , [info]);

  const { chartData, total, priceLevels, dateTicks } = useMemo<ChartProperties>(() => {
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
      dateTicks: voteData.dateTicks
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
    <div className={`flex flex-col items-center space-y-2 w-full ${pulseArea}`} ref={containerRef}>
      { containerSize &&
      <div style={{ position: 'relative', width: `${containerSize.width}px`, height: `${containerSize.height}px`, zIndex: 10 }}>
        { /* TODO: fix opacity of price levels via a custom layer */ }
        <div style={{ position: 'absolute', top: AXIS_MARGIN, right: 0, bottom: AXIS_MARGIN, left: 0, zIndex: 5 }} className="flex flex-col">
          <ul className="flex flex-col w-full" key={vote.vote_id}>
            {
              priceLevels.slice().reverse().map((price, index) => (
                <li key={index}>
                  {
                    (index < (priceLevels.length - 1)) ? 
                    <div className={`flex flex-col w-full`} style={{ height: `${getHeightLine(priceLevels)}px` }}>
                      <div className="flex flex-row w-full items-end" style={{ position: 'relative' }}>
                        { !isMobile && <div className="text-xs" style={{ position: 'absolute', left: -55, bottom: -7 }}>{ formatSatoshis(BigInt(price)) }</div> }
                        <div className="flex w-full h-[2.0px] bg-slate-500 dark:bg-white" style={{ position: 'absolute', bottom: 0, opacity: 0.3 }}/>
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
          margin={{ top: AXIS_MARGIN + marginTop(priceLevels, Math.max(total.maximum, total.current)), bottom: AXIS_MARGIN }}
          spacing={0}
          activeBorderOpacity={0.5}
          colors={(serie) => serie.color}
          borderColor={(serie) => serie.color}
          fillOpacity={0.8}
          borderWidth={2}
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
                (isMobile && tickIndex % 2) ? <></> :
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
              )}
          }}
        />
      </div>
      }
      <IntervalPicker duration={duration} setDuration={setDuration} availableDurations={[DurationUnit.WEEK, DurationUnit.MONTH, DurationUnit.YEAR]} />
    </div>
  );
}

export default VoteChart;