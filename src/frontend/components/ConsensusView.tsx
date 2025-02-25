import { useMemo } from "react";
import { BallotInfo } from "./types";
import { add_ballot, VoteDetails } from "../utils/conversions/votedetails";
import DateSpan from "./DateSpan";
import { useCurrencyContext } from "./CurrencyContext";
import { MOBILE_MAX_WIDTH_QUERY } from "../constants";
import { useMediaQuery } from "react-responsive";

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
  selected: boolean;
  category: string;
  voteDetails: VoteDetails;
  text: string;
  timestamp: bigint;
  ballot?: BallotInfo;
}

const ConsensusView: React.FC<ConsensusViewProps> = ({ selected, category, voteDetails, text, timestamp, ballot }) => {

  const { formatSatoshis } = useCurrencyContext();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const liveDetails = useMemo(() => {
    if (ballot) {
      return add_ballot(voteDetails, ballot);
    }
    return voteDetails;
  }, [voteDetails, ballot]);

  const blendedColor = useMemo(() => {
    return blendColors("#07E344", "#03B5FD", liveDetails.cursor); // Blend yes and no colors
  }, [liveDetails]);

  return (
    <div className="grid grid-cols-[auto_60px] sm:grid-cols-[100px_auto_100px_100px] gap-x-2 sm:gap-x-4 justify-items-center items-center grow pr-3 sm:pr-5">
      { !isMobile && <span>{category.split(" ")[0]}</span> }
      {
        selected ?
        <span className={`justify-self-start grow ${isMobile ? "pl-3" : ""}`}>
          {text}
          { selected && <span className="text-gray-400 text-sm">{" · "}</span> }
          { selected && <DateSpan timestamp={timestamp}/> }
        </span> :
        <span className={`justify-self-start max-w-full ${isMobile ? "pl-3" : ""}`}>
          {text}
        </span>
      }
      { !isMobile && 
        <span className={`justify-self-end ${ballot && ballot?.amount > 0n ? "animate-pulse" : ""}`}>{formatSatoshis(BigInt(Math.trunc(liveDetails.total)))}</span>
      }
      <div
        className={`justify-self-end text-lg leading-none ${ballot && ballot?.amount > 0n ? `animate-pulse` : ``}`}
        style={{ color: blendedColor, textShadow: "0.2px 0.2px 1px rgba(0, 0, 0, 0.4)" }}
      >
        { liveDetails.cursor.toFixed(2) }
      </div>
    </div>
  );
};

export default ConsensusView;
