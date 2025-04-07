import { VoteDetails } from "../utils/conversions/votedetails";
import { useCurrencyContext } from "./CurrencyContext";
import { MOBILE_MAX_WIDTH_QUERY } from "../constants";
import { useMediaQuery } from "react-responsive";
import ConsensusIndicator from "./ConsensusIndicator";

interface VoteRowProps {
  tvl: bigint;
  voteDetails: VoteDetails;
  text: string;
}

const VoteRow: React.FC<VoteRowProps> = ({ tvl, voteDetails, text }) => {

  const { formatSatoshis } = useCurrencyContext();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  return (
    <div className="grid grid-cols-[auto_60px] sm:grid-cols-[auto_100px_100px_100px] gap-x-2 sm:gap-x-4 justify-items-center items-center grow pr-3 sm:pr-5">
      <div className={`flex items-center h-[4.5em] sm:h-[3em] justify-self-start max-w-full pl-3`}>
        <span className="line-clamp-3 sm:line-clamp-2 overflow-hidden">
          {text}
        </span>
      </div>
      { !isMobile && 
        <span className={`justify-self-end`}>{formatSatoshis(BigInt(Math.trunc(voteDetails.total)))}</span>
      }
      { !isMobile && 
        <span className={`justify-self-end`}>{formatSatoshis(tvl)}</span>
      }

    { voteDetails.cursor !== undefined && <ConsensusIndicator cursor={voteDetails.cursor} /> }
    </div>
  );
};

export default VoteRow;

export const VoteRowSkeleton: React.FC = () => {
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  return (
    <div className="grid grid-cols-[auto_60px] sm:grid-cols-[auto_100px_100px_100px] gap-x-2 sm:gap-x-4 justify-items-center items-center grow pr-3 sm:pr-5">
      
      <div className={`flex items-center h-[4.5em] sm:h-[3em] justify-self-start w-full pl-3`}>
        <div className="w-full h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
      </div>

      {!isMobile && <div className="w-12 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse justify-self-end" />}

      {!isMobile && <div className="w-12 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse justify-self-end" />}
      
      <div className="w-10 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse justify-self-end"></div>
    </div>
  );
};
