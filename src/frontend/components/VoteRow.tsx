import { useMemo } from "react";
import { VoteDetails } from "../utils/conversions/votedetails";
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

interface VoteRowProps {
  category: string;
  voteDetails: VoteDetails;
  text: string;
}

const VoteRow: React.FC<VoteRowProps> = ({ category, voteDetails, text }) => {

  const { formatSatoshis } = useCurrencyContext();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const blendedColor = useMemo(() => {
    if (voteDetails.cursor === undefined) {
      return undefined;
    }
    return blendColors("#07E344", "#03B5FD", voteDetails.cursor); // Blend yes and no colors
  }, [voteDetails]);

  return (
    <div className="grid grid-cols-[auto_60px] sm:grid-cols-[100px_auto_100px_100px] gap-x-2 sm:gap-x-4 justify-items-center items-center grow pr-3 sm:pr-5">
      { !isMobile && <span>{category.split(" ")[0]}</span> }
      <div className={`flex items-center h-[4.5em] sm:h-[3em] justify-self-start max-w-full ${isMobile ? "pl-3" : ""}`}>
        <span className="line-clamp-3 sm:line-clamp-2 overflow-hidden">
          {text}
        </span>
      </div>
      { !isMobile && 
        <span className={`justify-self-end`}>{formatSatoshis(BigInt(Math.trunc(voteDetails.total)))}</span>
      }
      <div
        className={`justify-self-end text-lg leading-none`}
        style={{ color: blendedColor ?? "white", textShadow: "0.2px 0.2px 1px rgba(0, 0, 0, 0.4)" }}
      >
        { voteDetails.cursor !== undefined? voteDetails.cursor.toFixed(2) : "" }
      </div>
    </div>
  );
};

export default VoteRow;

export const VoteRowSkeleton: React.FC = () => {
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  return (
    <div className="grid grid-cols-[auto_60px] sm:grid-cols-[100px_auto_100px_100px] gap-x-2 sm:gap-x-4 justify-items-center items-center grow pr-3 sm:pr-5">
      {!isMobile && <div className="w-16 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />}
      
      <div className={`flex items-center h-[4.5em] sm:h-[3em] justify-self-start w-full ${isMobile ? "pl-3" : ""}`}>
        <div className="w-full h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
      </div>

      {!isMobile && <div className="w-12 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse justify-self-end" />}
      
      <div className="w-10 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse justify-self-end"></div>
    </div>
  );
};
