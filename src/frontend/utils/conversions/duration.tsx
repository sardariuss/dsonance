import { Duration } from "@/declarations/protocol/protocol.did";

const NS_IN_YEAR = 31_557_600_000_000_000n; // 365.25 * 24 * 60 * 60 * 1_000_000_000
const NS_IN_DAY = 86_400_000_000_000n; // 24 * 60 * 60 * 1_000_000_000
const NS_IN_HOUR = 3_600_000_000_000n; // 60 * 60 * 1_000_000_000
const NS_IN_MINUTE = 60_000_000_000n; // 60 * 1_000_000_000
const NS_IN_SECOND = 1_000_000_000n;

export const durationToNs = (duration: Duration): bigint => {
    if('NS' in duration) {
        return duration.NS;
    };
    if('SECONDS' in duration) {
        return NS_IN_SECOND * duration.SECONDS;
    };
    if('MINUTES' in duration) {
        return NS_IN_MINUTE * duration.MINUTES;
    };
    if('HOURS' in duration) {
        return NS_IN_HOUR * duration.HOURS;
    };
    if('DAYS' in duration) {
        return NS_IN_DAY * duration.DAYS;
    };
    if('YEARS' in duration) {
        return NS_IN_YEAR * duration.YEARS;
    };
    throw new Error("Invalid duration");
};

    
    
    
    
    