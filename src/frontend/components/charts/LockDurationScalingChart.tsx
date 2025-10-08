import { ResponsiveLine } from '@nivo/line';
import { useContext } from "react";
import { ThemeContext } from "../App";
import { DurationScalerParameters } from "@/declarations/protocol/protocol.did";

// Format USDT amount from e6 base units to human-readable
const formatUSDTAxis = (value: number): string => {
  // value is in e6 base units (1,000,000 e6 = 1 USDT)
  const usdt = value / 1_000_000;
  if (usdt < 1) return usdt.toExponential(0);
  if (usdt < 1_000) return usdt.toFixed(0);
  if (usdt < 1_000_000) return (usdt / 1_000).toFixed(0) + 'K';
  if (usdt < 1_000_000_000) return (usdt / 1_000_000).toFixed(0) + 'M';
  if (usdt < 1_000_000_000_000) return (usdt / 1_000_000_000).toFixed(0) + 'B';
  return (usdt / 1_000_000_000_000).toFixed(0) + 'T';
};

// Format duration from nanoseconds to human-readable
const formatDurationAxis = (ns: number): string => {
  const seconds = ns / 1_000_000_000;
  if (seconds < 60) return seconds.toFixed(1) + 's';
  const minutes = seconds / 60;
  if (minutes < 60) return minutes.toFixed(0) + 'm';
  const hours = minutes / 60;
  if (hours < 24) return hours.toFixed(0) + 'h';
  const days = hours / 24;
  if (days < 365) return days.toFixed(0) + 'd';
  const years = days / 365.25;
  return years.toFixed(0) + 'y';
};

interface LockDurationScalingChartProps {
  durationScaler: DurationScalerParameters;
}

const LockDurationScalingChart: React.FC<LockDurationScalingChartProps> = ({ durationScaler }) => {
  const { theme } = useContext(ThemeContext);

  // Generate data for lock duration scaling chart
  // Formula from DurationScaler.mo: duration = a * hotness^(log(b) / log(10))
  const generateDurationScalingData = () => {
    const { a, b } = durationScaler;
    const dataPoints = [];
    // log(b) / log(10) = log₁₀(b) (change of base formula)
    const exponent = Math.log(b) / Math.log(10);

    // Generate points from 1e6 to 1e13 (1 USDT to 10M USDT in e6 base units)
    // Using logarithmic spacing for smooth curve on log scale
    for (let i = 6; i <= 13; i += 0.1) {
      const hotness_e6 = Math.pow(10, i);
      const duration_ns = a * Math.pow(hotness_e6, exponent);

      dataPoints.push({
        x: hotness_e6,
        y: duration_ns
      });
    }

    return [{
      id: 'Lock Duration',
      data: dataPoints
    }];
  };

  const durationScalingData = generateDurationScalingData();

  return (
    <div className="mt-6">
      <div className="h-96">
        <ResponsiveLine
          data={durationScalingData}
          margin={{ top: 20, right: 60, bottom: 60, left: 80 }}
          xScale={{ type: 'log', base: 10, min: 1e6, max: 1e13 }}
          yScale={{ type: 'log', base: 10, min: 'auto', max: 'auto' }}
          curve="monotoneX"
          axisBottom={{
            legend: 'CDV (in ckUSDT)',
            legendOffset: 45,
            legendPosition: 'middle',
            format: (value) => formatUSDTAxis(value),
            tickValues: [1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13]
          }}
          axisLeft={{
            legend: 'Lock Duration',
            legendOffset: -60,
            legendPosition: 'middle',
            format: (value) => formatDurationAxis(value)
          }}
          colors={{ scheme: 'category10' }}
          lineWidth={3}
          enablePoints={false}
          enableGridX={true}
          enableGridY={true}
          gridXValues={[1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13]}
          useMesh={true}
          tooltip={({ point }) => (
            <div className="bg-white dark:bg-gray-800 p-3 rounded shadow-lg border border-gray-200 dark:border-gray-700">
              <div className="text-sm font-semibold text-gray-900 dark:text-white">
                Hotness: {formatUSDTAxis(point.data.x as number)} USDT
              </div>
              <div className="text-sm text-gray-700 dark:text-gray-300">
                Duration: {formatDurationAxis(point.data.y as number)}
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
    </div>
  );
};

export default LockDurationScalingChart;
