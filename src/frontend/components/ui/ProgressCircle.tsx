import React from "react";

interface ProgressCircleProps {
  percentage: number;
  size?: number; // diameter in pixels
  strokeWidth?: number;
  className?: string;
  showPercentage?: boolean;
}

const ProgressCircle: React.FC<ProgressCircleProps> = ({
  percentage,
  size = 80,
  strokeWidth = 2,
  className = "",
  showPercentage = true,
}) => {

  return (
    <div className={`relative ${className}`} style={{ width: size, height: size }}>
      <svg viewBox="0 0 36 36" className="w-full h-full">
        <path
          className="text-gray-300 dark:text-gray-700"
          d="M18 2.0845
             a 15.9155 15.9155 0 0 1 0 31.831
             a 15.9155 15.9155 0 0 1 0 -31.831"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
        />
        <path
          className="text-green-500 dark:text-green-400"
          d="M18 2.0845
             a 15.9155 15.9155 0 0 1 0 31.831"
          fill="none"
          stroke="currentColor"
          strokeWidth={strokeWidth}
          strokeDasharray="100, 100"
          strokeDashoffset={100 - percentage}
          style={{ transition: "stroke-dashoffset 0.5s" }}
        />
      </svg>
      {showPercentage && (
        <div className="absolute inset-0 flex items-center justify-center text-sm font-semibold">
          {percentage.toFixed(2)}%
        </div>
      )}
    </div>
  );
};

export default ProgressCircle;
