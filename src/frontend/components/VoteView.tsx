import { SYesNoVote } from "@/declarations/backend/backend.did";
import PutBallot from "./PutBallot";
import { useEffect, useMemo, useState } from "react";
import { EYesNoChoice } from "../utils/conversions/yesnochoice";
import EvpChart from "./charts/EvpChart";
import { BallotInfo } from "./types";
import { add_ballot, compute_vote_details } from "../utils/conversions/votedetails";
import { useProtocolContext } from "./context/ProtocolContext";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../constants";
import VoteFigures, { VoteFiguresSkeleton } from "./VoteFigures";
import { interpolate_now, map_timeline } from "../utils/timeline";
import ConsensusChart from "./charts/ConsensusChart";
import { protocolActor } from "../actors/ProtocolActor";
import LockChart from "./charts/LockChart";
import { useBallotPreview } from "./hooks/useBallotPreview";
import { DurationUnit } from "../utils/conversions/durationUnit";
import IntervalPicker from "./charts/IntervalPicker";
import ChartToggle, { ChartType } from "./charts/ChartToggle";
import { createThumbnailUrl } from "../utils/thumbnail";

interface VoteViewProps {
  vote: SYesNoVote;
}

const VoteView: React.FC<VoteViewProps> = ({ vote }) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const [ballot, setBallot] = useState<BallotInfo>({ choice: EYesNoChoice.Yes, amount: 0n });
  const [duration, setDuration] = useState<DurationUnit | undefined>(DurationUnit.MONTH);
  const [selectedChart, setSelectedChart] = useState<ChartType>(ChartType.Consensus);

  const { data: voteBallots } = protocolActor.useQueryCall({
    functionName: "get_vote_ballots",
    args: [vote.vote_id], 
  });

  const { computeDecay, info } = useProtocolContext();
  
  const ballotPreview = useBallotPreview(vote.vote_id, ballot);

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
      timeline = {
        history: [...timeline.history, timeline.current],
        current: {
          timestamp: info.current_time,
          data: liveDetails.cursor,
        },
      } 
    }
  
    return timeline;
  }, [liveDetails]);
    
  const resetVote = () => {
    setBallot({ choice: EYesNoChoice.Yes, amount: 0n });
  }

  useEffect(() => {
    resetVote();
  }, [vote]);

  const thumbnail = useMemo(() => createThumbnailUrl(vote.info.thumbnail), [vote]);

  return (
    <div className={`flex flex-col items-center ${isMobile ? "px-3 py-1 w-full" : "py-3 w-2/3"}`}>
      {/* Top Row: Image and Vote Text */}
      <div className="w-full flex flex-row items-center gap-4 mb-4">
        {/* Placeholder Image */}
        <img 
          className="w-20 h-20 bg-contain bg-no-repeat bg-center rounded-md self-start"
          src={thumbnail}
        />
        {/* Vote Text */}
        <div className="flex-grow text-gray-800 dark:text-gray-200 font-medium text-lg">
          {vote.info.text}
        </div>
      </div>

      {/* Vote Details */}
      {voteDetails !== undefined ? 
        <VoteFigures timestamp={vote.date} voteDetails={voteDetails} ballot={ballot} tvl={vote.tvl} /> :
        <VoteFiguresSkeleton />
      }

      {/* Charts and Ballot */}
      {voteDetails !== undefined && vote.vote_id !== undefined ? 
        <div className="flex flex-col space-y-2 items-center w-full">
          {voteBallots && voteBallots.length > 0 &&
            <div className="w-full flex flex-col items-center justify-between space-y-2">
              <div className={`w-full ${isMobile ? "h-[200px]" : "h-[300px]"}`}>
                {selectedChart === ChartType.EVP ?
                  (voteDetails.total > 0 && <EvpChart vote={vote} ballot={ballot} durationWindow={duration} />)
                  : selectedChart === ChartType.Consensus ?
                  (consensusTimeline !== undefined && liveDetails?.cursor !== undefined &&
                    <ConsensusChart timeline={consensusTimeline} format_value={(value: number) => (value * 100).toFixed(0) + "%"} durationWindow={duration}/> 
                  ) 
                  : selectedChart === ChartType.TVL ?
                  (voteBallots !== undefined && <LockChart ballots={voteBallots.map(ballot => ballot.YES_NO)} ballotPreview={ballotPreview} durationWindow={duration}/>)
                  : <></>
                }
              </div>
              <div className="flex flex-row justify-between items-center w-full">
                <IntervalPicker duration={duration} setDuration={setDuration} availableDurations={[DurationUnit.WEEK, DurationUnit.MONTH, DurationUnit.YEAR]} />
                <ChartToggle selected={selectedChart} setSelected={setSelectedChart}/>
              </div>
            </div>
          }
          <PutBallot
            id={vote.vote_id}
            disabled={false}
            voteDetails={voteDetails}
            ballot={ballot}
            setBallot={setBallot}
            ballotPreview={ballotPreview?.new.YES_NO}
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

  return (
    <div className={`flex flex-col items-center ${isMobile ? "px-3 py-1 w-full" : "py-3 w-2/3"}`}>
      {/* Top Row: Placeholder Image and Vote Text */}
      <div className="w-full flex items-center gap-4 mb-4">
        <div className="w-20 h-20 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
        <div className="flex-grow h-6 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
      </div>

      {/* Vote Details Skeleton */}
      <VoteFiguresSkeleton />

      {/* Charts and Ballot Skeleton */}
      <div className="flex flex-col space-y-2 items-center w-full">
        <div className="w-full h-[200px] bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
        <div className="flex flex-row justify-between items-center w-full">
          <div className="w-1/3 h-8 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
          <div className="w-1/3 h-8 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
        </div>
        <div className="w-full h-12 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
      </div>
    </div>
  );
}
