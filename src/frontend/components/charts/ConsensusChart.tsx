import { PointSymbolProps, ResponsiveLine, Serie } from '@nivo/line';
import { useContext, useMemo } from 'react';
import { create_serie } from './utils';
import { useMediaQuery } from 'react-responsive';
import { ThemeContext } from '../App';
import { MOBILE_MAX_WIDTH_QUERY, TICK_TEXT_COLOR_DARK, TICK_TEXT_COLOR_LIGHT } from '../../constants';
import { STimeline } from '@/declarations/protocol/protocol.did';
import { nsToMs } from '../../utils/conversions/date';
import { format } from 'date-fns';
import { chartTheme } from '.';
import { DurationUnit, toNs } from '../../utils/conversions/durationUnit';
import { useContainerSize } from '../hooks/useContainerSize';
import { useProtocolContext } from '../ProtocolContext';

interface ConsensusChartProps {
  timeline: STimeline;
  format_value: (value: number) => string;
  color: string;
  durationWindow: DurationUnit | undefined;
};

const ConsensusChart = ({ timeline, format_value, color, durationWindow }: ConsensusChartProps) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const { theme } = useContext(ThemeContext);
  const { info } = useProtocolContext();
  const { containerSize, containerRef } = useContainerSize();

  const CustomLastPoint = (props: PointSymbolProps) => {
      
    if (props.datum.x === undefined || props.datum.y === undefined || props.datum.x === null || props.datum.y === null) {
          return null;
      }
    
      const point_timestamp = new Date(props.datum.x).getTime();
      const last_timestamp = new Date(nsToMs(timeline.current.timestamp)).getTime();

      if (point_timestamp === last_timestamp && props.datum.y === timeline.current.data) {
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
      if (timeline === undefined || info === undefined) {
        return [];
      }

      if (durationWindow === undefined) {
        return [create_serie("consensus",  { history: timeline.history, current: timeline.current })];
      }

      let filtered_history = timeline.history.filter((item) => {
        const duration = info.current_time - item.timestamp;
        return duration <= toNs(1, durationWindow);
      });

      // Add a first point
      filtered_history = [
        {
          timestamp: info.current_time - toNs(1, durationWindow),
          data: filtered_history.length > 0 ? filtered_history[0].data : timeline.current.data,
        },
        ...filtered_history,
      ];

      return [create_serie("consensus",  { history: filtered_history, current: timeline.current })];
    }, [timeline, info, durationWindow]);
    
    return (
      <div className="flex flex-col items-center space-y-1 w-full h-full" ref={containerRef}>
        { containerSize && <div
          style={{
            width: `${containerSize.width}px`,
            height: `${containerSize.height}px`,
            overflowX: 'auto',
            overflowY: 'hidden',
          }}
        >
        <ResponsiveLine
          data={series}
          xScale={{ type: 'time' }}
          yScale={{ type: 'linear', min: 0, max: 1 }}
          margin={isMobile ? { top: 25, right: 25, bottom: 25, left: 25 } : { top: 25, right: 25, bottom: 25, left: 60 }}
          curve= { 'stepAfter' }  
          animate={false}
          enablePoints={true} // Disable default points
          pointSymbol={CustomLastPoint} // Custom last point rendering
          enableGridX={false}
          legends={[]}
          colors={[color]}
          theme={chartTheme(theme)}
          axisBottom={{
            renderTick: ({ x, y, value }) => {
              return (
                <g transform={`translate(${x},${y})`}>
                  <text
                    x={0}
                    y={16}
                    textAnchor="middle"
                    dominantBaseline="central"
                    style={{
                      fontSize: '12px',
                      fill: theme === "dark" ? TICK_TEXT_COLOR_DARK : TICK_TEXT_COLOR_LIGHT,
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
                    fill: theme === "dark" ? TICK_TEXT_COLOR_DARK : TICK_TEXT_COLOR_LIGHT,
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