import { DurationUnit } from "../../utils/conversions/durationUnit";

interface IntervalPickerProps {
    duration: DurationUnit | undefined; // Current interval
    setDuration: (duration: DurationUnit | undefined) => void; // Callback to set interval
    availableDurations: DurationUnit[]; // List of available intervals
}

const IntervalPicker: React.FC<IntervalPickerProps> = ({ duration, setDuration, availableDurations }) => {

    // Keep track of the currently selected interval
    const handleIntervalChange = (interval: DurationUnit | undefined) => {
        setDuration(interval);
    };

    return (
        <div className="flex flex-row space-x-0 sm:space-x-1 ">
        {[...availableDurations, undefined].map((interval) => (
            <button
                className={`text-base h-8 px-2 justify-center items-center button-discrete rounded-full
                    ${duration === interval ? "dark:bg-slate-700 bg-slate-300" : ""}`}
                key={interval === undefined ? "ALL" : interval}
                onClick={() => handleIntervalChange(interval)}
            >
                {interval === undefined ? "ALL" : interval} 
            </button>
        ))}
        </div>
    );
};

export default IntervalPicker;