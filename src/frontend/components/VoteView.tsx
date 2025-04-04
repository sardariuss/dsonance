import { SYesNoVote } from "@/declarations/backend/backend.did";
import PutBallot from "./PutBallot";
import { useContext, useEffect, useMemo, useState } from "react";
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
import { protocolActor } from "../actors/ProtocolActor";
import NewLockChart from "./charts/NewLockChart";
import { useBallotPreview } from "./hooks/useBallotPreview";
import { DurationUnit } from "../utils/conversions/durationUnit";
import IntervalPicker from "./charts/IntervalPicker";
import ChartToggle, { ChartType } from "./charts/ChartToggle";
import { ThemeContext } from "./App";

interface VoteViewProps {
  vote: SYesNoVote;
}

const VoteView: React.FC<VoteViewProps> = ({ vote }) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const navigate = useNavigate();
  const { theme } = useContext(ThemeContext);

  const [ballot, setBallot] = useState<BallotInfo>({ choice: EYesNoChoice.Yes, amount: 0n });
  const [duration, setDuration] = useState<DurationUnit | undefined>(DurationUnit.MONTH);
  const [selectedChart, setSelectedChart] = useState<ChartType>(ChartType.EVP);

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
        <VoteFigures timestamp={vote.date} voteDetails={voteDetails} ballot={ballot} tvl={vote.tvl} /> :
        <VoteFiguresSkeleton />
      }
      { voteDetails !== undefined && vote.vote_id !== undefined ? 
        <div className="flex flex-col space-y-2 items-center w-full">
          <div className={`w-full ${isMobile ? "h-[200px]" : "h-[300px]"}`}>
            { selectedChart === ChartType.EVP ?
              ( voteDetails.total > 0 && <VoteChart vote={vote} ballot={ballot} durationWindow={duration} /> )
              : selectedChart === ChartType.Consensus ?
              ( consensusTimeline !== undefined && liveDetails?.cursor !== undefined &&
                <ConsensusChart timeline={consensusTimeline} format_value={(value: number) => (value * 100).toFixed(0) + "%"} color={theme === "dark" ? "#ddd" : "#222"} durationWindow={duration}/> 
              ) 
              : selectedChart === ChartType.TVL ?
              ( voteBallots !== undefined &&  <NewLockChart ballots={voteBallots.map(ballot => ballot.YES_NO)} ballotPreview={ballotPreview} durationWindow={duration}/> )
              : <></>
            }
          </div>
          <div className="flex flex-row justify-between items-center w-full">
            <IntervalPicker duration={duration} setDuration={setDuration} availableDurations={[DurationUnit.WEEK, DurationUnit.MONTH, DurationUnit.YEAR]} />
            <ChartToggle selected={selectedChart} setSelected={setSelectedChart}/>
          </div>
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
