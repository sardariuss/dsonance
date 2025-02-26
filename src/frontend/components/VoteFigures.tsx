import { useEffect, useMemo } from "react";
import { BallotInfo } from "./types";
import { add_ballot, VoteDetails } from "../utils/conversions/votedetails";
import { useCurrencyContext } from "./CurrencyContext";
import { useProtocolContext } from "./ProtocolContext";
import { niceFormatDate, timeToDate } from "../utils/conversions/date";

// Utility to blend two colors based on a ratio (0 to 1)
const blendColors = (color1: string, color2: string, ratio: number) => {
  const hexToRgb = (hex: string) =>
    hex
      .replace(/^#/, "")
      .match(/.{2}/g)!
      .map((x) => parseInt(x, 16));
  const rgbToHex = (rgb: number[]) =>
    `#${rgb.map((x) => x.toString(16).padStart(2, "0")).join("")}`;

  const rgb1 = hexToRgb(color1);
  const rgb2 = hexToRgb(color2);
  const blended = rgb1.map((c1, i) => Math.round(c1 * ratio + rgb2[i] * (1 - ratio)));
  return rgbToHex(blended);
};

interface VoteFiguresProps {
  category: string;
  timestamp: bigint;
  voteDetails: VoteDetails;
  ballot?: BallotInfo;
}

const VoteFigures: React.FC<VoteFiguresProps> = ({ category, timestamp, voteDetails, ballot }) => {

  const { formatSatoshis } = useCurrencyContext();
  const { info, refreshInfo } = useProtocolContext();

  const liveDetails = useMemo(() => {
    if (ballot) {
      return add_ballot(voteDetails, ballot);
    }
    return voteDetails;
  }, [voteDetails, ballot]);

  const blendedColor = useMemo(() => {
    return blendColors("#07E344", "#03B5FD", liveDetails.cursor); // Blend yes and no colors
  }, [liveDetails]);

  useEffect(() => {
    refreshInfo();
  }
  , [timestamp]);

  return (
    <div className="grid grid-cols-2 sm:grid-cols-4 gap-x-2 gap-y-2 justify-items-center items-center w-full sm:w-2/3">
      <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
        <span className="text-sm text-gray-600 dark:text-gray-400">Opened</span>
        <span>{ (info !== undefined ? niceFormatDate(timeToDate(timestamp), timeToDate(info.current_time)) : "") } </span>
      </div>
      <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
        <span className="text-sm text-gray-600 dark:text-gray-400">Category</span>
        <span>{category}</span>
      </div>
      <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
        <span className="text-sm text-gray-600 dark:text-gray-400">TVL</span>
        <span className={`${ballot && ballot?.amount > 0n ? "animate-pulse" : ""}`}>{formatSatoshis(BigInt(Math.trunc(liveDetails.total)))}</span>
      </div>
      <div className="grid grid-rows-2 justify-items-center sm:justify-items-end">
        <span className="text-sm text-gray-600 dark:text-gray-400">Consensus</span>
        <div
          className={`${ballot && ballot?.amount > 0n ? `animate-pulse` : ``}`}
          style={{ color: blendedColor, textShadow: "0.2px 0.2px 1px rgba(0, 0, 0, 0.4)" }}
        >
          { liveDetails.cursor.toFixed(2) }
        </div>
      </div>
    </div>
  );
};

export default VoteFigures;
