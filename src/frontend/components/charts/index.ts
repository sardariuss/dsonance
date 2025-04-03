import { format }             from "date-fns";
import { DurationUnit, toNs } from "../../utils/conversions/durationUnit";
import { nsToMs }             from "../../utils/conversions/date";

export type DurationParameters = {
    duration: bigint; 
    sample: bigint; 
    tick: bigint; 
    format: (date: Date) => string;
}

export const CHART_CONFIGURATIONS = new Map<DurationUnit, DurationParameters>([
    [DurationUnit.DAY,   { duration: toNs(1, DurationUnit.DAY),   sample: toNs(1, DurationUnit.HOUR), tick: toNs(2, DurationUnit.HOUR),  format: (date: Date) => format(date,                                     "HH:mm")} ],
    [DurationUnit.WEEK,  { duration: toNs(1, DurationUnit.WEEK),  sample: toNs(6, DurationUnit.HOUR), tick: toNs(12, DurationUnit.HOUR), format: (date: Date) => format(date, date.getHours() === 0 ? "dd MMM" : "HH:mm" )} ],
    [DurationUnit.MONTH, { duration: toNs(1, DurationUnit.MONTH), sample: toNs(1, DurationUnit.DAY),  tick: toNs(2, DurationUnit.DAY),   format: (date: Date) => format(date,                                    "dd MMM")} ],
    [DurationUnit.YEAR,  { duration: toNs(1, DurationUnit.YEAR),  sample: toNs(15, DurationUnit.DAY), tick: toNs(1, DurationUnit.MONTH), format: (date: Date) => format(date,                                    "dd MMM")} ],
]);

export type Interval = {
    dates: { date :number; decay: number }[];
    ticks: number[];
}

export const computeInterval = (end: bigint, e_duration: DurationUnit, compute_decay: (time: bigint) => number): Interval => {
    
    const { duration, sample, tick } = CHART_CONFIGURATIONS.get(e_duration)!;
    let dates : { date :number; decay: number }[] = [];
    let date = end;
    const startDate = end - duration;
    while (date >= startDate) {
        dates.push({ date: nsToMs(date), decay: compute_decay(date) });
        date -= sample;
    };
    dates.reverse();
    return { dates, ticks: computeTicksMs(duration, startDate, tick) };
}

export const computeTicksMs = (duration: bigint, start: bigint, tick_duration: bigint): number[] => {
    const numTicks = Math.floor(Number(duration) / Number(tick_duration));
    return Array.from(
        { length: numTicks + 1 },
        (_, i) => nsToMs((start + BigInt(i) * tick_duration))
    );
}

export const isNotFiniteNorNaN = (value: number) => {
    return !Number.isFinite(value) && !Number.isNaN(value);
}

export const computeAdaptiveTicks = (start: Date, end: Date): { ticks: number[]; format: string } => {
    const targetTickCount = 10; // Aim for ~10 ticks
    const durationMs = end.getTime() - start.getTime();
    const tickInterval = getOptimalTickInterval(durationMs, targetTickCount);
    const ticks = generateTicks(start.getTime(), end.getTime(), tickInterval);
    const dateFormat = getDateFormat(tickInterval);

    return { ticks, format: dateFormat };
};

const getOptimalTickInterval = (durationMs: number, targetTickCount: number): number => {
    // Define common time intervals in milliseconds
    const intervals = [
        { label: "minute", ms: 60 * 1000 },
        { label: "hour", ms: 60 * 60 * 1000 },
        { label: "day", ms: 24 * 60 * 60 * 1000 },
        { label: "week", ms: 7 * 24 * 60 * 60 * 1000 },
        { label: "month", ms: 30 * 24 * 60 * 60 * 1000 },
        { label: "year", ms: 365 * 24 * 60 * 60 * 1000 },
    ];

    // Find the largest interval that gives a reasonable tick count
    for (const interval of intervals) {
        const tickCount = durationMs / interval.ms;
        if (tickCount <= targetTickCount * 2) {
            return interval.ms * Math.ceil(tickCount / targetTickCount);
        }
    }

    return intervals[intervals.length - 1].ms; // Default to largest interval
};

const generateTicks = (startMs: number, endMs: number, tickInterval: number): number[] => {
    const ticks = [];
    for (let t = startMs; t <= endMs; t += tickInterval) {
        ticks.push(t);
    }
    return ticks;
};

