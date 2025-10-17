import { useMemo } from "react";
import { SBallotType } from "@/declarations/protocol/protocol.did";
import { formatDate, timeDifference, timeToDate } from "../../utils/conversions/date";
import { unwrapLock } from "../../utils/conversions/ballot";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";
import { aprToApy } from "../../utils/lending";
import { formatDuration } from "@/frontend/utils/conversions/durationUnit";

interface PositionRowProps {
  ballot: SBallotType;
  now: bigint | undefined;
}

const PositionRow = ({ ballot, now }: PositionRowProps) => {
  const { supplyLedger: { formatAmountUsd } } = useFungibleLedgerContext();

  const { releaseTimestamp, durationAdded, reward, currentApy } = useMemo(() => {
    const lockDuration = unwrapLock(ballot.YES_NO).duration_ns;
    return {
      currentApy: aprToApy(ballot.YES_NO.foresight.apr.current),
      reward: ballot.YES_NO.foresight.reward,
      releaseTimestamp: ballot.YES_NO.timestamp + lockDuration.current.data,
      durationAdded: lockDuration.history.length === 0 ? undefined : lockDuration.current.data - lockDuration.history[0].data,
    };
  }, [ballot]);

  return now === undefined ? (
    <></>
  ) : (
    <div className="grid grid-cols-3 gap-2 sm:gap-4 items-center py-2 h-[60px] sm:h-[68px]">
      {/* Dissent */}
      <div className="w-full text-right flex items-center justify-end">
        <span className="text-sm">{ballot.YES_NO.dissent.toFixed(2)}</span>
      </div>

      {/* Time Left */}
      <div className={`w-full ${durationAdded ? "flex flex-col" : ""} text-right flex justify-end`}>
        <span className="text-sm">
          {releaseTimestamp <= now
            ? `${formatDate(timeToDate(releaseTimestamp))}`
            : `${timeDifference(timeToDate(releaseTimestamp), timeToDate(now))}`}
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
          {formatAmountUsd(ballot.YES_NO.amount + reward)}
        </span>
        <span className="text-xs text-green-500">
          {(currentApy * 100).toFixed(2)}% APY
        </span>
      </div>
    </div>
  );
};

export default PositionRow;
