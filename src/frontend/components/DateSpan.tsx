import { useEffect } from "react";
import { protocolActor } from "../actors/ProtocolActor";
import { niceFormatDate, timeToDate } from "../utils/conversions/date";

interface DateSpanProps {
    timestamp: bigint;
}

const DateSpan: React.FC<DateSpanProps> = ({ timestamp }) => {

    const { call: refreshNow, data: now } = protocolActor.useQueryCall({
        functionName: "get_time",
    });

    useEffect(() => {
        refreshNow();
    }
    , [timestamp]);

    return (
        <span className="text-gray-400 text-sm">
            { (now !== undefined ? niceFormatDate(timeToDate(timestamp), timeToDate(now)) : "") } 
        </span>
    );
}

export default DateSpan;