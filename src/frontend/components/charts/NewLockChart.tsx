import { useMemo, useEffect, useRef, useState, Fragment, useContext } from 'react';
import { ResponsiveLine, Serie } from '@nivo/line';
import { SBallot, SBallotPreview } from '@/declarations/protocol/protocol.did';
import { DurationUnit, toNs } from '../../utils/conversions/durationUnit';
import { computeAdaptiveTicks } from '.';
import { formatDate, nsToMs, timeToDate } from '../../utils/conversions/date';
import { get_current } from '../../utils/timeline';
import { unwrapLock } from '../../utils/conversions/ballot';
import { useCurrencyContext } from '../CurrencyContext';
import { ThemeContext } from '../App';
import { useMediaQuery } from 'react-responsive';
import { MOBILE_MAX_WIDTH_QUERY } from '../../constants';
import { useProtocolContext } from '../ProtocolContext';
import { EYesNoChoice, toEnum } from '../../utils/conversions/yesnochoice';
import { format } from 'date-fns';

type LockRect = {
  id: string | number;
  start: { x: Date; y: number};
  mid: { x: Date; y: number};
  end: { x: Date; y: number};
  height: number;
  label: string;
  className: string;
};

interface NewLockChartProps {
  ballots: SBallot[];
  ballotPreview: SBallotPreview | undefined;
  durationWindow: DurationUnit;
};

const CHART_HEIGHT = 250;

const NewLockChart = ({ ballots, ballotPreview, durationWindow }: NewLockChartProps) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const { theme } = useContext(ThemeContext)
  const { formatSatoshis } = useCurrencyContext();
  const { info } = useProtocolContext();

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

  const { dateRange, chartData, lockRects, gridX, totalLocked } = useMemo(() => {
  
    let dateRange = { start: Infinity, end: -Infinity };
    const chartData : Serie[] = [];
    const lockRects : LockRect[] = [];
    let gridX : { ticks: number[]; format: string } = { ticks: [], format: "" };
    let totalLocked = 0n;

    if (info === undefined) {
      return { dateRange, chartData, lockRects, gridX };
    }

    dateRange.start = nsToMs(info.current_time - toNs(1, durationWindow));
    dateRange.end = nsToMs(info.current_time);
    
    const all_ballots = [...ballots, ...(ballotPreview ? [ballotPreview.new.YES_NO] : [])];

    // Create map of preview ballots
    const previewLockDuration = new Map<string, bigint>();
    if (ballotPreview !== undefined) {
      ballotPreview.previous.forEach((b) => {
        previewLockDuration.set(b.YES_NO.ballot_id, unwrapLock(b.YES_NO).duration_ns.current.data);
      });
    }

    totalLocked = all_ballots.reduce((acc, ballot) => acc + ballot.amount, 0n);

    let height_no = 0;
    let height_yes = CHART_HEIGHT;

    all_ballots.forEach((ballot, index) => {
      const { timestamp, amount, ballot_id } = ballot;
      const duration_ns = unwrapLock(ballot).duration_ns;

      // Compute timestamps
      const baseTimestamp = nsToMs(timestamp);
      const initialLockEnd = baseTimestamp + nsToMs(get_current(duration_ns).data);
      const actualLockEnd = baseTimestamp + nsToMs(previewLockDuration.get(ballot_id) ?? get_current(duration_ns).data);

      // Skip locks that expired before the start date
      if (actualLockEnd > dateRange.start) { 
      
        // Update the end date to show the full range of the chart
        if (actualLockEnd > dateRange.end) dateRange.end = actualLockEnd;

        const height = (Number(ballot.amount) / Number(totalLocked)) * CHART_HEIGHT;

        let y = 0;
        if (toEnum(ballot.choice) === EYesNoChoice.No) {
          y = height_no + height / 2;
          height_no += height;
        }
        else {
          y = height_yes - height / 2;
          height_yes -= height;
        }
        
        // Generate chart data points for this ballot
        const points = [
          { x: new Date(Math.max(dateRange.start, baseTimestamp)), y},
          { x: new Date(actualLockEnd)                           , y},
        ];

        chartData.push({
          id: index.toString(),
          data: points,
        });

        lockRects.push({
          id: ballot_id,
          start: points[0],
          mid: { x: new Date(initialLockEnd), y },
          end: points[1],
          height: height,
          label: formatSatoshis(amount) ?? "",
          className: `${toEnum(ballot.choice) === EYesNoChoice.Yes ? "fill-brand-true stroke-brand-true" : "fill-brand-false stroke-brand-false"}
            ${ballot.ballot_id === ballotPreview?.new.YES_NO.ballot_id ? "" : ""}`,
        });
      }

    });

    gridX = computeAdaptiveTicks(new Date(dateRange.start), new Date(dateRange.end));

    return { dateRange, chartData, lockRects, gridX, totalLocked };

  }, [ballots, formatSatoshis, info, ballotPreview]);

  const chartRef = useRef<HTMLDivElement>(null);

  interface CustomLayerProps {
    xScale: (value: number | string | Date) => number; // Nivo scale function
    yScale: (value: number | string | Date) => number; // Nivo scale function
  }

  const customLayer = ({ xScale, yScale }: CustomLayerProps) => {
    return (
      <>
        {/* Render custom lines */}
        {lockRects.map((segment, index) => {
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
                  className={className}
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
        {lockRects.map((segment, index) => {
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
      { containerWidth && <div
        ref={chartRef}
        style={{
          width: `${containerWidth}px`, // Dynamic width based on container
          height: `${300}px`,
          overflowX: 'auto',
          overflowY: 'hidden',
        }}
      >
        <div
          style={{
            width: `${containerWidth}px`,
            height: '100%',
          }}
        >
          <ResponsiveLine
            data={chartData}
            xScale={{
              type: 'time',
              precision: 'hour', // Somehow this is important
              min: new Date(dateRange.start),
              max: new Date(dateRange.end),
            }}
            yScale={{
              type: 'linear',
              min: 0,
              max: CHART_HEIGHT,
            }}
            animate={true}
            enableGridY={false}
            enableGridX={true}
            gridXValues={gridX.ticks.map((tick) => new Date(tick))}
            axisBottom={{
              tickSize: 5,
              tickPadding: 5,
              tickRotation: 0,
              tickValues: gridX.ticks,
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
                    { format(new Date(value), gridX.format) }
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
