import { SYesNoVote } from "@/declarations/backend/backend.did";
import PutBallot from "./PutBallot";
import { useEffect, useState } from "react";
import { EYesNoChoice } from "../utils/conversions/yesnochoice";
import PutBallotPreview from "./PutBallotPreview";
import { formatDateTime, timeToDate } from "../utils/conversions/date";
import VoteChart from "./charts/VoteChart";
import VoteSlider from "./VoteSlider";
import { BallotInfo } from "./types";
import { get_total_votes, get_votes, get_yes_votes } from "../utils/conversions/vote";
import ConsensusView from "./ConsensusView";

type FetchFunction = (eventOrReplaceArgs?: [] | React.MouseEvent<Element, MouseEvent> | undefined) => Promise<SYesNoVote[] | undefined>;

interface VoteViewProps {
  vote: SYesNoVote;
  fetchVotes?: FetchFunction;
  selected: string | null;
  setSelected: (selected: string | null) => void;
}

const VoteView: React.FC<VoteViewProps> = ({ vote, fetchVotes, selected, setSelected }) => {

  const [ballot, setBallot] = useState<BallotInfo>({ choice: EYesNoChoice.Yes, amount: 0n });

  const getTotalSide = (side: EYesNoChoice) : bigint => {
    let total_side = get_votes(vote, side);
    total_side += (ballot.choice === side ? ballot.amount : 0n);
    return total_side;
  }

  const getPercentage = (side: EYesNoChoice) => {
    const total = Number(get_total_votes(vote) + ballot.amount);
    if (total === 0) {
      throw new Error("Total number of votes is null");
    }
    return Number(getTotalSide(side)) / total * 100;
  }

  const resetVote = () => {
    setBallot({ choice: EYesNoChoice.Yes, amount: 0n });
  }

  useEffect(() => {
    if (selected !== vote.vote_id) {
      resetVote();
    }
  }, [selected]);

  return (
    <div className="flex flex-col content-center border-b dark:border-gray-700 hover:bg-slate-50 dark:hover:bg-slate-850 px-5 py-1 hover:cursor-pointer space-y-2 w-full">
      <div className="w-full" onClick={(e) => { setSelected(selected === vote.vote_id ? null : vote.vote_id) }}>
        <ConsensusView vote={vote} ballot={ballot}/>
      </div>
      {
        selected === vote.vote_id && vote.vote_id !== undefined && (
          <div className="flex flex-col space-y-2 items-center">
            {
              get_total_votes(vote) > 0n && <div className="flex flex-col space-y-2 items-center">
                <VoteChart vote={vote} ballot={ballot}/>
                <VoteSlider id={vote.vote_id} disabled={false} vote={vote} ballot={ballot} setBallot={setBallot} onMouseUp={() => {}} onMouseDown={() => {}}/>
              </div>
            }
            <PutBallotPreview vote_id={vote.vote_id} ballot={ballot} />
            <PutBallot 
              vote_id={vote.vote_id} 
              fetchVotes={fetchVotes} 
              ballot={ballot}
              setBallot={setBallot}
              resetVote={resetVote}
            />
            { /* formatDateTime(timeToDate(vote.date)) */ }
            { vote.vote_id }
          </div>
        )
      }
    </div>
  );
};

export default VoteView;
