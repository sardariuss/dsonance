import { ResponsiveLine } from '@nivo/line';
import { useContext } from "react";
import { ThemeContext } from "../App";

interface EmissionCurveChartProps {
  genesisTime: bigint;
  currentTime: bigint;
  emissionTotalAmount: bigint;
  emissionHalfLifeS: number;
  totalMinted: bigint;
  formatAmount: (amount: bigint | number | undefined) => string;
}

const EmissionCurveChart: React.FC<EmissionCurveChartProps> = ({
  genesisTime,
  currentTime,
  emissionTotalAmount,
  emissionHalfLifeS,
  totalMinted,
  formatAmount
}) => {
  const { theme } = useContext(ThemeContext);

  // Constants
  const NS_IN_SECOND = 1_000_000_000;
  const NS_IN_DAY = 24 * 60 * 60 * NS_IN_SECOND;

  // Calculate emission curve data
  // Formula from ParticipationMiner.mo: E_0 * (1 - e^(-kt))
  // Emission rate (derivative): dE/dt = E_0 * k * e^(-kt)
  // where k = ln(2) / T_h
  const generateEmissionData = () => {
    const k = Math.log(2) / emissionHalfLifeS;
    const E0 = Number(emissionTotalAmount);

    const genesisTimeNum = Number(genesisTime);
    const currentTimeNum = Number(currentTime);

    // Calculate time range in days since genesis
    const elapsedTime = currentTimeNum - genesisTimeNum;
    const elapsedDays = elapsedTime / Number(NS_IN_DAY);

    // Project 2x the elapsed time or at least 30 days into the future
    const projectionDays = Math.max(elapsedDays * 2, 30);

    const theoreticalCurve = [];
    const emissionRateCurve = [];
    const actualPoint = [];

    // Calculate max emission rate for reference (at t=0)
    const maxEmissionRatePerSecond = E0 * k;
    const maxEmissionRatePerDay = maxEmissionRatePerSecond * 24 * 60 * 60;

    // Generate theoretical curve points
    const numPoints = 100;
    for (let i = 0; i <= numPoints; i++) {
      const days = (projectionDays * i) / numPoints;
      const timeInSeconds = days * 24 * 60 * 60;

      // Calculate minted amount at this time: E_0 * (1 - e^(-kt))
      const mintedAmount = E0 * (1 - Math.exp(-k * timeInSeconds));

      // Calculate emission rate at this time: dE/dt = E_0 * k * e^(-kt) in TWV/second
      const emissionRatePerSecond = E0 * k * Math.exp(-k * timeInSeconds);
      const emissionRatePerDay = emissionRatePerSecond * 24 * 60 * 60;

      theoreticalCurve.push({
        x: days,
        y: mintedAmount
      });

      emissionRateCurve.push({
        x: days,
        y: emissionRatePerDay
      });
    }

    // Store actual minted value for marker
    const actualMintedValue = Number(totalMinted);

    return {
      theoretical: [{
        id: 'Cumulative Emission',
        data: theoreticalCurve
      }],
      emissionRate: [{
        id: 'Emission Rate (TWV/day)',
        data: emissionRateCurve
      }],
      maxDays: projectionDays,
      currentDays: elapsedDays,
      actualMintedValue: actualMintedValue
    };
  };

  const { theoretical, emissionRate, maxDays, currentDays, actualMintedValue } = generateEmissionData();

  // Calculate scaling factor for emission rate to fit on same chart
  // We want the max emission rate to be around 20% of the max cumulative emission
  const maxEmissionRateValue = emissionRate[0].data[0].y; // Max at t=0
  const scalingFactor = (Number(emissionTotalAmount) * 0.2) / maxEmissionRateValue;

  // Scale emission rate data for visualization
  const scaledEmissionRate = [{
    id: emissionRate[0].id,
    data: emissionRate[0].data.map(point => ({
      ...point,
      y: point.y * scalingFactor,
      originalY: point.y // Keep original for tooltip and right axis
    }))
  }];

  // Combine all data (no actual point - will use marker instead)
  const allData = [...theoretical, ...scaledEmissionRate];

  // Format days to human readable
  const formatDays = (days: number): string => {
    if (days < 1) return (days * 24).toFixed(0) + 'h';
    if (days < 30) return days.toFixed(0) + 'd';
    if (days < 365) return (days / 30).toFixed(1) + 'mo';
    return (days / 365).toFixed(1) + 'y';
  };

  return (
    <div className="h-80">
      <ResponsiveLine
        data={allData}
        margin={{ top: 20, right: 120, bottom: 60, left: 80 }}
        xScale={{ type: 'linear', min: 0, max: maxDays }}
        yScale={{ type: 'linear', min: 0, max: 'auto' }}
        curve="monotoneX"
        axisBottom={{
          legend: 'Time since Genesis',
          legendOffset: 45,
          legendPosition: 'middle',
          format: (value) => formatDays(value),
        }}
        axisLeft={{
          legend: 'Cumulative TWV',
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
          theme === 'dark' ? '#60a5fa' : '#3b82f6',  // Cumulative - blue
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
          },
          {
            axis: 'y',
            value: actualMintedValue,
            lineStyle: { stroke: theme === 'dark' ? '#34d399' : '#10b981', strokeWidth: 2, strokeDasharray: '4 4' },
            legend: `Actual: ${formatAmount(actualMintedValue)} TWV`,
            legendOrientation: 'horizontal',
            legendPosition: 'top-right',
            textStyle: { fill: theme === 'dark' ? '#34d399' : '#10b981', fontSize: 11 }
          }
        ]}
        legends={[
          {
            anchor: 'bottom-right',
            direction: 'column',
            justify: false,
            translateX: 100,
            translateY: 0,
            itemsSpacing: 0,
            itemDirection: 'left-to-right',
            itemWidth: 80,
            itemHeight: 20,
            itemOpacity: 0.75,
            symbolSize: 12,
            symbolShape: 'circle',
            symbolBorderColor: 'rgba(0, 0, 0, .5)',
            effects: [
              {
                on: 'hover',
                style: {
                  itemBackground: 'rgba(0, 0, 0, .03)',
                  itemOpacity: 1
                }
              }
            ]
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
                Time: {formatDays(point.data.x as number)}
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
