import { useEffect, useMemo } from "react";
import { PositionInfo } from "./types";
import { add_position, PoolDetails } from "../utils/conversions/pooldetails";
import { useProtocolContext } from "./context/ProtocolContext";
import { formatDate, niceFormatDate, timeToDate } from "../utils/conversions/date";
import InfoIcon from "./icons/InfoIcon";
import { Link } from "react-router-dom";
import { DOCS_CDV_URL, DOCS_TVL_URL, MOBILE_MAX_WIDTH_QUERY } from "../constants";
import ConsensusIndicator from "./ConsensusIndicator";
import { useMediaQuery } from "react-responsive";
import { useFungibleLedgerContext } from "./context/FungibleLedgerContext";

interface PoolFiguresProps {
  timestamp: bigint;
  poolDetails: PoolDetails;
  tvl: bigint;
  position?: PositionInfo;
}

const PoolFigures: React.FC<PoolFiguresProps> = ({ timestamp, poolDetails, tvl, position }) => {

  const { supplyLedger : { formatAmountUsd } } = useFungibleLedgerContext();
  const { info, refreshInfo } = useProtocolContext();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const liveDetails = useMemo(() => {
    if (position) {
      return add_position(poolDetails, position);
    }
    return poolDetails;
  }, [poolDetails, position]);

  const date = useMemo(() => {
    if (info === undefined) {
      return formatDate(timeToDate(timestamp));
    }
    return niceFormatDate(timeToDate(timestamp), timeToDate(info.current_time))
  }
  , [timestamp, info]);

  useEffect(() => {
    refreshInfo();
  }
  , [timestamp]);

  return (
    <div className="grid grid-cols-4 gap-x-2 gap-y-2 justify-items-center items-center w-full sm:w-2/3">
      <div className="grid grid-rows-2 justify-items-end h-16 gap-y-1">
        <span className="self-center text-sm text-gray-600 dark:text-gray-400">Opened</span>
        <span className="self-center">{ date } </span>
      </div>
      <div className="grid grid-rows-2 justify-items-end h-16 gap-y-1">
        <span className="self-center flex flex-row gap-x-1 items-center">
          <span className="text-sm text-gray-600 dark:text-gray-400">CDV</span>
          <Link className="w-full hover:cursor-pointer" to={DOCS_CDV_URL} target="_blank" rel="noopener">
            <InfoIcon/>
          </Link>
        </span>
        <span className={`self-center ${position && position?.amount > 0n ? "animate-pulse" : ""}`}>{formatAmountUsd(liveDetails.total)}</span>
      </div>
      <div className="grid grid-rows-2 justify-items-end h-16 gap-y-1">
        <span className="self-center flex flex-row gap-x-1 items-center">
          <span className="text-sm text-gray-600 dark:text-gray-400">TVL</span>
          <Link className="w-full hover:cursor-pointer" to={DOCS_TVL_URL} target="_blank" rel="noopener">
            <InfoIcon/>
          </Link>
        </span>
        <span className={`self-center ${position && position?.amount > 0n ? "animate-pulse" : ""}`}>{ formatAmountUsd(tvl + (position?.amount ?? 0n)) }</span>
      </div>
      <div className="grid grid-rows-2 justify-items-end h-16 gap-y-1">
        <span className="self-center text-sm text-gray-600 dark:text-gray-400">Consensus</span>
        <span className="self-center">
          { liveDetails.cursor === undefined ? <></> : <ConsensusIndicator cursor={liveDetails.cursor} pulse={position && position?.amount > 0n}/> }
        </span>
      </div>
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
