import { SYesNoVote } from "../../declarations/backend/backend.did";
import { backendActor } from "./actors/BackendActor";
import { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../constants";
import VoteCard from "./VoteCard"
import { useProtocolContext } from "./context/ProtocolContext";
import { compute_vote_details } from "../utils/conversions/votedetails";
import { toNullable } from "@dfinity/utils";
import InfiniteScroll from "react-infinite-scroll-component";

const SkeletonLoader = ({ count }: { count: number }) => (
  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 p-3">
    {Array(count).fill(null).map((_, index) => (
      <div key={index} className="bg-gray-300 dark:bg-gray-700 rounded-lg shadow-md p-4 animate-pulse h-32"></div>
    ))}
  </div>
);

const VoteList = () => {

  const [searchParams, setSearchParams] = useSearchParams();
  const voteRefs = useRef<Map<string, (HTMLDivElement | null)>>(new Map());
  const selectedVoteId = useMemo(() => searchParams.get("voteId"), [searchParams]);
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const [votes, setVotes] = useState<SYesNoVote[]>([]);
  const [previous, setPrevious] = useState<string | undefined>(undefined);
  const [hasMore, setHasMore] = useState<boolean>(true);
  const limit = isMobile ? 10 : 16;

  const { computeDecay, info } = useProtocolContext();
  const navigate = useNavigate();

  const { call: fetchVotes } = backendActor.unauthenticated.useQueryCall({
    functionName: "get_votes",
  });

  const fetchAndSetVotes = async () => {

    const fetchedVotes = await fetchVotes([{ 
      previous: toNullable(previous), 
      limit: BigInt(limit)
    }]);

    if (fetchedVotes && fetchedVotes.length > 0) {
      setVotes((prevVotes) => {
        const mergedVotes = [...prevVotes, ...fetchedVotes];
        const uniqueVotes = Array.from(new Map(mergedVotes.map(v => [v.vote_id, v])).values());
        return uniqueVotes;
      });
      setPrevious(fetchedVotes.length === limit ? fetchedVotes[limit - 1].vote_id : undefined);
      setHasMore(fetchedVotes.length === limit);
    } else {
      setHasMore(false);
    }
  };  

  // Initial Fetch on Mount
  useEffect(() => {
    fetchAndSetVotes();
  }, []);

  useEffect(() => {
    if (votes && selectedVoteId !== null) {
      const voteElement = voteRefs.current.get(selectedVoteId);
      if (voteElement) {
        setTimeout(() => {
          voteElement.scrollIntoView({ behavior: "smooth", block: "start" });
        }, 50);
      }
    }
  }, [votes]);

  return (
    <div className="flex flex-col gap-y-1 w-full rounded-md">
      {/* Vote Grid */}
      <InfiniteScroll
        dataLength={votes.length}
        next={fetchAndSetVotes}
        hasMore={hasMore}
        loader={<SkeletonLoader count={5} />} // Adjust count as needed
        className="w-full flex flex-col min-h-full overflow-auto"
        style={{ height: "auto", overflow: "visible" }}
      >
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
          {votes.map((vote: SYesNoVote, index) => (
            computeDecay && vote.info.visible && info &&
              <div 
                key={index}
                ref={(el) => { voteRefs.current.set(vote.vote_id, el); }}
                className="bg-white dark:bg-slate-800 rounded-lg shadow-md p-3 hover:cursor-pointer border border-slate-200 dark:border-slate-700 hover:shadow-lg transition-all duration-200 ease-in-out"
                onClick={() => { setSearchParams({ voteId: vote.vote_id }); navigate(`/vote/${vote.vote_id}`); }}
              >
                <VoteCard 
                  tvl={vote.tvl} 
                  voteDetails={compute_vote_details(vote, computeDecay(info.current_time))} 
                  text={vote.info.text}
                  thumbnail={vote.info.thumbnail}
                />
              </div>
          ))}
        </div>
      </InfiniteScroll>
    </div>
  );
};

export default VoteList;
