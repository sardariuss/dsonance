import { useMemo } from "react";
import { BallotInfo } from "./types";
import { add_ballot, VoteDetails } from "../utils/conversions/votedetails";
import DateSpan from "./DateSpan";
import BitcoinIcon from "./icons/BitcoinIcon";
import { useCurrencyContext } from "./CurrencyContext";

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

interface ConsensusViewProps {
  voteDetails: VoteDetails;
  text: string;
  timestamp: bigint;
  ballot?: BallotInfo;
}

const ConsensusView: React.FC<ConsensusViewProps> = ({ voteDetails, text, timestamp, ballot }) => {

  const { formatSatoshis } = useCurrencyContext();

  const liveDetails = useMemo(() => {
    if (ballot) {
      return add_ballot(voteDetails, ballot);
    }
    return voteDetails;
  }, [voteDetails, ballot]);

  const blendedColor = useMemo(() => {
    if (!liveDetails.cursor) return "#000"; // Default color if no consensus
    return blendColors("#07E344", "#03B5FD", liveDetails.cursor); // Blend yes and no colors
  }, [liveDetails]);

  return (
    <div className="grid grid-cols-[minmax(200px,_1fr)_60px_60px] sm:grid-cols-[minmax(400px,_1fr)_100px_100px] gap-x-2 sm:gap-x-4 justify-items-center items-center grow">
      <span className="justify-self-start grow">
        {text}
        <span className="text-gray-400 text-sm">{" · "}</span>
        <DateSpan timestamp={timestamp}/>
      </span>
      { liveDetails.cursor && (
        <div
          className={`text-lg leading-none ${ballot && ballot?.amount > 0n ? `animate-pulse` : ``}`}
          style={{ color: blendedColor, textShadow: "0.2px 0.2px 1px rgba(0, 0, 0, 0.4)" }}
        >
          { liveDetails.cursor.toFixed(2) }
        </div>
      )}
      <div className="flex flex-row items-center justify-self-center">
        <span className={`${ballot && ballot?.amount > 0n ? "animate-pulse" : ""}`}>{formatSatoshis(BigInt(Math.trunc(liveDetails.total)))}</span>
        <BitcoinIcon />
      </div>
    </div>
  );
};

export default ConsensusView;
