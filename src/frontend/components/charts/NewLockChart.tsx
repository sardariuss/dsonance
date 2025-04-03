import { useMemo, useEffect, useRef, useState, Fragment, useContext } from 'react';
import { ResponsiveLine, Serie } from '@nivo/line';
import { SBallot, SBallotPreview } from '@/declarations/protocol/protocol.did';
import { DurationUnit, toNs } from '../../utils/conversions/durationUnit';
import { computeAdaptiveTicks, computeNiceGridLines } from '.';
import { nsToMs, timeToDate } from '../../utils/conversions/date';
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
  bottom: number;
  top: number;
  label: string;
  className: string;
};

interface NewLockChartProps {
  ballots: SBallot[];
  ballotPreview: SBallotPreview | undefined;
  durationWindow: DurationUnit;
};

const NewLockChart = ({ ballots, ballotPreview, durationWindow }: NewLockChartProps) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const { theme } = useContext(ThemeContext)
  const { formatSatoshis, satoshisToCurrency } = useCurrencyContext();
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

  const { dateRange, chartData, lockRects, gridX, gridY, totalLocked } = useMemo(() => {
  
    let dateRange = { start: Infinity, end: -Infinity };
    const chartData : Serie[] = [];
    const lockRects : LockRect[] = [];
    let gridX : { ticks: number[]; format: string } = { ticks: [], format: "" };
    let gridY : number[] = [];
    let totalLocked = 0;

    if (info === undefined || satoshisToCurrency === undefined) {
      return { dateRange, chartData, lockRects, gridX, gridY, totalLocked };
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

    totalLocked = all_ballots.reduce((acc, ballot) => { 
      const baseTimestamp = nsToMs(ballot.timestamp);
      const actualLockEnd = baseTimestamp + nsToMs(previewLockDuration.get(ballot.ballot_id) ?? get_current(unwrapLock(ballot).duration_ns).data);
      // Skip locks that expired before the start date
      const to_add = actualLockEnd > dateRange.start ? (satoshisToCurrency(ballot.amount) ?? 0) : 0;
      return acc + to_add;
    }, 0);

    let height_no = 0;
    let height_yes = totalLocked;

    all_ballots.forEach((ballot, index) => {
      const { timestamp, amount, ballot_id, choice } = ballot;
      const duration_ns = unwrapLock(ballot).duration_ns;

      // Compute timestamps
      const baseTimestamp = nsToMs(timestamp);
      const initialLockEnd = baseTimestamp + nsToMs(get_current(duration_ns).data);
      const actualLockEnd = baseTimestamp + nsToMs(previewLockDuration.get(ballot_id) ?? get_current(duration_ns).data);

      // Skip locks that expired before the start date
      if (actualLockEnd > dateRange.start) { 
      
        // Update the end date to show the full range of the chart
        if (actualLockEnd > dateRange.end) dateRange.end = actualLockEnd;

        const height = satoshisToCurrency(amount) ?? 0;

        let y = 0;
        if (toEnum(choice) === EYesNoChoice.No) {
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
          bottom: y - height / 2,
          top: y + height / 2,
          label: formatSatoshis(amount) ?? "",
          className: `${toEnum(choice) === EYesNoChoice.Yes ? "fill-brand-true stroke-brand-true" : "fill-brand-false stroke-brand-false"}
            ${ballot_id === ballotPreview?.new.YES_NO.ballot_id ? " animate-pulse" : " "}`,
        });
      }

    });

    gridX = computeAdaptiveTicks(new Date(dateRange.start), new Date(dateRange.end));
    gridY = computeNiceGridLines(0, totalLocked).filter((tick) => tick <= totalLocked);

    return { dateRange, chartData, lockRects, gridX, gridY, totalLocked };

  }, [ballots, formatSatoshis, info, ballotPreview, satoshisToCurrency, durationWindow]);

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
          const { start, mid, end, bottom, top, className } = segment;
          
          const x1 = xScale(start.x);
          const x2 = xScale(mid.x);
          const x3 = xScale(end.x);
          const y1 = yScale(start.y);
          const height = yScale(bottom) - yScale(top);
  
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
        {lockRects.map((segment, index) => {
          const { start, end, bottom, top } = segment;
          const x1 = xScale(start.x);
          const x2 = xScale(end.x);
          const y = yScale(start.y);
          const height = yScale(bottom) - yScale(top);
  
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
              max: totalLocked,
            }}
            animate={true}
            enableGridX={false}
            enableGridY={true}
            gridXValues={gridX.ticks.map((tick) => new Date(tick))}
            gridYValues={gridY}
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
            axisLeft={{
              tickSize: 5,
              tickPadding: 10,
              tickRotation: 0,
              tickValues: gridY,
              legend: '',
              legendPosition: 'middle',
              legendOffset: 64,
            }}
            enablePoints={false}
            lineWidth={1}
            margin={isMobile ? { top: 25, right: 25, bottom: 25, left: 25 } : { top: 25, right: 25, bottom: 25, left: 60 }}
            markers={info ? [
              {
                axis: 'x',
                value: timeToDate(info.current_time).getTime(),
                lineStyle: {
                  stroke: theme === "dark" ? "#ccc" : "#666",
                  strokeWidth: 1,
                  zIndex: 20,
                },
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
              axis: {
                ticks: {
                  text: {
                    fontSize: '12px',
                    fill: theme === "dark" ? "#AAA" : "#666",
                  },
                },
              },
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
