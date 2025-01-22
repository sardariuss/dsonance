
import { STimeline } from "@/declarations/protocol/protocol.did";
import { nsToMs } from "../../utils/conversions/date";

import { ResponsiveLine, Serie } from '@nivo/line';
import { useContext, useEffect, useMemo, useRef, useState } from "react";
import { protocolActor } from "../../actors/ProtocolActor";
import { format } from "date-fns";
import { ThemeContext } from "../App";

export enum CHART_COLORS {
  BLUE = "rgb(59 130 246)",
  PURPLE = "rgb(126 34 206)",
  WHITE = "rgb(255 255 255)",
  YELLOW = "rgb(247 147 26)",
  GREEN = "rgb(7 227 68)",
}

const COLOR_NAMES = {
  [CHART_COLORS.BLUE]: 'BLUE',
  [CHART_COLORS.PURPLE]: 'PURPLE',
  [CHART_COLORS.WHITE]: 'WHITE',
  [CHART_COLORS.YELLOW]: 'YELLOW',
  [CHART_COLORS.GREEN]: 'GREEN',
};

interface DurationChartProps {
  duration_timeline: STimeline;
  format_value: (value: number) => string;
  fillArea: boolean;
  y_min?: number;
  y_max?: number;
  color: CHART_COLORS;
  last_timestamp?: bigint;
};
  
const DurationChart = ({ duration_timeline, format_value, fillArea, y_min, y_max, color, last_timestamp }: DurationChartProps) => {

  const { theme } = useContext(ThemeContext);

  const [containerWidth, setContainerWidth] = useState<number | undefined>(undefined); // State to store the width of the div
  
  const containerRef = useRef<HTMLDivElement>(null); // Ref for the div element

  useEffect(() => {
    // Function to update the width
    const updateWidth = () => {
      if (containerRef.current) {
        console.log("Container width: ", containerRef.current.offsetWidth);
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

  const { data: currentTime } = protocolActor.useQueryCall({
    functionName: "get_time",
  });

  // Set up the chart container ref
  const chartContainerRef = useRef<HTMLDivElement | null>(null);

  const data = useMemo(() => {
    const data : Serie[] = [];
    let points = duration_timeline.history.map((duration_ns) => {
      return {
        x: new Date(nsToMs(duration_ns.timestamp)),
        y: duration_ns.data
      };
    });
    points.push({
      x: new Date(nsToMs(duration_timeline.current.timestamp)),
      y: duration_timeline.current.data
    });
    let timestamp = last_timestamp ?? currentTime;
    if (timestamp) {
      points.push({
        x: new Date(nsToMs(timestamp)),
        y: duration_timeline.current.data
      });
    }
    data.push({
      id: "Duration",
      data: points
    });
    return data;
  }, [duration_timeline, currentTime]);

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
          data={data}
          xScale={{
            type: 'time',
          }}
          yScale={{
            type: 'linear',
            min: y_min,
            max: y_max,
          }}
          curve='linear'
          enableArea={fillArea}
          animate={false}
          enablePoints={false}
          margin={{ top: 20, bottom: 50, right: 50, left: 90 }}
          colors={color}
          areaOpacity={0.7} // Adjust transparency of the area
          fill={fillArea ? [{ match: '*', id: `gradientA_${COLOR_NAMES[color]}` }] : undefined}
          defs={fillArea ? [{
            id: `gradientA_${COLOR_NAMES[color]}`,
            type: 'linearGradient',
            colors: [
              { offset: 0, color: color, opacity: 0.8 }, // Top gradient color
              { offset: 100, color: color, opacity: 0.2 }, // Bottom gradient color
            ],
          }] : undefined}
          areaBlendMode="normal"
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
                tickIndex % 2 ? <></> :
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
          enableGridX={false}
          theme={{
            grid: {
              line: {
                stroke: theme === "dark" ? "white" : "rgb(30 41 59)", // slate-800,
                strokeOpacity: 0.3,
              }
            }
          }}
        />
      </div>
    }
    </div>
  );
}

export default DurationChart;