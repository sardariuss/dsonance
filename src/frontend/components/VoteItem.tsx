import { SYesNoVote } from "@/declarations/backend/backend.did";
import { useMemo } from "react";
import { compute_vote_details } from "../utils/conversions/votedetails";
import { useProtocolContext } from "./ProtocolContext";
import { useCurrencyContext } from "./CurrencyContext";

interface VoteItemProps {
  vote: SYesNoVote;
  index: number;
  setRef: (el: HTMLTableRowElement | null) => void;
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

const VoteItem: React.FC<VoteItemProps> = ({ vote, index, setRef }) => {

  const { formatSatoshis } = useCurrencyContext();

  const { computeDecay } = useProtocolContext();

  const voteDetails = useMemo(() => {
    if (computeDecay === undefined) {
      return undefined;
    }
    return compute_vote_details(vote, computeDecay);
  }, [vote, computeDecay]);

  const blendedColor = useMemo(() => {
    return blendColors("#07E344", "#03B5FD", voteDetails?.cursor ?? 0); // Blend yes and no colors
  }, [voteDetails]);

  return (
    voteDetails === undefined ? <></> : 
    <tr key={index} ref={(el) => {setRef(el)}} className="w-full scroll-mt-[104px] sm:scroll-mt-[88px] bg-slate-50 dark:bg-slate-850 border-t-2 border-slate-100 dark:border-slate-900">
      <td className="text-start pl-6 py-3">
      🔬
      </td>
      <td scope="row" className="text-base text-start grow px-3 py-3">
        {vote.info.text}
      </td>
      <td className="px-3 py-3 text-end">
        {formatSatoshis(BigInt(Math.trunc(voteDetails.total)))}
      </td>
      <td
        className={`text-lg leading-none pl-3 pr-6 py-3 text-end`}
        style={{ color: blendedColor, textShadow: "0.2px 0.2px 1px rgba(0, 0, 0, 0.4)" }}
      >
        { voteDetails.cursor.toFixed(2) }
      </td>
    </tr>
  );
};

export default VoteItem;
