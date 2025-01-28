import { SYesNoVote } from "@/declarations/backend/backend.did";
import { useMemo } from "react";
import { EYesNoChoice } from "../utils/conversions/yesnochoice";
import { BallotInfo } from "./types";
import { get_total_votes, get_yes_votes } from "../utils/conversions/vote";

type Consensus = {
  choice: EYesNoChoice;
  ratio: number;
};

interface ConsensusViewProps {
  vote: SYesNoVote;
  ballot?: BallotInfo;
}

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

const ConsensusView: React.FC<ConsensusViewProps> = ({ vote, ballot }) => {
  const consensus = useMemo((): Consensus | undefined => {
    const total = get_total_votes(vote) + (ballot?.amount ?? 0n);
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
    <div className="grid grid-cols-[minmax(200px,_1fr)_100px] grid-gap-2 justify-items-center items-baseline grow">
      <div className="justify-self-start flex flex-row grow">{vote.info.text}</div>
      {consensus && (
        <div
          className={`flex flex-row items-baseline space-x-1 ${
            ballot && ballot?.amount > 0n ? `animate-pulse` : ``
          }`}
          style={{ color: blendedColor }} // Apply blended color
        >
          <div className={`text-lg hidden`}>{consensus.choice}</div>
          <div className={`text-lg leading-none`}>{consensus.ratio?.toFixed(2)}</div>
        </div>
      )}
    </div>
  );
};

export default ConsensusView;
