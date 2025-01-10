import { useMemo, useEffect, useRef, useState, Fragment } from 'react';
import { ResponsiveLine, Serie } from '@nivo/line';
import { CHART_BACKGROUND_COLOR } from '../../constants';
import { SBallotType } from '@/declarations/protocol/protocol.did';
import IntervalPicker from './IntervalPicker';
import { DurationUnit, toNs } from '../../utils/conversions/duration';
import { CHART_CONFIGURATIONS, computeTicksMs, isNotFiniteNorNaN } from '.';
import { protocolActor } from '../../actors/ProtocolActor';
import { formatDate, msToNs, nsToMs, timeToDate } from '../../utils/conversions/date';
import { get_current, get_first } from '../../utils/timeline';
import { unwrapLock } from '../../utils/conversions/ballot';
import { useCurrencyContext } from '../CurrencyContext';

interface LockChartProps {
  ballots: SBallotType[];
  selected: number | undefined;
  select_ballot: (index: number | undefined) => void;
};

const LockChart = ({ ballots, selected, select_ballot }: LockChartProps) => {

  const [containerWidth, setContainerWidth] = useState<number | undefined>(undefined); // State to store the width of the div
  
  const containerRef = useRef<HTMLDivElement>(null); // Ref for the div element

  useEffect(() => {
    // Function to update the width
    const updateWidth = () => {
      if (containerRef.current) {
        console.log("Container width: ", containerRef.current.offsetWidth);
        setContainerWidth(containerRef.current.offsetWidth - 20); // 20 px to make room for the slider bar if any
      }
    };

    // Set initial width
    updateWidth();

    // Update width on window resize
    window.addEventListener('resize', updateWidth);

    return () => {
      window.removeEventListener('resize', updateWidth);
    };
  }, []);

  const { formatSatoshis } = useCurrencyContext();

  const { data: currentTime } = protocolActor.useQueryCall({
    functionName: "get_time",
  });

  const [duration, setDuration] = useState<DurationUnit>(DurationUnit.YEAR);

  const { data, dateRange, processedSegments } = useMemo(() => {
  
    let minDate = Infinity;
    let maxDate = -Infinity;

    const data : Serie[] = [];
    type Segment = {
      id: string | number;
      start: { x: Date; y: number};
      end: { x: Date; y: number};
      percentage: number;
      label: string;
    };
    const segments : Segment[] = [];

    ballots.forEach((ballot, index) => {
      const { YES_NO: { timestamp, amount } } = ballot;
      const duration_ns = unwrapLock(ballot).duration_ns;

      // Compute timestamps
      const baseTimestamp = nsToMs(timestamp);
      const initialLockEnd = baseTimestamp + nsToMs(get_first(duration_ns).data);
      const actualLockEnd = baseTimestamp + nsToMs(get_current(duration_ns).data);

      // Update min and max directly
      if (baseTimestamp < minDate) minDate = baseTimestamp;
      if (actualLockEnd > maxDate) maxDate = actualLockEnd;

      let y = ballots.length - index - 1; // Reverse order

      // Generate chart data points for this ballot
      const points = [
        { x: new Date(baseTimestamp), y},
        { x: new Date(actualLockEnd), y},
      ];

      data.push({
        id: index.toString(), // Use index as id
        data: points,
      });

      segments.push({
        id: index.toString(),
        start: points[0],
        end: points[1],
        percentage: ((initialLockEnd - baseTimestamp) / (actualLockEnd - baseTimestamp)) * 100,
        label: formatSatoshis(amount)
      });
    });

    const nsDiff = (maxDate - minDate) * 1_000_000; // Nanoseconds difference

    return {
      data,
      processedSegments: segments,
      dateRange: {
        minDate,
        maxDate,
        nsDiff,
      },
    };
  }, [ballots, formatSatoshis]);

  // Precompute width and ticks for all durations in CHART_CONFIGURATIONS
  const chartConfigurationsMap = useMemo(() => {

    const map = new Map<DurationUnit, { chartWidth: number; ticks: number[] }>();

    if (containerWidth === undefined) {
      return map;
    }

    for (const [duration, config] of CHART_CONFIGURATIONS.entries()) {
      if (isNotFiniteNorNaN(dateRange.minDate) || isNotFiniteNorNaN(dateRange.maxDate)) {
        map.set(duration, { chartWidth: 0, ticks: [] });
      } else {
        const chartWidth = Math.max(
          1,
          dateRange.nsDiff / Number(toNs(1, duration))
        ) * containerWidth; // Adjusted width

        const ticks = computeTicksMs(
          msToNs(dateRange.maxDate - dateRange.minDate),
          msToNs(dateRange.minDate),
          config.tick
        );

        map.set(duration, { chartWidth, ticks });
      }
    }

    return map;
  }, [dateRange, containerWidth]);
  
  type ChartConfiguration = {
    chartWidth: number;
    ticks: number[];
  };

  const [config, setConfig] = useState<ChartConfiguration | undefined>(undefined);

  useEffect(() => {
    setConfig(chartConfigurationsMap.get(duration));
  },
  [chartConfigurationsMap, duration]);

  const chartRef = useRef<HTMLDivElement>(null);

//  useEffect(() => {
//    const currentDate = new Date();
//    const currentDateTimestamp = currentDate.getTime();
//
//    // Scroll center calculation
//    const rangeStart = dateRange.minDate;
//    const rangeEnd = dateRange.maxDate;
//    const totalRange = rangeEnd - rangeStart;
//
//    // Calculate the position of the current date within the time range
//    const relativePosition = (currentDateTimestamp - rangeStart) / totalRange;
//
//    // Calculate the scroll position to center the current date
//    const scrollPosition = relativePosition * (chartWidth - containerWidth); // Adjusted by the chart width and visible area
//
//    if (chartRef.current) {
//      chartRef.current.scrollLeft = scrollPosition;
//    }
//  }, [dateRange, chartWidth, containerWidth]);

  interface CustomLayerProps {
    xScale: (value: number | string | Date) => number; // Nivo scale function
    yScale: (value: number | string | Date) => number; // Nivo scale function
  }

  const customLayer = ({ xScale, yScale }: CustomLayerProps) => {
    return (
      <>
        {/* Render custom lines */}
        {processedSegments.map((segment, index) => {
          const { start, end } = segment;
          const x1 = xScale(start.x);
          const x2 = xScale(end.x);
          const y1 = yScale(start.y);
          const y2 = yScale(end.y);

          const id = Number(segment.id)

          const border_width = 2;
  
          return (
            <Fragment key={`segment-${index}`}>
              {/* Border line */}
              { id === selected && <line
                key={`border-${index}`}
                x1={x1-border_width}
                x2={x2+border_width}
                y1={y1}
                y2={y2}
                stroke={"rgb(59 130 246)"} // Border color
                strokeWidth={20 + 2 * border_width} // Slightly larger than the main line
                strokeLinejoin="round"
                style={{
                  zIndex: 0
                }}
              /> }

              {/* Main line */}
              <svg width="100%" height="100%" xmlns="http://www.w3.org/2000/svg">
                <defs>
                  <linearGradient id={`lineGradient-${index}`} gradientUnits="userSpaceOnUse" x1={x1} x2={x2} y1={y1} y2={y2}>
                    <stop offset="0%" stopColor="#1B63EB" />
                    <stop offset={segment.percentage.toFixed(2) + "%"} stopColor="#1B63EB" />
                    <stop offset={segment.percentage.toFixed(2) + "%"} stopColor="#1B63EB" />
                    <stop offset="100%" stopColor="#A21CAF">
                      <animate
                        attributeName="stop-color"
                        values="#A21CAF;#E11D48;#A21CAF" // bg-fuchsia-700 & bg-rose-600
                        dur="5s" 
                        repeatCount="indefinite" 
                      />
                    </stop>
                  </linearGradient>
                </defs>
                <line
                  key={`line-${index}`}
                  x1={x1}
                  x2={x2}
                  y1={y1}
                  y2={y2}
                  stroke={`url(#lineGradient-${index})`}
                  strokeWidth={20}
                  onClick={() => select_ballot(selected === id ? undefined : id)}
                  cursor="pointer"
                  style={{
                    zIndex: 1
                  }}
                />
              </svg>
            </Fragment>
          );
        })}
  
        {/* Render custom lock labels */}
        {processedSegments.map((segment, index) => {
          const { start, end } = segment;
          const id = Number(segment.id);
          const x1 = xScale(start.x);
          const x2 = xScale(end.x);
          const y = yScale(start.y);
  
          return (
            <text
              key={`label-${index}`}
              x={x1 + (x2 - x1) / 2}
              y={y}
              textAnchor="middle"
              alignmentBaseline="middle"
              fontSize={12}
              fill="white"
              onClick={() => select_ballot(selected === id ? undefined : id)}
              cursor="pointer"
            >
              {segment.label}
            </text>
          );
        })}
      </>
    );
  };

  return (
    <div className="flex flex-col items-center space-y-2 w-full" ref={containerRef}>
      { containerWidth && config && <div
        ref={chartRef}
        style={{
          width: `${containerWidth}px`, // Dynamic width based on container
          height: `${data.length * 80}px`, // Dynamic height based on data length
          overflowX: 'auto',
          overflowY: 'hidden',
        }}
      >
        <div
          style={{
            width: `${config.chartWidth}px`, // Dynamic width based on data range
            height: '100%',
          }}
        >
          <ResponsiveLine
            data={data}
            xScale={{
              type: 'time',
              precision: 'hour', // Somehow this is important
            }}
            yScale={{
              type: 'linear',
              min: -0.5,
              max: data.length - 0.5,
            }}
            animate={false}
            enableGridY={false}
            enableGridX={true}
            gridXValues={config.ticks.map((tick) => new Date(tick))}
            axisBottom={{
              tickSize: 5,
              tickPadding: 5,
              tickRotation: 0,
              tickValues: config.ticks,
              legend: '',
              legendPosition: 'middle',
              legendOffset: 64,
              renderTick: ({ x, y, value }) => (
                <g transform={`translate(${x},${y})`}>
                  <text
                    x={0}
                    y={16}
                    textAnchor="middle"
                    dominantBaseline="central"
                    style={{
                      fontSize: '12px',
                      fill: 'gray',
                    }}
                  >
                    { CHART_CONFIGURATIONS.get(duration)!.format(new Date(value)) }
                  </text>
                </g>
              ),
            }}
            axisLeft={null}
            enablePoints={false}
            lineWidth={20}
            margin={{ top: 50, right: 50, bottom: 50, left: 60 }}
            markers={currentTime ? [
              {
                axis: 'x',
                value: timeToDate(currentTime).getTime(), // Convert string to timestamp
                lineStyle: {
                  stroke: 'yellow',
                  strokeWidth: 1,
                  zIndex: 20,
                },
                legend: formatDate(timeToDate(currentTime)),
                legendOrientation: 'horizontal',
                legendPosition: 'top',
                textStyle: {
                  fill: 'white',
                  fontSize: 12,
                }
              },
            ] : []}
            theme={{
              background: CHART_BACKGROUND_COLOR,
            }}
            layers={[
              'grid',
              'axes',
              'lines',
              customLayer, // Add custom layer
              'markers',
              'legends',
            ]}
          />
        </div>
      </div>
      }
      <IntervalPicker duration={duration} setDuration={setDuration} availableDurations={[DurationUnit.MONTH, DurationUnit.YEAR]}  />
    </div>
  );
};

export default LockChart;
