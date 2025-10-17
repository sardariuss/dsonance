import { useMemo } from "react";
import { fromNullable } from "@dfinity/utils";
import { backendActor } from "../actors/BackendActor";
import { SBallotType } from "@/declarations/protocol/protocol.did";
import { SYesNoVote } from "@/declarations/backend/backend.did";
import { createThumbnailUrl } from "../../utils/thumbnail";
import { useNavigate } from "react-router-dom";
import ChoiceView from "../ChoiceView";
import { toEnum } from "../../utils/conversions/yesnochoice";

interface PoolRowProps {
  ballot: SBallotType;
}

const PoolRow = ({ ballot }: PoolRowProps) => {
  const navigate = useNavigate();

  const { data: opt_vote } = backendActor.unauthenticated.useQueryCall({
    functionName: "get_vote",
    args: [{ vote_id: ballot.YES_NO.vote_id }],
  });

  const vote = useMemo(() => {
    return opt_vote ? fromNullable(opt_vote) : undefined;
  }, [opt_vote]);

  const thumbnailUrl = useMemo(() => {
    if (vote === undefined) {
      return undefined;
    }
    return createThumbnailUrl(vote.info.thumbnail);
  }, [vote]);

  return (
    <div className="py-2 h-[60px] sm:h-[68px] flex items-center">
      <div
        className="flex flex-row items-center hover:cursor-pointer gap-x-1 sm:gap-x-2 w-full"
        onClick={() => {
          navigate(`/vote/${ballot.YES_NO.vote_id}`);
        }}
      >
        <img
          className="w-8 h-8 sm:w-10 sm:h-10 min-w-8 min-h-8 sm:min-w-10 sm:min-h-10 bg-contain bg-no-repeat bg-center rounded-md"
          src={thumbnailUrl}
          alt="Vote Thumbnail"
        />
        <div className="flex flex-col space-y-0.5 sm:space-y-1 min-w-0 pl-1">
          <div className="text-xs sm:text-sm line-clamp-1 overflow-hidden">
            {vote === undefined ? (
              <span className="w-full h-4 sm:h-2 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
            ) : (
              <span className="line-clamp-1 overflow-hidden">{vote.info.text}</span>
            )}
          </div>
          <div className="flex">
            <ChoiceView choice={toEnum(ballot.YES_NO.choice)} />
          </div>
        </div>
      </div>
    </div>
  );
};

export default PoolRow;
