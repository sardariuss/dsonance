import { useEffect, useMemo } from "react";
import { BallotInfo } from "./types";
import { add_ballot, VoteDetails } from "../utils/conversions/votedetails";
import { useCurrencyContext } from "./CurrencyContext";
import { useProtocolContext } from "./ProtocolContext";
import { formatDate, niceFormatDate, timeToDate } from "../utils/conversions/date";
import InfoIcon from "./icons/InfoIcon";
import { Link } from "react-router-dom";
import { DOCS_EVP_URL, DOCS_TVL_URL, MOBILE_MAX_WIDTH_QUERY } from "../constants";
import ConsensusIndicator from "./ConsensusIndicator";
import { useMediaQuery } from "react-responsive";

interface VoteFiguresProps {
  timestamp: bigint;
  voteDetails: VoteDetails;
  tvl: bigint;
  ballot?: BallotInfo;
}

const VoteFigures: React.FC<VoteFiguresProps> = ({ timestamp, voteDetails, tvl, ballot }) => {

  const { formatSatoshis } = useCurrencyContext();
  const { info, refreshInfo } = useProtocolContext();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const liveDetails = useMemo(() => {
    if (ballot) {
      return add_ballot(voteDetails, ballot);
    }
    return voteDetails;
  }, [voteDetails, ballot]);

  const date = useMemo(() => {
    if (info === undefined || isMobile) {
      return formatDate(timeToDate(timestamp));
    }
    return niceFormatDate(timeToDate(timestamp), timeToDate(info.current_time))
  }
  , [timestamp, info, isMobile]);

  useEffect(() => {
    refreshInfo();
  }
  , [timestamp]);

  return (
    <div className="grid grid-cols-4 gap-x-2 gap-y-2 justify-items-center items-center w-full sm:w-2/3">
      <div className="grid grid-rows-2 justify-items-center sm:justify-items-end h-16 gap-y-1">
        <span className="self-center text-sm text-gray-600 dark:text-gray-400">Opened</span>
        <span className="self-center">{ date } </span>
      </div>
      <div className="grid grid-rows-2 justify-items-center sm:justify-items-end h-16 gap-y-1">
        <span className="self-center flex flex-row gap-x-1 items-center">
          <span className="text-sm text-gray-600 dark:text-gray-400">EVP</span>
          <Link className="w-full hover:cursor-pointer" to={DOCS_EVP_URL} target="_blank" rel="noopener">
            <InfoIcon/>
          </Link>
        </span>
        <span className={`self-center ${ballot && ballot?.amount > 0n ? "animate-pulse" : ""}`}>{formatSatoshis(BigInt(Math.trunc(liveDetails.total)))}</span>
      </div>
      <div className="grid grid-rows-2 justify-items-center sm:justify-items-end h-16 gap-y-1">
        <span className="self-center flex flex-row gap-x-1 items-center">
          <span className="text-sm text-gray-600 dark:text-gray-400">TVL</span>
          <Link className="w-full hover:cursor-pointer" to={DOCS_TVL_URL} target="_blank" rel="noopener">
            <InfoIcon/>
          </Link>
        </span>
        <span className={`self-center ${ballot && ballot?.amount > 0n ? "animate-pulse" : ""}`}>{ formatSatoshis(tvl + (ballot?.amount ?? 0n)) }</span>
      </div>
      <div className="grid grid-rows-2 justify-items-center sm:justify-items-end h-16 gap-y-1">
        <span className="self-center text-sm text-gray-600 dark:text-gray-400">Consensus</span>
        <span className="self-center">
          { liveDetails.cursor === undefined ? <></> : <ConsensusIndicator cursor={liveDetails.cursor} pulse={ballot && ballot?.amount > 0n}/> }
        </span>
      </div>
    </div>
  );
};

export default VoteFigures;

export const VoteFiguresSkeleton: React.FC = () => {
  return (
  <div className="grid grid-cols-2 sm:grid-cols-4 gap-x-2 gap-y-2 justify-items-center items-center w-full sm:w-2/3">
    {/* Opened Date */}
    <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
      <span className="text-sm text-gray-600 dark:text-gray-400">Opened</span>
      <div className="w-20 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
    </div>

    {/* EVP */}
    <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
      <span className="flex flex-row gap-x-1 items-center">
        <span className="text-sm text-gray-600 dark:text-gray-400">EVP</span>
        <Link className="w-full hover:cursor-pointer" to={DOCS_EVP_URL} target="_blank" rel="noopener">
          <InfoIcon/>
        </Link>
      </span>
      <div className="w-16 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
    </div>

    {/* TVL */}
    <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
        <span className="self-center flex flex-row gap-x-1 items-center">
          <span className="text-sm text-gray-600 dark:text-gray-400">TVL</span>
          <Link className="w-full hover:cursor-pointer" to={DOCS_TVL_URL} target="_blank" rel="noopener">
            <InfoIcon/>
          </Link>
        </span>
      <div className="w-12 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
    </div>

    {/* Consensus */}
    <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
      <span className="text-sm text-gray-600 dark:text-gray-400">Consensus</span>
      <div className="w-10 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
    </div>
  </div>
  );
}
