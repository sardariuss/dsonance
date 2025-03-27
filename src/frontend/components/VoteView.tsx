import { SYesNoVote } from "@/declarations/backend/backend.did";
import PutBallot from "./PutBallot";
import { useEffect, useMemo, useState } from "react";
import { EYesNoChoice } from "../utils/conversions/yesnochoice";
import VoteChart from "./charts/VoteChart";
import { BallotInfo } from "./types";
import { add_ballot, compute_vote_details } from "../utils/conversions/votedetails";
import { useNavigate } from "react-router-dom";
import { useProtocolContext } from "./ProtocolContext";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../constants";
import VoteFigures, { VoteFiguresSkeleton } from "./VoteFigures";
import BackArrowIcon from "./icons/BackArrowIcon";
import { interpolate_now, map_timeline } from "../utils/timeline";
import ConsensusChart from "./charts/ConsensusChart";
import { blendColors } from "../utils/colors";

interface VoteViewProps {
  vote: SYesNoVote;
}

const VoteView: React.FC<VoteViewProps> = ({ vote }) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const navigate = useNavigate();

  const [ballot, setBallot] = useState<BallotInfo>({ choice: EYesNoChoice.Yes, amount: 0n });

  const { computeDecay, info } = useProtocolContext();

    // TODO: remove redundant code
  const { voteDetails, liveDetails } = useMemo(() => {
    if (computeDecay === undefined || info === undefined) {
      return { voteDetails: undefined, liveDetails: undefined };
    }
  
    const voteDetails = compute_vote_details(vote, computeDecay(info.current_time));
    const liveDetails = ballot ? add_ballot(voteDetails, ballot) : voteDetails;
  
    return { voteDetails, liveDetails };
  }, [vote, computeDecay, info, ballot]);
  
  const consensusTimeline = useMemo(() => {
    if (liveDetails === undefined || info === undefined) {
      return undefined;
    }
  
    let timeline = interpolate_now(
      map_timeline(vote.aggregate, (aggregate) => 
        Number(aggregate.total_yes) / Number(aggregate.total_yes + aggregate.total_no)
      ),
      info.current_time
    );
  
    if (liveDetails.cursor !== undefined) {
      timeline.current.data = liveDetails.cursor;
    }
  
    return timeline;
  }, [liveDetails]);
    

  const resetVote = () => {
    setBallot({ choice: EYesNoChoice.Yes, amount: 0n });
  }

  useEffect(() => {
    resetVote();
  }, [vote]);

  return (
    <div className={`flex flex-col items-center ${isMobile ? "px-3 py-1 w-full" : "py-3 w-2/3"}`}>
      <div className="w-full grid grid-cols-3 space-x-1 mb-3 items-center">
        <div className="hover:cursor-pointer justify-self-start" onClick={() => navigate(-1)}>
          <BackArrowIcon/>
        </div>
        <span className="text-xl font-semibold items-baseline justify-self-center">Vote</span>
        <span className="grow">{/* spacer */}</span>
      </div>
      <div className="w-full text-center mb-4 mx-auto">
        { vote.info.text }
      </div>
      { voteDetails !== undefined ? 
        <VoteFigures category={vote.info.category} timestamp={vote.date} voteDetails={voteDetails} ballot={ballot} /> :
        <VoteFiguresSkeleton />
      }
      { voteDetails !== undefined && vote.vote_id !== undefined ? 
        <div className="flex flex-col space-y-2 items-center w-full">
          { voteDetails.total > 0 && <VoteChart vote={vote} ballot={ballot} /> }
          { consensusTimeline !== undefined && liveDetails?.cursor !== undefined && <ConsensusChart timeline={consensusTimeline} format_value={(value: number) => (value * 100).toFixed(0) + "%"} color={blendColors("#07E344", "#03B5FD", liveDetails.cursor)} y_max={1} y_min={0}/> }
          <PutBallot
            id={vote.vote_id}
            disabled={false}
            voteDetails={voteDetails}
            ballot={ballot}
            setBallot={setBallot}
            onMouseUp={() => {}}
            onMouseDown={() => {}}
          />
        </div> : 
        <div className="flex flex-col space-y-2 items-center w-full">
          <div className="w-full h-64 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"/>
          <div className="w-full h-32 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"/>
        </div>
      }
    </div>
  );
  
};

export default VoteView;

export const VoteViewSkeleton: React.FC = () => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const navigate = useNavigate();

  return (
    <div className={`flex flex-col items-center ${isMobile ? "px-3 py-1 w-full" : "py-3 w-2/3"}`}>
      <div className="w-full grid grid-cols-3 space-x-1 mb-3 items-center">
        <div className="hover:cursor-pointer justify-self-start" onClick={() => navigate(-1)}>
          <BackArrowIcon/>
        </div>
        <span className="text-xl font-semibold items-baseline justify-self-center">Vote</span>
        <span className="grow">{/* spacer */}</span>
      </div>
      <div className="flex flex-col w-full space-y-2 mb-4">
        <div className="w-full h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"/>
        <div className="w-full h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"/>
        <div className="w-1/2 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"/>
      </div>
      <VoteFiguresSkeleton />
      <div className="flex flex-col space-y-2 items-center w-full">
        <div className="w-full h-64 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"/>
        <div className="w-full h-32 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"/>
      </div>
    </div>
  );
}
