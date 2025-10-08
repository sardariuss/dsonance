import { ResponsiveLine } from '@nivo/line';
import { useContext } from "react";
import { ThemeContext } from "../App";

interface TimedData<T> {
  timestamp: bigint;
  data: T;
}

interface RollingTimeline<T> {
  current: TimedData<T>;
  history: TimedData<T>[];
  maxSize: bigint;
  minInterval: bigint;
}

interface EmissionCurveChartProps {
  genesisTime: bigint;
  currentTime: bigint;
  emissionTotalAmount: bigint;
  emissionHalfLifeS: number;
  totalAllocatedTimeline: RollingTimeline<bigint>;
  totalClaimedTimeline: RollingTimeline<bigint>;
  formatAmount: (amount: bigint | number | undefined) => string;
}

const EmissionCurveChart: React.FC<EmissionCurveChartProps> = ({
  genesisTime,
  currentTime,
  emissionTotalAmount,
  emissionHalfLifeS,
  totalAllocatedTimeline,
  totalClaimedTimeline,
  formatAmount
}) => {
  const { theme } = useContext(ThemeContext);

  // Constants
  const NS_IN_SECOND = 1_000_000_000;
  const NS_IN_DAY = 24 * 60 * 60 * NS_IN_SECOND;

  // Process timeline data and generate emission rate curve
  const generateChartData = () => {
    const k = Math.log(2) / emissionHalfLifeS;
    const E0 = Number(emissionTotalAmount);

    const genesisTimeNum = Number(genesisTime);
    const currentTimeNum = Number(currentTime);

    // Calculate time range in days since genesis
    const elapsedTime = currentTimeNum - genesisTimeNum;
    const elapsedDays = elapsedTime / Number(NS_IN_DAY);

    // Convert timeline data to chart points
    const allocatedPoints = [];
    const claimedPoints = [];

    // Add historical data from timelines
    for (const entry of totalAllocatedTimeline.history) {
      const timeSinceGenesis = Number(entry.timestamp) - genesisTimeNum;
      const days = timeSinceGenesis / Number(NS_IN_DAY);
      allocatedPoints.push({
        x: days,
        y: Number(entry.data)
      });
    }

    // Add current allocated point
    const currentAllocatedDays = (Number(totalAllocatedTimeline.current.timestamp) - genesisTimeNum) / Number(NS_IN_DAY);
    allocatedPoints.push({
      x: currentAllocatedDays,
      y: Number(totalAllocatedTimeline.current.data)
    });

    // Add historical data from claimed timeline
    for (const entry of totalClaimedTimeline.history) {
      const timeSinceGenesis = Number(entry.timestamp) - genesisTimeNum;
      const days = timeSinceGenesis / Number(NS_IN_DAY);
      claimedPoints.push({
        x: days,
        y: Number(entry.data)
      });
    }

    // Add current claimed point
    const currentClaimedDays = (Number(totalClaimedTimeline.current.timestamp) - genesisTimeNum) / Number(NS_IN_DAY);
    claimedPoints.push({
      x: currentClaimedDays,
      y: Number(totalClaimedTimeline.current.data)
    });

    // Project 2x the elapsed time or at least 30 days into the future
    const projectionDays = Math.max(elapsedDays * 2, 30);

    // Generate emission rate curve
    const emissionRateCurve = [];
    const numPoints = 100;
    for (let i = 0; i <= numPoints; i++) {
      const days = (projectionDays * i) / numPoints;
      const timeInSeconds = days * 24 * 60 * 60;

      // Calculate emission rate at this time: dE/dt = E_0 * k * e^(-kt) in TWV/second
      const emissionRatePerSecond = E0 * k * Math.exp(-k * timeInSeconds);
      const emissionRatePerDay = emissionRatePerSecond * 24 * 60 * 60;

      emissionRateCurve.push({
        x: days,
        y: emissionRatePerDay
      });
    }

    // TODO: add total claimed, but for that once should ideally use an histogram of claims over time
    return {
      allocated: [{
        id: 'Total Mined (TWV)',
        data: allocatedPoints
      }],
      emissionRate: [{
        id: 'Emission Rate (TWV/day)',
        data: emissionRateCurve
      }],
      maxDays: projectionDays,
      currentDays: elapsedDays
    };
  };

  const { allocated, emissionRate, maxDays, currentDays } = generateChartData();

  // Calculate the maximum allocated value for Y-axis scaling
  const maxAllocated = Math.max(...allocated[0].data.map(point => point.y));
  const yAxisMax = maxAllocated * 1.1; // Add 10% padding

  // Calculate scaling factor for emission rate to fit on same chart
  // Scale emission rate to use the full Y-axis range
  const maxEmissionRateValue = emissionRate[0].data[0].y; // Max at t=0
  const scalingFactor = yAxisMax / maxEmissionRateValue;

  // Scale emission rate data for visualization
  const scaledEmissionRate = [{
    id: emissionRate[0].id,
    data: emissionRate[0].data.map(point => ({
      ...point,
      y: point.y * scalingFactor,
      originalY: point.y // Keep original for tooltip and right axis
    }))
  }];

  // Combine all data
  const allData = [...allocated, ...scaledEmissionRate];

  // Format days since genesis to actual date
  const formatToDate = (days: number): string => {
    const genesisTimeMs = Number(genesisTime) / 1_000_000; // Convert from nanoseconds to milliseconds
    const daysInMs = days * 24 * 60 * 60 * 1000;
    const date = new Date(genesisTimeMs + daysInMs);

    // Format based on time range
    const elapsedDays = Number(currentTime - genesisTime) / (24 * 60 * 60 * 1_000_000_000);
    if (elapsedDays < 30) {
      // Show date and time for short ranges
      return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: '2-digit' });
    } else if (elapsedDays < 365) {
      // Show month and day for medium ranges
      return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    } else {
      // Show month and year for long ranges
      return date.toLocaleDateString('en-US', { month: 'short', year: 'numeric' });
    }
  };

  return (
    <div className="h-80">
      <ResponsiveLine
        data={allData}
        margin={{ top: 20, right: 120, bottom: 60, left: 80 }}
        xScale={{ type: 'linear', min: 0, max: maxDays }}
        yScale={{ type: 'linear', min: 0, max: yAxisMax }}
        curve="monotoneX"
        axisBottom={{
          legendOffset: 45,
          legendPosition: 'middle',
          format: (value) => formatToDate(value),
        }}
        axisLeft={{
          legend: 'Total Mined (TWV)',
          legendOffset: -60,
          legendPosition: 'middle',
          format: (value) => formatAmount(value),
        }}
        axisRight={{
          legend: 'Emission Rate (TWV/day)',
          legendOffset: 70,
          legendPosition: 'middle',
          format: (value) => formatAmount(value / scalingFactor),
          tickValues: 5
        }}
        colors={[
          theme === 'dark' ? '#60a5fa' : '#3b82f6',  // Allocated - blue
          theme === 'dark' ? '#34d399' : '#10b981',  // Claimed - green
          theme === 'dark' ? '#f59e0b' : '#f97316'   // Emission Rate - orange
        ]}
        lineWidth={3}
        enablePoints={false}
        enableGridX={true}
        enableGridY={true}
        useMesh={true}
        markers={[
          {
            axis: 'x',
            value: currentDays,
            lineStyle: { stroke: theme === 'dark' ? '#9ca3af' : '#6b7280', strokeWidth: 2, strokeDasharray: '6 6' },
            legend: 'Current Time',
            legendOrientation: 'vertical',
            legendPosition: 'top-left',
            textStyle: { fill: theme === 'dark' ? '#9ca3af' : '#6b7280', fontSize: 12 }
          }
        ]}
        tooltip={({ point }) => {
          const isEmissionRate = point.serieId === 'Emission Rate (TWV/day)';
          const originalY = (point.data as any).originalY;
          const displayValue = isEmissionRate && originalY ? originalY : point.data.y;

          return (
            <div className="bg-white dark:bg-gray-800 p-3 rounded shadow-lg border border-gray-200 dark:border-gray-700">
              <div className="text-sm font-semibold text-gray-900 dark:text-white">
                {point.serieId}
              </div>
              <div className="text-sm text-gray-700 dark:text-gray-300">
                {formatToDate(point.data.x as number)}
              </div>
              <div className="text-sm text-gray-700 dark:text-gray-300">
                {isEmissionRate
                  ? `Rate: ${formatAmount(displayValue as number)} TWV/day`
                  : `Amount: ${formatAmount(displayValue as number)} TWV`
                }
              </div>
            </div>
          );
        }}
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
          },
          legends: {
            text: {
              fill: theme === 'dark' ? '#e5e7eb' : '#374151',
            }
          }
        }}
      />
    </div>
  );
};

export default EmissionCurveChart;
