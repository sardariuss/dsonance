import { useEffect, useMemo } from "react";
import { PositionInfo } from "./types";
import { add_position, PoolDetails } from "../utils/conversions/pooldetails";
import { useProtocolContext } from "./context/ProtocolContext";
import { formatDate, niceFormatDate, timeToDate } from "../utils/conversions/date";
import InfoIcon from "./icons/InfoIcon";
import { Link } from "react-router-dom";
import { DOCS_CDV_URL, DOCS_TVL_URL, PREVIEW_POOL_IMPACT } from "../constants";
import ConsensusIndicator from "./ConsensusIndicator";
import { useFungibleLedgerContext } from "./context/FungibleLedgerContext";

interface PoolFiguresProps {
  timestamp: bigint;
  poolDetails: PoolDetails;
  tvl: bigint;
  position?: PositionInfo;
}

// Helper component for figure display
interface FigureProps {
  label: string;
  value: React.ReactNode;
  docUrl?: string;
  shouldPulse?: boolean;
}

const Figure: React.FC<FigureProps> = ({ label, value, docUrl, shouldPulse = false }) => (
  <div className="grid grid-rows-2 justify-items-end h-16 gap-y-1">
    <span className="self-center flex flex-row gap-x-1 items-center">
      <span className="text-sm text-gray-600 dark:text-gray-400">{label}</span>
      {docUrl && (
        <Link className="w-full hover:cursor-pointer" to={docUrl} target="_blank" rel="noopener">
          <InfoIcon />
        </Link>
      )}
    </span>
    <span className={`self-center ${shouldPulse ? "animate-pulse" : ""}`}>
      {value}
    </span>
  </div>
);

const PoolFigures: React.FC<PoolFiguresProps> = ({ timestamp, poolDetails, tvl, position }) => {

  const { supplyLedger : { formatAmountUsd } } = useFungibleLedgerContext();
  const { info, refreshInfo } = useProtocolContext();

  // Check if position has impact (should trigger pulse animation)
  const hasPositionImpact = useMemo(() =>
    PREVIEW_POOL_IMPACT && position !== undefined && position.amount > 0n,
    [position]
  );

  // Calculate live details with position impact
  const liveDetails = useMemo(() => {
    if (PREVIEW_POOL_IMPACT && position && position.amount > 0n) {
      return add_position(poolDetails, position);
    }
    return poolDetails;
  }, [poolDetails, position]);

  // Calculate live TVL with position impact
  const liveTvl = useMemo(() =>
    PREVIEW_POOL_IMPACT ? tvl + (position?.amount ?? 0n) : tvl,
    [tvl, position]
  );

  const date = useMemo(() => {
    if (info === undefined) {
      return formatDate(timeToDate(timestamp));
    }
    return niceFormatDate(timeToDate(timestamp), timeToDate(info.current_time))
  }, [timestamp, info]);

  useEffect(() => {
    refreshInfo();
  }, [timestamp]);

  return (
    <div className="grid grid-cols-4 gap-x-2 gap-y-2 justify-items-center items-center w-full sm:w-2/3">
      <Figure
        label="Opened"
        value={date}
      />
      <Figure
        label="CDV"
        value={formatAmountUsd(liveDetails.total)}
        docUrl={DOCS_CDV_URL}
        shouldPulse={hasPositionImpact}
      />
      <Figure
        label="TVL"
        value={formatAmountUsd(liveTvl)}
        docUrl={DOCS_TVL_URL}
        shouldPulse={hasPositionImpact}
      />
      <Figure
        label="Consensus"
        value={
          liveDetails.cursor === undefined ? <></> :
          <ConsensusIndicator cursor={liveDetails.cursor} pulse={hasPositionImpact} />
        }
      />
    </div>
  );
};

export default PoolFigures;

export const PoolFiguresSkeleton: React.FC = () => {
  return (
  <div className="grid grid-cols-4 gap-x-2 gap-y-2 justify-items-center items-center w-full sm:w-2/3">
    {/* Opened Date */}
    <div className="grid grid-rows-2 justify-items-end">
      <span className="text-sm text-gray-600 dark:text-gray-400">Opened</span>
      <div className="w-20 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
    </div>

    {/* CDV */}
    <div className="grid grid-rows-2 justify-items-end">
      <span className="flex flex-row gap-x-1 items-center">
        <span className="text-sm text-gray-600 dark:text-gray-400">CDV</span>
        <Link className="w-full hover:cursor-pointer" to={DOCS_CDV_URL} target="_blank" rel="noopener">
          <InfoIcon/>
        </Link>
      </span>
      <div className="w-16 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
    </div>

    {/* TVL */}
    <div className="grid grid-rows-2 justify-items-end">
        <span className="self-center flex flex-row gap-x-1 items-center">
          <span className="text-sm text-gray-600 dark:text-gray-400">TVL</span>
          <Link className="w-full hover:cursor-pointer" to={DOCS_TVL_URL} target="_blank" rel="noopener">
            <InfoIcon/>
          </Link>
        </span>
      <div className="w-12 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
    </div>

    {/* Consensus */}
    <div className="grid grid-rows-2 justify-items-end">
      <span className="text-sm text-gray-600 dark:text-gray-400">Consensus</span>
      <div className="w-10 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
    </div>
  </div>
  );
}
