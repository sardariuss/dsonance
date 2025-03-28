import { DurationUnit } from "../../utils/conversions/durationUnit";

interface IntervalPickerProps {
    duration: DurationUnit; // Current interval
    setDuration: (duration: DurationUnit) => void; // Callback to set interval
    availableDurations: DurationUnit[]; // List of available intervals
}

const IntervalPicker: React.FC<IntervalPickerProps> = ({ duration, setDuration, availableDurations }) => {

    // Keep track of the currently selected interval
    const handleIntervalChange = (interval: DurationUnit) => {
        setDuration(interval);
    };

    return (
        <div className="flex flex-row space-x-1 p-1 ">
        {availableDurations.map((interval) => (
            <button
                className={`h-8 px-2 justify-center items-center button-discrete rounded-full
                    ${duration === interval ? "dark:bg-slate-700 bg-slate-300" : ""}`}
                key={interval}
                onClick={() => handleIntervalChange(interval)}
            >
                {interval} {/* Convert enum to string */}
            </button>
        ))}
        </div>
    );
};

export default IntervalPicker;