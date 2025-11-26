import { useMemo } from "react";
import { SPositionType } from "@/declarations/protocol/protocol.did";
import { formatDate, timeDifference, timeToDate } from "../../utils/conversions/date";
import { unwrapLock } from "../../utils/conversions/position";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";
import { aprToApy } from "../../utils/lending";
import { formatDuration } from "@/frontend/utils/conversions/durationUnit";
import { useProtocolContext } from "../context/ProtocolContext";

interface PositionRowProps {
  position: SPositionType;
}

const PositionRow = ({ position }: PositionRowProps) => {
  const { info } = useProtocolContext();
  const { supplyLedger: { formatAmountUsd } } = useFungibleLedgerContext();

  const { releaseTimestamp, durationAdded, reward, currentApy } = useMemo(() => {
    const lockDuration = unwrapLock(position.YES_NO).duration_ns;
    return {
      currentApy: aprToApy(position.YES_NO.foresight.apr.current),
      reward: position.YES_NO.foresight.reward,
      releaseTimestamp: position.YES_NO.timestamp + lockDuration.current.data,
      durationAdded: lockDuration.history.length === 0 ? undefined : lockDuration.current.data - lockDuration.history[0].data,
    };
  }, [position]);

  return info?.current_time === undefined ? (
    <></>
  ) : (
    <div className="grid grid-cols-3 gap-2 sm:gap-4 items-center py-2 h-[60px] sm:h-[68px]">
      {/* Dissent */}
      <div className="w-full text-right flex items-center justify-end">
        <span className="font-semibold text-sm">{position.YES_NO.dissent.toFixed(2)}</span>
      </div>

      {/* Time Left */}
      <div className={`w-full ${durationAdded ? "flex flex-col" : ""} text-right flex justify-end`}>
        <span className="font-semibold text-sm">
          {releaseTimestamp <= info?.current_time
            ? `${formatDate(timeToDate(releaseTimestamp))}`
            : `${timeDifference(timeToDate(releaseTimestamp), timeToDate(info?.current_time))}`}
        </span>
        <span>
          {durationAdded && (
            <span className="text-xs text-gray-400">
              +{formatDuration(durationAdded)}
            </span>
          )}
        </span>
      </div>

      {/* Value */}
      <div className="w-full flex flex-col items-end text-right justify-center">
        <span className="font-semibold text-sm">
          {formatAmountUsd(position.YES_NO.amount + reward)}
        </span>
        <span className="text-xs text-green-500">
          {(currentApy * 100).toFixed(2)}% APY
        </span>
      </div>
    </div>
  );
};

export default PositionRow;
