
import { STimeline } from "@/declarations/protocol/protocol.did";
import { nsToMs } from "../../utils/conversions/date";

import { ResponsiveLine, Serie } from '@nivo/line';
import { useMemo, useRef } from "react";
import { protocolActor } from "../../actors/ProtocolActor";
import { format } from "date-fns";

interface DurationChartProps {
  duration_timeline: STimeline;
  format_value: (value: number) => string;
};
  
const DurationChart = ({ duration_timeline, format_value }: DurationChartProps) => {

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
    if (currentTime) {
      points.push({
        x: new Date(nsToMs(currentTime)),
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
    <div className="flex flex-col items-center space-y-1">
      <div
        ref={chartContainerRef}
        style={{
          width: '800px',
          height: `400px`,
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
          }}
          curve='stepAfter'
          enableArea={true}
          animate={false}
          enablePoints={false}
          margin={{ top: 20, bottom: 50, right: 50, left: 90 }}
          colors={"rgb(59 130 246)"}
          areaOpacity={0.7} // Adjust transparency of the area
          fill={[ // Define custom gradient fills for the area
            { match: '*', id: 'gradientA' },
          ]}
          defs={[
            {
              id: 'gradientA',
              type: 'linearGradient',
              colors: [
                { offset: 0, color: 'rgb(59 130 246)', opacity: 0.8 }, // Top gradient color
                { offset: 100, color: 'rgb(59 130 246)', opacity: 0.2 }, // Bottom gradient color
              ],
            },
          ]}
          areaBlendMode="normal"
          axisBottom={{
            renderTick: ({ tickIndex, x, y, value }) => {
              return (
                tickIndex % 1 ? <></> :
                <g transform={`translate(${x},${y})`}>
                  <text
                    x={0}
                    y={16}
                    textAnchor="middle"
                    dominantBaseline="central"
                    style={{
                      fontSize: '12px',
                      fill: 'white',
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
                    fill: 'white',
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
                stroke: 'white',
                strokeOpacity: 0.3,
              }
            }
          }}
        />
      </div>
    </div>
  );
}

export default DurationChart;