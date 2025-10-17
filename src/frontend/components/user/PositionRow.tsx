import { useMemo } from "react";
import { SBallotType } from "@/declarations/protocol/protocol.did";
import { timeDifference, timeToDate } from "../../utils/conversions/date";
import { unwrapLock } from "../../utils/conversions/ballot";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";
import { aprToApy } from "../../utils/lending";

interface PositionRowProps {
  ballot: SBallotType;
  now: bigint | undefined;
}

const PositionRow = ({ ballot, now }: PositionRowProps) => {
  const { supplyLedger: { formatAmountUsd } } = useFungibleLedgerContext();

  const { releaseTimestamp, reward, currentApy } = useMemo(() => {
    return {
      currentApy: aprToApy(ballot.YES_NO.foresight.apr.current),
      reward: ballot.YES_NO.foresight.reward,
      releaseTimestamp: ballot.YES_NO.timestamp + unwrapLock(ballot.YES_NO).duration_ns.current.data
    };
  }, [ballot]);

  return now === undefined ? (
    <></>
  ) : (
    <div className="grid grid-cols-3 gap-2 sm:gap-4 items-center py-2">
      {/* Dissent */}
      <div className="w-full text-right">
        <span className="text-sm">{ballot.YES_NO.dissent.toFixed(2)}</span>
      </div>

      {/* Time Left */}
      <div className="w-full text-right">
        <span className="text-sm">
          {releaseTimestamp <= now
            ? `expired`
            : `${timeDifference(timeToDate(releaseTimestamp), timeToDate(now))}`}
        </span>
      </div>

      {/* Value */}
      <div className="w-full flex flex-col items-end text-right">
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
