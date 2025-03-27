import { PointSymbolProps, ResponsiveLine, Serie } from '@nivo/line';
import { useContext, useEffect, useMemo, useRef, useState } from 'react';
import { create_serie } from './utils';
import { TimeLine } from '../../utils/timeline';
import { useMediaQuery } from 'react-responsive';
import { ThemeContext } from '../App';
import { MOBILE_MAX_WIDTH_QUERY } from '../../constants';
import { STimeline } from '@/declarations/protocol/protocol.did';
import { nsToMs } from '../../utils/conversions/date';
import { format } from 'date-fns';

interface ConsensusChartProps {
  timeline: STimeline;
  format_value: (value: number) => string;
  y_min?: number;
  y_max?: number;
  color: string;
};

const ConsensusChart = ({ timeline, format_value, y_min, y_max, color }: ConsensusChartProps) => {

  const { theme } = useContext(ThemeContext);

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

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

  // Set up the chart container ref
  const chartContainerRef = useRef<HTMLDivElement | null>(null);

  const CustomLastPoint = (props: PointSymbolProps) => {
      if (props.datum.x === undefined || props.datum.x === null) {
          return null;
      }
    
      const to_compare = new Date(nsToMs(timeline.current.timestamp));

      if ((new Date(props.datum.x)).getTime() === to_compare.getTime()) {
        return (
          <svg className="h-6 w-6" style={{ overflow: 'visible' }}>
            <circle
              r={4}
              fill={color}
              className="animate-ping"
            />
            <circle
              r={4}
              fill={color}
            />
          </svg>
        );
      }
      return null;
    };

    const series : Serie[] = useMemo(() => {
      return [create_serie("test", timeline)];
    }, [timeline]);

    
    return (
      <div className="flex flex-col items-center space-y-1 w-full" ref={containerRef}>
        { containerWidth && <div
          ref={chartContainerRef}
          style={{
            width: `${containerWidth}px`, // Dynamic width based on container
            height: `300px`,
            overflowX: 'auto',
            overflowY: 'hidden',
          }}
        >
        <ResponsiveLine
          data={series}
          xScale={{ type: 'time' }}
          yScale={{ type: 'linear', min: y_min, max: y_max }}
          margin={ isMobile ? { top: 20, bottom: 50, right: 20, left: 20 } : { top: 20, bottom: 50, right: 50, left: 90 }}
          curve= { 'stepAfter' }  
          animate={false}
          enablePoints={true} // Disable default points
          pointSymbol={CustomLastPoint} // Custom last point rendering
          enableGridX={false}
          legends={[]}
          colors={[color]}
          theme={{
            grid: {
              line: {
                stroke: theme === "dark" ? "white" : "rgb(30 41 59)", // slate-800,
                strokeOpacity: 0.3,
              }
            },
            legends: {
              text: {
                fill: theme === "dark" ? "white" : "rgb(30 41 59)", // slate-800
              }
            }
          }}
          axisBottom={{
            renderTick: ({ tickIndex, x, y, value }) => {
              return (
                tickIndex % (containerWidth < 800 ? 2 : 1) ? <></> :
                <g transform={`translate(${x},${y})`}>
                  <text
                    x={0}
                    y={16}
                    textAnchor="middle"
                    dominantBaseline="central"
                    style={{
                      fontSize: '12px',
                      fill: theme === "dark" ? "white" : "rgb(30 41 59)", // slate-800
                    }}
                  >
                    { format(new Date(value), "dd MMM") }
                  </text>
                </g>
              );
            },
          }}
          axisLeft={{
            renderTick: ({ tickIndex, x, y, value }) => {
              return (
                (isMobile || tickIndex % 2) ? <></> :
                <g transform={`translate(${x},${y})`}>
                <text
                  x={-36}
                  y={0}
                  textAnchor="middle"
                  dominantBaseline="central"
                  style={{
                    fontSize: '12px',
                    fill: theme === "dark" ? "white" : "rgb(30 41 59)", // slate-800
                  }}
                >
                  { format_value(value) }
                </text>
              </g>
              );
            }
          }}
        />
      </div>
}
</div>
    );
}

export default ConsensusChart;