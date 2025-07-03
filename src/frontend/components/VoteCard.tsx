import { VoteDetails } from "../utils/conversions/votedetails";
import { useCurrencyContext } from "./context/CurrencyContext";
import ConsensusIndicator from "./ConsensusIndicator";
import { useMemo } from "react";

interface VoteCardProps {
  tvl: bigint;
  voteDetails: VoteDetails;
  text: string;
  thumbnail: number[] | Uint8Array;
}

const VoteCard: React.FC<VoteCardProps> = ({ tvl, voteDetails, text, thumbnail }) => {
  const { formatSatoshis } = useCurrencyContext();

  const thumbnailUrl = useMemo(() => {
    const byteArray = new Uint8Array(thumbnail);
    const blob = new Blob([byteArray]);
    return URL.createObjectURL(blob);
  }, [thumbnail]);

  return (
    <div className="relative flex flex-col h-full min-h-28">
      {/* Top Row: Image, Text, and Consensus */}
      <div className="flex items-center gap-3">
        {/* Thumbnail Image */}
        <img 
          className="w-10 h-10 min-w-10 min-h-10 bg-contain bg-no-repeat bg-center rounded-md self-start" 
          src={thumbnailUrl}
          alt="Vote Thumbnail"
        />

        {/* Vote Text */}
        <div className="flex-grow text-gray-800 dark:text-gray-200 font-medium line-clamp-3">
          {text}
        </div>

        {/* Consensus Indicator */}
        {voteDetails.cursor !== undefined && (
          <div>
            <ConsensusIndicator cursor={voteDetails.cursor} />
          </div>
        )}
      </div>

      {/* Bottom Row: EVP and TVL */}
      <div className="mt-auto flex justify-between items-center text-sm text-gray-600 dark:text-gray-400 pt-4">
        <span>EVP: {formatSatoshis(BigInt(Math.trunc(voteDetails.total)))}</span>
        <span>TVL: {formatSatoshis(tvl)}</span>
      </div>
    </div>
  );
};

export default VoteCard;

export const VoteCardSkeleton: React.FC = () => {
  return (
    <div className="flex flex-col h-full">
      {/* Top Row: Image and Text */}
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 bg-gray-300 dark:bg-gray-700 rounded-md animate-pulse"></div>
        <div className="flex-grow h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
      </div>

      {/* Bottom Row: EVP and TVL */}
      <div className="mt-auto flex justify-between items-center text-sm text-gray-600 dark:text-gray-400 pt-4">
        <div className="w-16 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
        <div className="w-16 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
      </div>
    </div>
  );
};
