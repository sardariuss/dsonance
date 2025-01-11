import { SYesNoVote } from "@/declarations/backend/backend.did";
import PutBallot from "./PutBallot";
import { useEffect, useMemo, useState } from "react";
import { EYesNoChoice } from "../utils/conversions/yesnochoice";
import PutBallotPreview from "./PutBallotPreview";
import VoteChart from "./charts/VoteChart";
import VoteSlider from "./VoteSlider";
import { BallotInfo } from "./types";
import { get_total_votes, get_votes, get_yes_votes } from "../utils/conversions/vote";
import ConsensusView from "./ConsensusView";
import DateSpan from "./DateSpan";
import { useCurrencyContext } from "./CurrencyContext";
import BitcoinIcon from "./icons/BitcoinIcon";

interface VoteViewProps {
  vote: SYesNoVote;
  refreshVotes?: () => void;
  selected: string | null;
  setSelected: (selected: string | null) => void;
}

const VoteView: React.FC<VoteViewProps> = ({ vote, refreshVotes, selected, setSelected }) => {

  const [ballot, setBallot] = useState<BallotInfo>({ choice: EYesNoChoice.Yes, amount: 0n });

  const { formatSatoshis } = useCurrencyContext();

  const total = useMemo(() : bigint => {
    return get_total_votes(vote) + (ballot?.amount ?? 0n);
  }, [vote, ballot]);

  const resetVote = () => {
    setBallot({ choice: EYesNoChoice.Yes, amount: 0n });
  }

  useEffect(() => {
    if (selected !== vote.vote_id) {
      resetVote();
    }
  }, [selected]);

  return (
    <div className="flex flex-col content-center border-b dark:border-gray-700 px-5 py-1 hover:cursor-pointer space-y-2 w-full hover:bg-slate-50 hover:dark:bg-slate-850">
      <div className="w-full grid grid-cols-[100px_minmax(300px,_1fr)_120px] items-baseline" onClick={(e) => { setSelected(selected === vote.vote_id ? null : vote.vote_id) }}>
        <div className="text-gray-400 text-sm">
          <DateSpan timestamp={vote.date}/>
        </div>
        <ConsensusView vote={vote} ballot={ballot}/>
        <div className="flex flex-row space-x-1 items-center justify-self-center">
          <span className={`${ballot && ballot?.amount > 0n ? "animate-pulse" : ""}`}>{formatSatoshis(total)}</span>
          <BitcoinIcon />
        </div>
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
              refreshVotes={refreshVotes} 
              ballot={ballot}
              setBallot={setBallot}
              resetVote={resetVote}
            />
            { vote.vote_id }
          </div>
        )
      }
    </div>
  );
};

export default VoteView;
