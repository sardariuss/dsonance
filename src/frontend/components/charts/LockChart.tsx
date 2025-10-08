import { useMemo, useRef, Fragment, useContext } from 'react';
import { ResponsiveLine, Serie } from '@nivo/line';
import { SBallot, SPutBallotSuccess } from '@/declarations/protocol/protocol.did';
import { DurationUnit, toNs } from '../../utils/conversions/durationUnit';
import { computeAdaptiveTicks, computeNiceGridLines } from '.';
import { nsToMs, timeToDate } from '../../utils/conversions/date';
import { get_current } from '../../utils/timeline';
import { unwrapLock } from '../../utils/conversions/ballot';
import { ThemeContext } from '../App';
import { useMediaQuery } from 'react-responsive';
import { MOBILE_MAX_WIDTH_QUERY, TICK_TEXT_COLOR_DARK, TICK_TEXT_COLOR_LIGHT } from '../../constants';
import { useProtocolContext } from '../context/ProtocolContext';
import { EYesNoChoice, toEnum } from '../../utils/conversions/yesnochoice';
import { format } from 'date-fns';
import { useContainerSize } from '../hooks/useContainerSize';
import { useFungibleLedgerContext } from '../context/FungibleLedgerContext';

type LockRect = {
  id: string;
  start: { x: Date; y: number};
  mid: { x: Date; y: number};
  end: { x: Date; y: number};
  bottom: number;
  top: number;
  label: string;
  choice: EYesNoChoice;
};

type ChartProperties = {
  dateRange: { start: number; end: number };
  chartData: Serie[];
  lockRects: LockRect[];
  gridX: { ticks: number[]; format: string };
  gridY: number[];
  totalLocked: number;
};

type Selectable = {
  selected: string | null;
  select_ballot: (id: string) => void;
};

interface LockChartProps {
  ballots: SBallot[];
  ballotPreview: SPutBallotSuccess | undefined;
  durationWindow: DurationUnit | undefined;
  selectable?: Selectable;
};

