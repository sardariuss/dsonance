
import { STimeline } from "@/declarations/protocol/protocol.did";
import { ResponsiveLine, Serie } from '@nivo/line';
import { useContext, useEffect, useMemo, useRef, useState } from "react";
import { format } from "date-fns";
import { ThemeContext } from "../App";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../../../frontend/constants";
import { create_serie } from "./utils";
import { chartTheme } from ".";
import { useContainerSize } from "../hooks/useContainerSize";

export enum CHART_COLORS {
  BLUE = "rgb(59 130 246)",
  PURPLE = "rgb(126 34 206)",
  WHITE = "rgb(255 255 255)",
  YELLOW = "rgb(247 147 26)",
  GREEN = "rgb(7 227 68)",
}

interface DurationChartProps {
  duration_timelines: Map<string, SerieInput>;
  format_value: (value: number) => string;
  fillArea: boolean;
  y_min?: number;
  y_max?: number;
};

export type SerieInput = {
  timeline: STimeline;
  color: CHART_COLORS;
};
  
const DurationChart = ({ duration_timelines, format_value, fillArea, y_min, y_max }: DurationChartProps) => {

  const { theme } = useContext(ThemeContext);
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const { containerSize, containerRef } = useContainerSize();

  const data = useMemo(() => {
    const series : Serie[] = [];
    duration_timelines.forEach((input, id) => {
      let serie = create_serie(id, input.timeline);
      series.push(serie);
    });
    return series;
  }, [duration_timelines]);

  return (
    <div className="flex flex-col items-center space-y-1 w-full" ref={containerRef}>
      { containerSize && <div
        style={{
          width: `${containerSize.width}px`,
          height: `${containerSize.height}px`,
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
          curve= { 'linear' }
          enableArea={fillArea}
          animate={false}
          enablePoints={false}
          margin={ isMobile ? { top: 20, bottom: 50, right: 20, left: 20 } : { top: 20, bottom: 50, right: 50, left: 90 }}
          colors={Array.from(duration_timelines.values()).map((serie) => serie.color)}
          areaOpacity={0.7} // Adjust transparency of the area
          fill={
            fillArea
              ? Array.from(duration_timelines.keys()).map((seriesId) => ({
                  match: { id: seriesId }, // This must match the actual series ID in your `data`
                  id: `gradient_${seriesId}`,
                }))
              : undefined
          }
          defs={
            fillArea
              ? Array.from(duration_timelines.entries()).map(([seriesId, serie]) => ({
                  id: `gradient_${seriesId}`, // Ensure IDs match
                  type: "linearGradient",
                  colors: [
                    { offset: 0, color: serie.color, opacity: 0.8 }, // Top gradient
                    { offset: 100, color: serie.color, opacity: 0.2 }, // Bottom gradient
                  ],
                }))
              : undefined
          }
          legends={duration_timelines.size < 2 ? [] : [
            {
              anchor: "bottom", // Position at the bottom
              direction: "row", // Display legends in a row
              justify: false,
              translateX: 0,
              translateY: 50, // Move below the chart
              itemsSpacing: 10, // Space between legend items
              itemDirection: "left-to-right",
              itemWidth: 80,
              itemHeight: 20,
              itemOpacity: 1.0,
              symbolSize: 12, // Size of color circle
              symbolShape: "circle", // Can be "circle", "square", etc.
            },
          ]}
          areaBlendMode="normal"
          axisBottom={{
            renderTick: ({ tickIndex, x, y, value }) => {
              return (
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
          enableGridX={false}
          theme={chartTheme(theme)}
        />
      </div>
    }
    </div>
  );
}

export default DurationChart;