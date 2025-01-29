import { SYesNoVote } from "@/declarations/backend/backend.did";
import { useMemo } from "react";
import { EYesNoChoice } from "../utils/conversions/yesnochoice";
import { BallotInfo } from "./types";
import { get_yes_votes } from "../utils/conversions/vote";
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

type Consensus = {
  choice: EYesNoChoice;
  ratio: number;
};

interface ConsensusViewProps {
  vote: SYesNoVote;
  ballot?: BallotInfo;
  total: bigint;
}

const ConsensusView: React.FC<ConsensusViewProps> = ({ vote, ballot, total }) => {

  const { formatSatoshis } = useCurrencyContext();

  const consensus = useMemo((): Consensus | undefined => {
    if (total === 0n) {
      return undefined;
    }
    const ratio =
      Number(get_yes_votes(vote) + (ballot?.choice === EYesNoChoice.Yes ? ballot.amount : 0n)) /
      Number(total);
    return { choice: ratio >= 0.5 ? EYesNoChoice.Yes : EYesNoChoice.No, ratio };
  }, [vote, ballot]);

  const blendedColor = useMemo(() => {
    if (!consensus) return "#000"; // Default color if no consensus
    return blendColors("#07E344", "#03B5FD", consensus.ratio); // Blend yes and no colors
  }, [consensus]);

  return (
    <div className="grid grid-cols-[minmax(200px,_1fr)_60px] sm:grid-cols-[minmax(400px,_1fr)_100px] gap-x-2 sm:gap-x-4 justify-items-center items-center grow">
      <span className="justify-self-start grow">
        {vote.info.text}
        <span className="text-gray-400 text-sm">{" · "}</span>
        <DateSpan timestamp={vote.date}/>
      </span>
      <div className="flex flex-col sm:flex-row items-center space-x-0 sm:space-x-6 justify-self-center space-y-2 sm:space-y-0">
        { consensus && (
          <div
            className={`text-lg leading-none ${ballot && ballot?.amount > 0n ? `animate-pulse` : ``}`}
            style={{ color: blendedColor, textShadow: "0.2px 0.2px 1px rgba(0, 0, 0, 0.4)" }}
          >
            {consensus.ratio?.toFixed(2)}
          </div>
        )}
        <div className="flex flex-row items-center justify-self-center">
          <span className={`${ballot && ballot?.amount > 0n ? "animate-pulse" : ""}`}>{formatSatoshis(total)}</span>
          <BitcoinIcon />
        </div>
      </div>
    </div>
  );
};

export default ConsensusView;
