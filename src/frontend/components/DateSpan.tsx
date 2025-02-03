import { useEffect } from "react";
import { protocolActor } from "../actors/ProtocolActor";
import { niceFormatDate, timeToDate } from "../utils/conversions/date";
import { useProtocolContext } from "./ProtocolContext";

interface DateSpanProps {
    timestamp: bigint;
}

const DateSpan: React.FC<DateSpanProps> = ({ timestamp }) => {

    const { info, refreshInfo } = useProtocolContext();

    useEffect(() => {
        refreshInfo();
    }
    , [timestamp]);

    return (
        <span className="text-gray-400 text-sm">
            { (info !== undefined ? niceFormatDate(timeToDate(timestamp), timeToDate(info.current_time)) : "") } 
        </span>
    );
}

export default DateSpan;