const getDateFormat = (tickInterval: number): string => {
    if (tickInterval < 60 * 60 * 1000) return "HH:mm"; // Less than an hour -> time
    if (tickInterval < 24 * 60 * 60 * 1000) return "dd MMM HH:mm"; // Less than a day -> date + time
    if (tickInterval < 30 * 24 * 60 * 60 * 1000) return "dd MMM"; // Less than a month -> day + month
    if (tickInterval < 365 * 24 * 60 * 60 * 1000) return "MMM yy"; // Less than a year -> month + year
    return "yyyy"; // More than a year -> only year
};

/**
 * Calculates "nice" grid line values for a given range.
 *
 * @param minValue The minimum value of the data range.
 * @param maxValue The maximum value of the data range.
 * @param targetLines The desired approximate number of grid lines (default: 5).
 * @returns An array of numbers representing the grid line values.
 */
export const computeNiceGridLines = (
    minValue: number,
    maxValue: number,
    targetLines: number = 5
): number[] => {
    // 0. Handle edge cases and invalid input
    if (maxValue < minValue) {
        // Swap if min/max are reversed
        [minValue, maxValue] = [maxValue, minValue];
    }
    if (minValue === maxValue) {
        // If min and max are the same, return a single line or a small range around it
        if (minValue === 0) return [0];
        const magnitude = Math.pow(10, Math.floor(Math.log10(Math.abs(minValue))));
        const step = magnitude / 10; // Arbitrary small step
        // Return 3 points: below, at, above the value
        // Or just return the single value if that's preferred: return [minValue];
         return [minValue - step, minValue, minValue + step].map(v => parseFloat(v.toFixed(10)));
        // Simpler alternative: just return the single value
        // return [minValue];
    }
    if (targetLines < 2) {
        targetLines = 2; // Need at least 2 lines for a range
    }

    // 1. Calculate the raw range and initial step estimate
    const range = maxValue - minValue;
    // Use targetLines - 1 intervals for the calculation
    const rawStep = range / (targetLines - 1);

    // 2. Calculate a "nice" step size (multiple of 1, 2, 5, 10, ...)
    // Find the magnitude (power of 10) of the raw step
    const magnitude = Math.pow(10, Math.floor(Math.log10(rawStep)));
    // Find the normalized step (a value roughly between 1 and 10)
    const normalizedStep = rawStep / magnitude;

    // Determine the nice multiplier (1, 2, 5, or 10)
    let niceMultiplier: number;
    if (normalizedStep <= 1) {
        niceMultiplier = 1;
    } else if (normalizedStep <= 2) {
        niceMultiplier = 2;
    } else if (normalizedStep <= 5) {
        niceMultiplier = 5;
    } else {
        niceMultiplier = 10;
    }

    const niceStep = niceMultiplier * magnitude;

    // 3. Calculate the start and end points of the grid lines
    // Snap the start down to the nearest multiple of niceStep
    const niceMin = Math.floor(minValue / niceStep) * niceStep;
    // Snap the end up to the nearest multiple of niceStep
    let niceMax = Math.ceil(maxValue / niceStep) * niceStep;

     // Special case: If niceMin and niceMax are identical but the original range wasn't zero,
     // we need to ensure we have at least two points or adjust the range slightly.
     // This can happen if minValue and maxValue fall within the same step interval.
     // One option is to extend niceMax by one step.
     if (niceMin === niceMax && maxValue > minValue) {
         niceMax += niceStep;
     }

    // 4. Generate the grid line values
    const lines: number[] = [];
    let currentValue = niceMin;
    // Determine the number of decimal places needed for precision
    const stepString = niceStep.toString();
    const decimalPlaces = stepString.includes('.') ? stepString.split('.')[1].length : 0;
    const precision = Math.min(decimalPlaces, 10); // Cap precision to avoid excessive decimals

    // Iterate and add lines, handling potential floating point issues
    // Use a small epsilon to avoid issues with floating point comparisons
    const epsilon = niceStep * 1e-9;
    while (currentValue <= niceMax + epsilon) {
        // Use toFixed to manage precision, then parseFloat to convert back to number
        lines.push(parseFloat(currentValue.toFixed(precision)));
        currentValue += niceStep;
    }

    // Ensure the result isn't empty if something went wrong
    if (lines.length === 0) {
       return [parseFloat(niceMin.toFixed(precision)), parseFloat(niceMax.toFixed(precision))];
    }

    return lines;
};