const LockChart = ({ ballots, ballotPreview, durationWindow, selectable }: LockChartProps) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const { theme } = useContext(ThemeContext);
  const { supplyLedger: { formatAmount, convertToFloatingPoint } } = useFungibleLedgerContext();
  const { info } = useProtocolContext();
  const { containerSize, containerRef } = useContainerSize();

  const chartProperties : ChartProperties | undefined = useMemo(() => {

    if (info === undefined || convertToFloatingPoint === undefined) {
      return undefined;
    }

    const chartData : Serie[] = [];
    const lockRects : LockRect[] = [];
    let gridX : { ticks: number[]; format: string } = { ticks: [], format: "" };
    let gridY : number[] = [];
    let totalLocked = 0;

    const all_ballots = [...ballots, ...(ballotPreview ? [ballotPreview.new.YES_NO] : [])];

    const dateStart = durationWindow !== undefined
      ? nsToMs(info.current_time - toNs(1, durationWindow))
      : all_ballots.reduce((acc, ballot) => Math.min(acc, nsToMs(ballot.timestamp)), Number.POSITIVE_INFINITY);
    let dateEnd = nsToMs(info.current_time);

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
      const to_add = (dateStart === undefined || actualLockEnd > dateStart) ? (convertToFloatingPoint(ballot.amount) ?? 0) : 0;
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
      if (dateStart === undefined || actualLockEnd > dateStart) { 
      
        // Update the end date to show the full range of the chart
        if (actualLockEnd > dateEnd) dateEnd = actualLockEnd;

        const height = convertToFloatingPoint(amount) ?? 0;

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
          { x: new Date(Math.max(dateStart, baseTimestamp)), y},
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
          label: formatAmount(amount) ?? "",
          choice: toEnum(choice),
        });
      }

    });

    gridX = computeAdaptiveTicks(new Date(dateStart), new Date(dateEnd));
    gridY = computeNiceGridLines(0, totalLocked).filter((tick) => tick <= totalLocked);

    return { dateRange : { start: dateStart, end: dateEnd }, chartData, lockRects, gridX, gridY, totalLocked };

  }, [ballots, formatAmount, info, ballotPreview, convertToFloatingPoint, durationWindow]);

  const chartRef = useRef<HTMLDivElement>(null);

  interface CustomLayerProps {
    xScale: (value: number | string | Date) => number; // Nivo scale function
    yScale: (value: number | string | Date) => number; // Nivo scale function
  }

  const customLayer = ({ xScale, yScale }: CustomLayerProps) => {
    return (
      <>
        {/* Render custom lines */}
        { chartProperties?.lockRects.map((segment, index) => {
          const { id, start, mid, end, bottom, top, choice } = segment;
          
          const x1 = xScale(start.x);
          const x2 = xScale(mid.x);
          const x3 = xScale(end.x);
          const y1 = yScale(start.y);
          const height = yScale(bottom) - yScale(top);

          let className = "";
          if (selectable !== undefined) {
            className = "fill-blue-700 hover:cursor-pointer";
            if (selectable.selected === id) {
              className += " stroke-2 stroke-blue-900 dark:stroke-blue-400";
            } else {
              className += " stroke-1 stroke-blue-800 dark:stroke-blue-500";
            }
          } else if (choice === EYesNoChoice.Yes) {
            className = "fill-brand-true dark:fill-brand-true-dark stroke-2 stroke-brand-true dark:stroke-brand-true-dark";
          }
          else if (choice === EYesNoChoice.No) {
            className = "fill-brand-false stroke-2 stroke-brand-false";
          }

          // Highlight the preview ballot
          if (ballotPreview !== undefined && id === ballotPreview.new.YES_NO.ballot_id) {
            className += " animate-pulse";
          }
  
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
                  onClick={() =>{
                    if (selectable) {
                      selectable.select_ballot(id);
                    }
                  }}
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
        { chartProperties?.lockRects.map((segment, index) => {
          const { id, start, end, bottom, top } = segment;
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
              onClick={() =>{
                if (selectable) {
                  selectable.select_ballot(id);
                }
              }}
              className={`${selectable? "hover:cursor-pointer": ""} ${selectable?.selected === id ? "font-semibold" : ""}`}
            >
              {segment.label}
            </text>
          );
        })}
      </>
    );
  };

  return (
    <div className="flex flex-col items-center space-y-2 w-full h-full" ref={containerRef}>
      { containerRef && containerSize && <div
        ref={chartRef}
        style={{
          width: `${containerSize.width}px`,
          height: `${containerSize.height}px`,
          overflowX: 'auto',
          overflowY: 'hidden',
        }}
      >
        <div
          style={{
            width: `${containerSize}px`,
            height: '100%',
          }}
        >
          { chartProperties && <ResponsiveLine
            data={chartProperties.chartData}
            xScale={{
              type: 'time',
              precision: 'hour', // Somehow this is important
              min: new Date(chartProperties.dateRange.start),
              max: new Date(chartProperties.dateRange.end),
            }}
            yScale={{
              type: 'linear',
              min: 0,
              max: chartProperties.totalLocked,
            }}
            animate={true}
            enableGridX={false}
            enableGridY={true}
            gridXValues={chartProperties.gridX.ticks.map((tick) => new Date(tick))}
            gridYValues={chartProperties.gridY}
            axisBottom={{
              tickSize: 5,
              tickPadding: 5,
              tickRotation: 0,
              tickValues: chartProperties.gridX.ticks,
              legend: '',
              legendPosition: 'middle',
              legendOffset: 64,
              renderTick: ({ x, y, value }) => (
                isMobile ? <></> :
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
                    { format(new Date(value), chartProperties.gridX.format) }
                  </text>
                </g>
              ),
            }}
            axisLeft={{
              tickSize: 5,
              tickPadding: 10,
              tickRotation: 0,
              tickValues: isMobile ? [] : chartProperties.gridY,
              legend: '',
              legendPosition: 'middle',
              legendOffset: 64,
            }}
            enablePoints={false}
            lineWidth={1}
            margin={{ top: 25, right: 25, bottom: 25, left: isMobile ? 25 : 60 }}
            markers={info ? [
              {
                axis: 'x',
                value: timeToDate(info.current_time).getTime(),
                lineStyle: {
                  stroke: theme === "dark" ? "yellow" : "orange",
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
            /* somehow if charttheme is used here the colors of the ticks in Y is wrong */
            theme={{
              grid: {
                line: {
                  stroke: theme === "dark" ? TICK_TEXT_COLOR_DARK : TICK_TEXT_COLOR_LIGHT,
                  strokeOpacity: 0.3,
                }
              },
              axis: {
                ticks: {
                  text: {
                    fontSize: '12px',
                    fill: theme === "dark" ? TICK_TEXT_COLOR_DARK : TICK_TEXT_COLOR_LIGHT,
                  },
                },
              },
            }}
          /> 
          }
        </div>
      </div>
      }
    </div>
  );
};

export default LockChart;
