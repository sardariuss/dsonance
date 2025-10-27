// --- Example Setup (React-like pseudo-code) ---
const strokeWidth = 8; // Thickness of the progress bar
const radius = 50 - strokeWidth / 2; // Radius of the centerline of the stroke
const viewBoxSize = 100; // Width of the SVG viewBox
const halfCircumference = Math.PI * radius; // Length of the half-circle path

// The SVG path definition for a top half-circle arc
// M = Move to start point (left-center, adjusted for stroke width)
// A = Arc command (radiusX, radiusY, rotation, large-arc-flag, sweep-flag, endX, endY)
const pathDefinition = `M ${strokeWidth / 2} ${viewBoxSize / 2} A ${radius} ${radius} 0 0 1 ${viewBoxSize - strokeWidth / 2} ${viewBoxSize / 2}`;

interface ConsensusIndicatorProps {
  cursor: number;
  pulse?: boolean;
}

const ConsensusIndicator: React.FC<ConsensusIndicatorProps> = ({ cursor, pulse }) => {

  return (
    <div className="relative h-11 justify-self-end leading-none" role="progressbar" aria-valuenow={cursor * 100} aria-valuemin={0} aria-valuemax={100}>
      <svg className="w-14" viewBox={`0 0 ${viewBoxSize} ${viewBoxSize}`}>
        <path
          d={pathDefinition}
          strokeWidth={strokeWidth}
          className="dark:stroke-gray-700 stroke-gray-300 fill-none"
        />
        <path
          d={pathDefinition}
          fill="none"
          strokeWidth={strokeWidth}
          className={`${cursor < 0.5 ? 'stroke-brand-false' : 'stroke-brand-true dark:stroke-brand-true-dark'} ${pulse? "animate-pulse" : ""}`}
          style={{
            strokeDasharray: cursor < 0.5
              ? `0 ${cursor * halfCircumference} ${(1 - cursor) * halfCircumference}`
              : halfCircumference,
            strokeDashoffset: cursor < 0.5 ? 0 : halfCircumference * (1 - cursor),
          }}
        />
      </svg>
      <div className="absolute inset-0 flex items-center justify-center">
        <span className={`${pulse? "animate-pulse" : ""}`}>{Math.round(cursor * 100)}%</span>
      </div>
    </div>
  );
};

export default ConsensusIndicator;
