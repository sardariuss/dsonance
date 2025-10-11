import { ResponsiveLine } from '@nivo/line';
import { useContext } from "react";
import { ThemeContext } from "../App";
import { LendingIndex } from "@/declarations/protocol/protocol.did";

interface TimedData<T> {
  timestamp: bigint;
  data: T;
}

interface STimeline<T> {
  current: TimedData<T>;
  history: TimedData<T>[];
  minIntervalNs: bigint;
}

interface SupplyAprChartProps {
  lendingIndexTimeline: STimeline<LendingIndex>;
  genesisTime: bigint;
}

const SupplyAprChart: React.FC<SupplyAprChartProps> = ({
  lendingIndexTimeline,
  genesisTime
}) => {
  const { theme } = useContext(ThemeContext);

  // Constants
  const NS_IN_HOUR = 60 * 60 * 1_000_000_000;

  // Process timeline data to extract Supply APR history
  const generateChartData = () => {
    const supplyAprPoints = [];

    const genesisTimeNum = Number(genesisTime);

    // Add historical data points
    for (const entry of lendingIndexTimeline.history) {
      const timeSinceGenesis = Number(entry.timestamp) - genesisTimeNum;
      const hours = timeSinceGenesis / Number(NS_IN_HOUR);

      supplyAprPoints.push({
        x: hours,
        y: entry.data.supply_rate * 100 // Convert to percentage
      });
    }

    // Add current data point
    const currentTimeSinceGenesis = Number(lendingIndexTimeline.current.timestamp) - genesisTimeNum;
    const currentHours = currentTimeSinceGenesis / Number(NS_IN_HOUR);

    supplyAprPoints.push({
      x: currentHours,
      y: lendingIndexTimeline.current.data.supply_rate * 100
    });

    // Calculate max hours for x-axis
    const maxHours = Math.max(...supplyAprPoints.map(p => p.x));

    return {
      data: [
        {
          id: 'Supply APR',
          data: supplyAprPoints
        }
      ],
      maxHours,
      currentHours
    };
  };

  const { data, maxHours, currentHours } = generateChartData();

  // Calculate max Y value for better scaling
  const allYValues = data.flatMap(series => series.data.map(point => point.y));
  const maxY = Math.max(...allYValues);
  const yAxisMax = maxY * 1.1; // Add 10% padding

  // Calculate mean APR
  const meanApr = allYValues.reduce((sum, val) => sum + val, 0) / allYValues.length;

  // Format hours to relative time or date
  const formatTime = (hours: number): string => {
    if (maxHours < 48) {
      // Show hours for short ranges
      return `${Math.round(hours)}h`;
    } else if (maxHours < 24 * 30) {
      // Show days for medium ranges
      const days = Math.floor(hours / 24);
      return `${days}d`;
    } else {
      // Show date for long ranges
      const genesisTimeMs = Number(genesisTime) / 1_000_000; // Convert from nanoseconds to milliseconds
      const hoursInMs = hours * 60 * 60 * 1000;
      const date = new Date(genesisTimeMs + hoursInMs);
      return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }
  };

  return (
    <div className="h-80">
      <ResponsiveLine
        data={data}
        margin={{ top: 20, right: 40, bottom: 60, left: 60 }}
        xScale={{ type: 'linear', min: 0, max: maxHours }}
        yScale={{ type: 'linear', min: 0, max: yAxisMax }}
        curve="monotoneX"
        axisBottom={{
          legend: '',
          legendOffset: 45,
          legendPosition: 'middle',
          format: (value) => formatTime(value),
        }}
        axisLeft={{
          legend: 'APR (%)',
          legendOffset: -50,
          legendPosition: 'middle',
          format: (value) => `${value.toFixed(1)}%`,
        }}
        colors={[theme === 'dark' ? '#60a5fa' : '#3b82f6']} // Supply APR - blue
        lineWidth={3}
        enablePoints={false}
        enableGridX={true}
        enableGridY={true}
        useMesh={true}
        markers={[
          {
            axis: 'x',
            value: currentHours,
            lineStyle: { stroke: theme === 'dark' ? '#9ca3af' : '#6b7280', strokeWidth: 2, strokeDasharray: '6 6' },
            legend: 'Now',
            legendOrientation: 'vertical',
            legendPosition: 'top-left',
            textStyle: { fill: theme === 'dark' ? '#9ca3af' : '#6b7280', fontSize: 12 }
          },
          {
            axis: 'y',
            value: meanApr,
            lineStyle: { stroke: theme === 'dark' ? '#60a5fa' : '#3b82f6', strokeWidth: 2, strokeDasharray: '6 6', opacity: 0.6 },
            legend: `Mean: ${meanApr.toFixed(2)}%`,
            legendOrientation: 'horizontal',
            legendPosition: 'top-right',
            textStyle: { fill: theme === 'dark' ? '#60a5fa' : '#3b82f6', fontSize: 12 }
          }
        ]}
        tooltip={({ point }) => (
          <div className="bg-white dark:bg-gray-800 p-3 rounded shadow-lg border border-gray-200 dark:border-gray-700">
            <div className="text-sm font-semibold text-gray-900 dark:text-white">
              Supply APR
            </div>
            <div className="text-sm text-gray-700 dark:text-gray-300">
              {formatTime(point.data.x as number)}
            </div>
            <div className="text-sm font-bold text-gray-900 dark:text-white">
              {(point.data.y as number).toFixed(2)}%
            </div>
          </div>
        )}
        theme={{
          background: 'transparent',
          text: {
            fill: theme === 'dark' ? '#e5e7eb' : '#374151',
          },
          axis: {
            legend: {
              text: {
                fill: theme === 'dark' ? '#e5e7eb' : '#374151',
              }
            },
            ticks: {
              text: {
                fill: theme === 'dark' ? '#9ca3af' : '#6b7280',
              }
            }
          },
          grid: {
            line: {
              stroke: theme === 'dark' ? '#374151' : '#e5e7eb',
              strokeWidth: 1
            }
          }
        }}
      />
    </div>
  );
};

export default SupplyAprChart;
