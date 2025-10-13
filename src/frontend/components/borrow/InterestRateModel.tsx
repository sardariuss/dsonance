import { useProtocolContext } from "../context/ProtocolContext";
import { useMemo } from "react";

interface InterestRateModelProps {
  utilizationRate: number;
}

const InterestRateModel: React.FC<InterestRateModelProps> = ({
  utilizationRate
}) => {
  const { parameters } = useProtocolContext();

  const chartData = useMemo(() => {
    if (!parameters?.lending.interest_rate_curve) {
      return null;
    }

    const curve = parameters.lending.interest_rate_curve;
    const sortedCurve = [...curve].sort((a, b) => a.utilization - b.utilization);

    // Interpolate the interest rate at the current utilization
    let currentRate = 0;
    for (let i = 0; i < sortedCurve.length - 1; i++) {
      const p1 = sortedCurve[i];
      const p2 = sortedCurve[i + 1];

      if (utilizationRate >= p1.utilization && utilizationRate <= p2.utilization) {
        // Linear interpolation
        const t = (utilizationRate - p1.utilization) / (p2.utilization - p1.utilization);
        currentRate = p1.rate + t * (p2.rate - p1.rate);
        break;
      }
    }

    // If utilization is beyond the last point, use the last rate
    if (utilizationRate >= sortedCurve[sortedCurve.length - 1].utilization) {
      currentRate = sortedCurve[sortedCurve.length - 1].rate;
    }

    return { sortedCurve, currentRate };
  }, [parameters, utilizationRate]);

  if (!chartData) {
    return (
      <div className="flex flex-col w-full space-y-6">
        <div className="text-sm text-gray-500 dark:text-gray-400">Loading...</div>
      </div>
    );
  }

  const { sortedCurve, currentRate } = chartData;

  // Chart dimensions
  const width = 600;
  const height = 300;
  const padding = { top: 20, right: 60, bottom: 50, left: 60 };
  const chartWidth = width - padding.left - padding.right;
  const chartHeight = height - padding.top - padding.bottom;

  // Scale functions
  const xScale = (utilization: number) => padding.left + (utilization * chartWidth);
  const yScale = (rate: number) => padding.top + chartHeight - (rate * chartHeight);

  // Generate SVG path for the curve
  const pathData = sortedCurve.map((point, i) => {
    const x = xScale(point.utilization);
    const y = yScale(point.rate);
    return i === 0 ? `M ${x} ${y}` : `L ${x} ${y}`;
  }).join(' ');

  // Current position on the chart
  const currentX = xScale(utilizationRate);
  const currentY = yScale(currentRate);

  // Y-axis ticks (0%, 25%, 50%, 75%, 100%)
  const yTicks = [0, 0.25, 0.5, 0.75, 1.0];
  // X-axis ticks (0%, 25%, 50%, 75%, 100%)
  const xTicks = [0, 0.25, 0.5, 0.75, 1.0];

  return (
    <div className="flex flex-col px-2 sm:px-6 w-full space-y-4">
      <div className="flex flex-col gap-2">
        <div className="flex justify-between items-center">
          <div className="flex flex-col">
            <span className="text-sm text-gray-500 dark:text-gray-400">Current Utilization</span>
            <span className="text-lg font-bold">{(100 * utilizationRate).toFixed(2)}%</span>
          </div>
        </div>
      </div>

      <div className="flex items-center gap-4 text-sm">
        <div className="flex items-center gap-2">
          <div className="w-4 h-0.5 bg-green-500"></div>
          <span className="text-gray-600 dark:text-gray-400">Borrow APR, variable</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-4 h-0.5 bg-purple-500"></div>
          <span className="text-gray-600 dark:text-gray-400">Utilization rate</span>
        </div>
      </div>

      <div className="w-full overflow-x-auto h-60">
        <svg
          viewBox={`0 0 ${width} ${height}`}
          className="w-full h-full"
        >
          {/* Grid lines */}
          {yTicks.map((tick) => (
            <line
              key={`grid-y-${tick}`}
              x1={padding.left}
              y1={yScale(tick)}
              x2={width - padding.right}
              y2={yScale(tick)}
              stroke="currentColor"
              strokeWidth="1"
              className="text-gray-300 dark:text-gray-700"
              strokeDasharray="4 4"
            />
          ))}
          {xTicks.map((tick) => (
            <line
              key={`grid-x-${tick}`}
              x1={xScale(tick)}
              y1={padding.top}
              x2={xScale(tick)}
              y2={height - padding.bottom}
              stroke="currentColor"
              strokeWidth="1"
              className="text-gray-300 dark:text-gray-700"
              strokeDasharray="4 4"
            />
          ))}

          {/* Axes */}
          <line
            x1={padding.left}
            y1={height - padding.bottom}
            x2={width - padding.right}
            y2={height - padding.bottom}
            stroke="currentColor"
            strokeWidth="2"
            className="text-gray-600 dark:text-gray-400"
          />
          <line
            x1={padding.left}
            y1={padding.top}
            x2={padding.left}
            y2={height - padding.bottom}
            stroke="currentColor"
            strokeWidth="2"
            className="text-gray-600 dark:text-gray-400"
          />

          {/* Interest rate curve */}
          <path
            d={pathData}
            fill="none"
            stroke="currentColor"
            strokeWidth="3"
            className="text-green-500"
          />

          {/* Current position indicator */}
          <line
            x1={currentX}
            y1={padding.top}
            x2={currentX}
            y2={height - padding.bottom}
            stroke="currentColor"
            strokeWidth="2"
            className="text-purple-500"
            strokeDasharray="4 4"
          />

          {/* Y-axis labels */}
          {yTicks.map((tick) => (
            <text
              key={`label-y-${tick}`}
              x={padding.left - 10}
              y={yScale(tick)}
              textAnchor="end"
              dominantBaseline="middle"
              className="text-xs fill-gray-600 dark:fill-gray-400"
            >
              {(tick * 100).toFixed(0)}%
            </text>
          ))}

          {/* X-axis labels */}
          {xTicks.map((tick) => (
            <text
              key={`label-x-${tick}`}
              x={xScale(tick)}
              y={height - padding.bottom + 20}
              textAnchor="middle"
              className="text-xs fill-gray-600 dark:fill-gray-400"
            >
              {(tick * 100).toFixed(0)}%
            </text>
          ))}

        </svg>
      </div>
    </div>
  )
};

export default InterestRateModel;
