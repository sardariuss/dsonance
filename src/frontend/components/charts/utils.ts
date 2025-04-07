import { STimeline } from "@/declarations/protocol/protocol.did";
import { nsToMs } from "../../utils/conversions/date";
import { Serie } from "@nivo/line";

export const create_serie = (id: string, duration_timeline: STimeline): Serie => {
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