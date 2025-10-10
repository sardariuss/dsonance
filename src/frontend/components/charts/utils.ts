import { nsToMs } from "../../utils/conversions/date";
import { Serie } from "@nivo/line";
import { TimeLine } from "@/frontend/utils/timeline";

export const create_serie = (id: string, duration_timeline: TimeLine<number>): Serie => {
  let data = duration_timeline.history.map((duration_ns) => {
    return {
      x: new Date(nsToMs(duration_ns.timestamp)),
      y: duration_ns.data
    };
  });
  data.push({
    x: new Date(nsToMs(duration_timeline.current.timestamp)),
    y: duration_timeline.current.data
  });
  return { id, data };
};