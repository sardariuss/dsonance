
export type TimeLine<T> = {
  current: TimedData<T>;
  history: TimedData<T>[];
}

export type TimedData<T> = {
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

export const interpolate_now = <T>(timeline: TimeLine<T>, now: bigint): TimeLine<T> => {
  let history = timeline.history;
  history.push(timeline.current);
  let current = {
    timestamp: now,
    data: timeline.current.data
  };
  return {
    current,
    history
  };
};

export const to_time_left = (timeline: TimeLine<bigint>, now: bigint): TimeLine<bigint> => {
  
  // Need to get the initial duration
  let initial_timestamp = timeline.current.timestamp;
  if (timeline.history.length > 0) {
    initial_timestamp = timeline.history[0].timestamp;
  };

  let history = timeline.history.map((timed_data) => ({
    timestamp: timed_data.timestamp,
    data: timed_data.data - (timed_data.timestamp - initial_timestamp)
  }));
  history.push({
    timestamp: timeline.current.timestamp,
    data: timeline.current.data - (timeline.current.timestamp - initial_timestamp)
  });
  let current = {
    timestamp: now,
    data: timeline.current.data - (now - initial_timestamp)
  };
  
  return {
    current,
    history
  };
};

export const map_timeline = <T1, T2>(timeline: TimeLine<T1>, f: (data: T1) => T2): TimeLine<T2> => {
  return {
    current: { timestamp: timeline.current.timestamp, data: f(timeline.current.data) },
    history: timeline.history.map((timed_data) => ({
      timestamp: timed_data.timestamp,
      data: f(timed_data.data)
    }))
  };
};

// TODO: remove temp hack made to avoid the first element of the history
export const map_timeline_hack = <T1, T2>(timeline: TimeLine<T1>, f: (data: T1) => T2): TimeLine<T2> => {
  return {
    current: { timestamp: timeline.current.timestamp, data: f(timeline.current.data) },
    history: timeline.history.map((timed_data) => ({
      timestamp: timed_data.timestamp,
      data: f(timed_data.data)
    })).slice(1)
  };
};

export const map_filter_timeline = <T1, T2>(timeline: TimeLine<T1>, f: (data: T1) => T2 | undefined): TimeLine<T2> | undefined => {
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

export const get_timeline_diff = <T extends number | bigint>(timeline: TimeLine<T>): T | undefined => {
  if (timeline.history.length !== 0) {
    let diff = (timeline.current.data - timeline.history[timeline.history.length - 1].data) as T;

    if (typeof diff === "bigint") {
      return diff !== BigInt(0) ? diff : undefined;
    }

    if (Math.abs(diff as number) > 0) {
      return diff;
    }
  }
  return undefined;
};


function mapFilter<T1, T2>(array: T1[], callback: (item: T1) => T2 | undefined): T2[] {
  const result = [];
  for (const item of array) {
    const mapped = callback(item);
    if (mapped !== undefined && mapped !== null) {
      result.push(mapped);
    }
  }
  return result;
}