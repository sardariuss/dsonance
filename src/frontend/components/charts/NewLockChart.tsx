import { useMemo, useEffect, useRef, useState, Fragment, useContext } from 'react';
import { ResponsiveLine, Serie } from '@nivo/line';
import { SBallot, SBallotPreview } from '@/declarations/protocol/protocol.did';
import { DurationUnit, toNs } from '../../utils/conversions/durationUnit';
import { CHART_CONFIGURATIONS, computeTicksMs, isNotFiniteNorNaN } from '.';
import { formatDate, msToNs, nsToMs, timeToDate } from '../../utils/conversions/date';
import { get_current } from '../../utils/timeline';
import { unwrapLock } from '../../utils/conversions/ballot';
import { useCurrencyContext } from '../CurrencyContext';
import { ThemeContext } from '../App';
import { useMediaQuery } from 'react-responsive';
import { MOBILE_MAX_WIDTH_QUERY } from '../../constants';
import { useProtocolContext } from '../ProtocolContext';
import { EYesNoChoice, toEnum } from '../../utils/conversions/yesnochoice';

interface NewLockChartProps {
  ballots: SBallot[];
  ballotPreview: SBallotPreview | undefined;
  duration: DurationUnit;
};

const NewLockChart = ({ ballots, ballotPreview, duration }: NewLockChartProps) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const { theme } = useContext(ThemeContext)

  const [containerWidth, setContainerWidth] = useState<number | undefined>(undefined); // State to store the width of the div
  const containerRef = useRef<HTMLDivElement>(null); // Ref for the div element

  useEffect(() => {
    // Function to update the width
    const updateWidth = () => {
      if (containerRef.current) {
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

  const { info } = useProtocolContext();

  const { data, dateRange, processedSegments, yMax } = useMemo(() => {
  
    let minDate = Infinity;
    let maxDate = -Infinity;

    const data : Serie[] = [];
    type Segment = {
      id: string | number;
      start: { x: Date; y: number};
      mid: { x: Date; y: number};
      end: { x: Date; y: number};
      height: number;
      label: string;
      className: string;
    };
    const segments : Segment[] = [];

    let height_no = 0;
    let height_yes = 250;
    
    const all_ballots : SBallot[] = [...ballots, ...(ballotPreview ? [ballotPreview.new.YES_NO] : [])];

    // Create map of preview ballots
    const previewLockDuration = new Map<string, bigint>();
    if (ballotPreview !== undefined) {
      ballotPreview.previous.forEach((b) => {
        previewLockDuration.set(b.YES_NO.ballot_id, unwrapLock(b.YES_NO).duration_ns.current.data);
      });
    }

    let total_locked = all_ballots.reduce((acc, ballot) => acc + ballot.amount, 0n);

    const padding = (0 / (all_ballots.length));

    all_ballots.forEach((ballot, index) => {
      const { timestamp, amount, ballot_id } = ballot;
      const duration_ns = unwrapLock(ballot).duration_ns;

      // Compute timestamps
      const baseTimestamp = nsToMs(timestamp);
      const initialLockEnd = baseTimestamp + nsToMs(get_current(duration_ns).data);
      const actualLockEnd = baseTimestamp + nsToMs(previewLockDuration.get(ballot_id) ?? get_current(duration_ns).data);

      // Update min and max directly
      if (baseTimestamp < minDate) minDate = baseTimestamp;
      if (actualLockEnd > maxDate) maxDate = actualLockEnd;

      const height = (Number(ballot.amount) / Number(total_locked)) * 250; // total height is 250, 50 is padding

      let y = 0;
      if (toEnum(ballot.choice) === EYesNoChoice.No) {
        y = height_no + (height / 2 + padding);
        height_no += height + padding;
      }
      else {
        y = height_yes - (height / 2 + padding);
        height_yes -= height + padding;
      }
      
      // Generate chart data points for this ballot
      const points = [
        { x: new Date(baseTimestamp), y},
        { x: new Date(actualLockEnd), y},
      ];

      data.push({
        id: index.toString(),
        data: points,
      });

      segments.push({
        id: ballot_id,
        start: points[0],
        mid: { x: new Date(initialLockEnd), y },
        end: points[1],
        height: height,
        label: formatSatoshis(amount) ?? "",
        className: `${toEnum(ballot.choice) === EYesNoChoice.Yes ? "fill-brand-true stroke-brand-true" : "fill-brand-false stroke-brand-false"}
         stroke-1 ${ballot.ballot_id === ballotPreview?.new.YES_NO.ballot_id ? "animate-pulse" : ""}`,
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
      yMax: 250,
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

  interface CustomLayerProps {
    xScale: (value: number | string | Date) => number; // Nivo scale function
    yScale: (value: number | string | Date) => number; // Nivo scale function
  }

  const customLayer = ({ xScale, yScale }: CustomLayerProps) => {
    return (
      <>
        {/* Render custom lines */}
        {processedSegments.map((segment, index) => {
          const { start, mid, end, height, className } = segment;
          
          const x1 = xScale(start.x);
          const x2 = xScale(mid.x);
          const x3 = xScale(end.x);
          const y1 = yScale(start.y);
  
          return (
            <Fragment key={`segment-${index}`}>
              {/* Main line */}
                <rect 
                  key={`rect-${index}`}
                  x={x1}
                  y={y1 - height / 2}
                  width={x2 - x1}
                  height={height}
                  className={className}
                  style={{
                    zIndex: 0,
                    fillOpacity: 0.8,
                  }}
                />
                { (x3 - x2 > 0) && <rect 
                  key={`rect-preview-${index}`}
                  x={x2}
                  y={y1 - height / 2}
                  width={x3 - x2}
                  height={height}
                  className={className + " animate-pulse"}
                  style={{
                    zIndex: 0,
                    fillOpacity: 0.8,
                  }}
                  />
                }
            </Fragment>
          );
        })}
  
        {/* Render custom lock labels */}
        {processedSegments.map((segment, index) => {
          const { start, end, height } = segment;
          const x1 = xScale(start.x);
          const x2 = xScale(end.x);
          const y = yScale(start.y);
  
          return (
            height < 16 ? <></> : // Skip rendering if height is too small
            <text
              key={`label-${index}`}
              x={x1 + (x2 - x1) / 2}
              y={y}
              textAnchor="middle"
              alignmentBaseline="middle"
              fontSize={12}
              fill="white"
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
          height: `${300}px`, // Dynamic height based on data length
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
              min: 0,
              max: yMax,
            }}
            animate={true}
            enableGridY={true}
            enableGridX={false}
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
                      fill: theme === "dark" ? "#AAA" : "#666",
                    }}
                  >
                    { CHART_CONFIGURATIONS.get(duration)!.format(new Date(value)) }
                  </text>
                </g>
              ),
            }}
            enablePoints={false}
            lineWidth={1}
            margin={isMobile ? { top: 25, right: 25, bottom: 25, left: 25 } : { top: 25, right: 25, bottom: 25, left: 60 }}
            markers={info ? [
              {
                axis: 'x',
                value: timeToDate(info.current_time).getTime(),
                lineStyle: {
                  stroke: theme === "dark" ? "yellow" : "black",
                  strokeWidth: 1,
                  zIndex: 20,
                },
                legend: formatDate(timeToDate(info.current_time)),
                legendOrientation: 'horizontal',
                legendPosition: 'top',
                textStyle: {
                  fill: theme === "dark" ? "white" : "black",
                  fontSize: 12,
                }
              },
            ] : []}
            layers={[
              'grid',
              'axes',
              customLayer, // Add custom layer
              'markers',
              'legends',
            ]}
            theme={{
              grid: {
                  line: {
                      strokeWidth: "0.5px",
                  },
              },
            }}
          />
        </div>
      </div>
      }
    </div>
  );
};

export default NewLockChart;
