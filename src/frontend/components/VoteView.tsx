import { SYesNoVote } from "@/declarations/backend/backend.did";
import PutBallot from "./PutBallot";
import { useEffect, useMemo, useState } from "react";
import { EYesNoChoice } from "../utils/conversions/yesnochoice";
import VoteChart from "./charts/VoteChart";
import { BallotInfo } from "./types";
import { compute_vote_details } from "../utils/conversions/votedetails";
import ConsensusView from "./ConsensusView";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../constants";
import { useProtocolContext } from "./ProtocolContext";

interface VoteViewProps {
  vote: SYesNoVote;
  selected: boolean;
  setSelected: () => void;
}

const VoteView: React.FC<VoteViewProps> = ({ vote, selected, setSelected }) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const [ballot, setBallot] = useState<BallotInfo>({ choice: EYesNoChoice.Yes, amount: 0n });

  const { computeDecay } = useProtocolContext();

  const voteDetails = useMemo(() => {
    if (computeDecay === undefined) {
      return undefined;
    }
    return compute_vote_details(vote, computeDecay);
  }, [vote, computeDecay]);

  const resetVote = () => {
    setBallot({ choice: EYesNoChoice.Yes, amount: 0n });
  }

  useEffect(() => {
    resetVote();
  }, [selected, vote]);

  return (
    voteDetails !== undefined && (
      <div className={`flex flex-col content-center w-full bg-slate-50 dark:bg-slate-850 hover:cursor-pointer ${isMobile ? "py-1" : "py-3"}`}>
        <div className="w-full flex flex-row space-x-1 items-baseline" onClick={() => setSelected()}>
          <ConsensusView selected={selected} category={vote.info.category} voteDetails={voteDetails} text={vote.info.text} timestamp={vote.date} ballot={ballot} />
        </div>
        {selected && vote.vote_id !== undefined && (
          <div className="flex flex-col space-y-2 items-center w-full">
            {voteDetails.total > 0 && (
              <div className={`flex flex-col space-y-2 items-center ${isMobile ? "w-full px-3" : "w-2/3"}`}>
                <VoteChart vote={vote} ballot={ballot} />
                <PutBallot
                  id={vote.vote_id}
                  disabled={false}
                  voteDetails={voteDetails}
                  ballot={ballot}
                  setBallot={setBallot}
                  onMouseUp={() => {}}
                  onMouseDown={() => {}}
                />
              </div>
            )}
          </div>
        )}
      </div>
    )
  );
  
};

export default VoteView;
