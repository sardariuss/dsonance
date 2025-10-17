import { useMemo } from "react";
import { fromNullable } from "@dfinity/utils";
import { backendActor } from "../actors/BackendActor";
import { SBallotType } from "@/declarations/protocol/protocol.did";
import { createThumbnailUrl } from "../../utils/thumbnail";
import { useProtocolContext } from "../context/ProtocolContext";
import { compute_vote_details } from "../../utils/conversions/votedetails";
import BallotRow from "./BallotRow";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../../constants";

interface VoteGroupProps {
  voteId: string;
  ballots: SBallotType[];
  now: bigint | undefined;
  selectedBallotId: string | null;
  onBallotClick: (ballotId: string) => void;
  ballotRefs: React.MutableRefObject<Map<string, HTMLLIElement | null>>;
}

const VoteGroup = ({ voteId, ballots, now, selectedBallotId, onBallotClick, ballotRefs }: VoteGroupProps) => {
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const { computeDecay, info } = useProtocolContext();

  const { data: opt_vote } = backendActor.unauthenticated.useQueryCall({
    functionName: "get_vote",
    args: [{ vote_id: voteId }],
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

  const voteDetails = useMemo(() => {
    if (vote === undefined || computeDecay === undefined || info === undefined) {
      return undefined;
    }
    return compute_vote_details(vote, computeDecay(info.current_time));
  }, [vote, computeDecay, info]);

  return (
    <div className="rounded-lg bg-slate-100 dark:bg-gray-750 border border-gray-300 dark:border-gray-700 overflow-hidden">
      {/* Vote Header */}
      <div className="flex items-center gap-3 px-3 py-3 bg-slate-50 dark:bg-gray-800 border-b border-gray-300 dark:border-gray-700">
        <img
          className="w-12 h-12 min-w-12 min-h-12 bg-contain bg-no-repeat bg-center rounded-md"
          src={thumbnailUrl}
          alt="Vote Thumbnail"
        />
        <div className="flex-1 min-w-0">
          {vote === undefined || voteDetails === undefined ? (
            <div className="w-full h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
          ) : (
            <span className="line-clamp-2 overflow-hidden text-gray-900 dark:text-gray-100">
              {vote.info.text}
            </span>
          )}
        </div>
      </div>

      {/* Ballot Rows */}
      <div className="flex flex-col">
        {ballots.map((ballot, index) => (
          <li
            key={ballot.YES_NO.ballot_id}
            ref={(el) => {
              ballotRefs.current.set(ballot.YES_NO.ballot_id, el);
            }}
            onClick={() => onBallotClick(ballot.YES_NO.ballot_id)}
            className="hover:cursor-pointer"
          >
            <BallotRow
              ballot={ballot}
              now={now}
            />
          </li>
        ))}
      </div>
    </div>
  );
};

export default VoteGroup;
