import { SYesNoVote } from "@/declarations/backend/backend.did";
import PutBallot from "./PutBallot";
import { useEffect, useMemo, useState } from "react";
import { EYesNoChoice } from "../utils/conversions/yesnochoice";
import PutBallotPreview from "./PutBallotPreview";
import VoteChart from "./charts/VoteChart";
import VoteSlider from "./VoteSlider";
import { BallotInfo } from "./types";
import { get_total_votes } from "../utils/conversions/vote";
import ConsensusView from "./ConsensusView";
import LinkIcon from "./icons/LinkIcon";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../constants";

interface VoteViewProps {
  vote: SYesNoVote;
  refreshVotes?: () => void;
  selected: string | null;
  setSelected: (selected: string | null) => void;
}

const VoteView: React.FC<VoteViewProps> = ({ vote, refreshVotes, selected, setSelected }) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const [ballot, setBallot] = useState<BallotInfo>({ choice: EYesNoChoice.Yes, amount: 0n });

  const total = useMemo(() : bigint => {
    return get_total_votes(vote) + (ballot?.amount ?? 0n);
  }, [vote, ballot]);

  const resetVote = () => {
    setBallot({ choice: EYesNoChoice.Yes, amount: 0n });
  }

  useEffect(() => {
    resetVote();
  }, [selected, vote]);

  return isMobile ? 
  (
    <div className="flex flex-col content-center border-b dark:border-gray-700 px-2 py-1 hover:cursor-pointer space-y-2 w-full hover:bg-slate-50 hover:dark:bg-slate-850">
      <div className="w-full flex flex-row space-x-1 items-baseline" onClick={(e) => { setSelected(selected === vote.vote_id ? null : vote.vote_id) }}>
        <ConsensusView vote={vote} ballot={ballot} total={total}/>
      </div>
      {
        selected === vote.vote_id && vote.vote_id !== undefined && (
          <div className="flex flex-col items-center space-y-2">
            {
              get_total_votes(vote) > 0n && <div className="flex flex-col space-y-2 items-center w-full px-2">
                <VoteChart vote={vote} ballot={ballot}/>
                <VoteSlider id={vote.vote_id} disabled={false} vote={vote} ballot={ballot} setBallot={setBallot} onMouseUp={() => {}} onMouseDown={() => {}}/>
              </div>
            }
            <PutBallotPreview vote_id={vote.vote_id} ballot={ballot} />
            <PutBallot 
              vote_id={vote.vote_id} 
              refreshVotes={refreshVotes} 
              ballot={ballot}
              setBallot={setBallot}
              resetVote={resetVote}
            />
            <span className="hidden"> { vote.vote_id } </span>
          </div>
        )
      }
    </div>
  ) : (
    <div className="flex flex-col content-center border-b dark:border-gray-700 px-5 py-1 hover:cursor-pointer space-y-2 w-full hover:bg-slate-50 hover:dark:bg-slate-850">
      <div className="w-full grid grid-cols-[minmax(300px,_1fr)_50px] items-center gap-x-8" onClick={(e) => { setSelected(selected === vote.vote_id ? null : vote.vote_id) }}>
        <ConsensusView vote={vote} ballot={ballot} total={total}/>
        <div className="flex flex-row dark:stroke-gray-200 dark:hover:stroke-white hover:stroke-black stroke-gray-800 hover:cursor-pointer"
          onClick={(e) => { e.stopPropagation(); window.open(`/vote/${vote.vote_id}`, "_blank") }}
        >
          <LinkIcon/>
        </div>
      </div>
      {
        selected === vote.vote_id && vote.vote_id !== undefined && (
          <div className="flex flex-col space-y-2 items-center">
            {
              get_total_votes(vote) > 0n && <div className="flex flex-col space-y-2 items-center w-4/5">
                <VoteChart vote={vote} ballot={ballot}/>
                <VoteSlider id={vote.vote_id} disabled={false} vote={vote} ballot={ballot} setBallot={setBallot} onMouseUp={() => {}} onMouseDown={() => {}}/>
              </div>
            }
            <PutBallotPreview vote_id={vote.vote_id} ballot={ballot} />
            <PutBallot 
              vote_id={vote.vote_id} 
              refreshVotes={refreshVotes} 
              ballot={ballot}
              setBallot={setBallot}
              resetVote={resetVote}
            />
            <span className="hidden"> { vote.vote_id } </span>
          </div>
        )
      }
    </div>
  );
};

export default VoteView;
