
export const dateToTime = (date: Date) : bigint => {
  return BigInt(date.getTime() * 1_000_000);
}

export const nsToMs = (ns: bigint) : number => {
  return Number(ns / 1_000_000n);
}

export const msToNs = (ms: number) : bigint => {
  return BigInt(ms * 1_000_000);
}

export const timeToDate = (time: bigint) : Date => {
  return new Date(Number(time / 1_000_000n));
}

export const niceFormatDate = (date: Date, now: Date) : string => {
  
  const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000);

  // Handle "X seconds/minutes/hours ago"
  if (diffInSeconds < 60) {
    return `${diffInSeconds}s ago`;
  } else if (diffInSeconds < 3600) {
    return `${Math.floor(diffInSeconds / 60)}m ago`;
  } else if (diffInSeconds < 86400) {
    return `${Math.floor(diffInSeconds / 3600)}h ago`;
  }

  // Handle dates within the same year
  const isSameYear = now.getFullYear() === date.getFullYear();
  const options: Intl.DateTimeFormatOptions = isSameYear
    ? { month: 'short', day: 'numeric' }
    : { month: 'short', day: 'numeric', year: 'numeric' };

  // Format as "MMM DD" or "MMM DD, YYYY"
  return date.toLocaleDateString('en-US', options);
}

export const timeDifference = (date: Date, now: Date): string => {
  const diffInSeconds = Math.floor((date.getTime() - now.getTime()) / 1000);

  // Handle "X seconds/minutes/hours/days/months/years"
  if (Math.abs(diffInSeconds) < 60) {
    return `${diffInSeconds}s`;
  } else if (Math.abs(diffInSeconds) < 3600) {
    return `${Math.floor(diffInSeconds / 60)}m`;
  } else if (Math.abs(diffInSeconds) < 86400) {
    return `${Math.floor(diffInSeconds / 3600)}h`;
  } else if (Math.abs(diffInSeconds) < 31536000) {
    return `${Math.floor(diffInSeconds / 86400)}d`;
  } else {
    return `${Math.floor(diffInSeconds / 31536000)}y`;
  }
}

export const formatDate = (date: Date) : string => {
  return date.toISOString().split('T')[0];
}