
type TimeLine<T> = {
  current: TimedData<T>;
  history: TimedData<T>[];
}

type TimedData<T> = {
  timestamp: bigint;
  data: T;
};

export const get_current = <T>(timeline: TimeLine<T>): TimedData<T> => (
  timeline.current
)

export const get_first = <T>(timeline: TimeLine<T>): TimedData<T> => (
  timeline.history.length > 0 ? timeline.history[0] : timeline.current
)

export const to_number_timeline = (timeline: TimeLine<bigint>): TimeLine<number> => ({
  current: { timestamp: timeline.current.timestamp, data: Number(timeline.current.data) },
  history: timeline.history.map((timed_data) => ({
    timestamp: timed_data.timestamp,
    data: Number(timed_data.data)
  }))
});

function mapFilter<T>(array: T[], callback: (item: T) => T | undefined): T[] {
  const result = [];
  for (const item of array) {
    const mapped = callback(item);
    if (mapped !== undefined && mapped !== null) {
      result.push(mapped);
    }
  }
  return result;
}

export const map_timeline = <T>(timeline: TimeLine<T>, f: (data: T) => T | undefined): TimeLine<T> | undefined => {
  // If the current is undefined, consider the whole timeline undefined
  let current = f(timeline.current.data);
  if (current === undefined) {
    return undefined;
  }
  // Else remove the undefined values from the history
  return {
    current: { timestamp: timeline.current.timestamp, data: current },
    history: mapFilter(timeline.history, (timed_data) => {
      const mapped = f(timed_data.data);
      return mapped === undefined ? undefined : { timestamp: timed_data.timestamp, data: mapped };
    })
  };
};