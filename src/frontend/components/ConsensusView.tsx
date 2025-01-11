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

const ConsensusView: React.FC<ConsensusViewProps> = ({ vote, ballot }) => {

  const consensus = useMemo(() : Consensus | undefined => {
    const total = get_total_votes(vote) + (ballot?.amount ?? 0n);
    if (total === 0n) {
      return undefined;
    }
    const ratio = Number(get_yes_votes(vote) + (ballot?.choice === EYesNoChoice.Yes ? ballot.amount : 0n)) / Number(total);
    return (ratio >= 0.5 ? { choice: EYesNoChoice.Yes, ratio } : { choice: EYesNoChoice.No, ratio: 1 - ratio });
  }, [vote, ballot]);

  return (
      <div className="grid grid-cols-[minmax(200px,_1fr)_100px] grid-gap-2 justify-items-center items-baseline">
        <div className="justify-self-start flex flex-row">
          {vote.text}
        </div>
        {
          consensus && <div className={`flex flex-row items-baseline space-x-1 
              ${ballot && ballot?.amount > 0n ? `animate-pulse` : ``}
              ${consensus.choice === EYesNoChoice.Yes ? "text-brand-true" : "text-brand-false"}`}>
            <div className={`text-lg` }>{consensus.choice}</div>
            <div className={`text-sm leading-none`}>{consensus.ratio?.toFixed(2)}</div>
          </div>
        }
      </div>
  );
};

export default ConsensusView;
