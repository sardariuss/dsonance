import { SYesNoVote } from "../../../declarations/backend/backend.did";
import { backendActor } from "../actors/BackendActor";
import { useEffect, useMemo, useRef, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../../constants";
import { toNullable } from "@dfinity/utils";
import { useAuth } from "@nfid/identitykit/react";
import UserVoteRow from "./UserVoteRow";
import AdaptiveInfiniteScroll from "../AdaptiveInfinitScroll";
import LoginIcon from "../icons/LoginIcon";


const UserVotes = () => {
  const { user, connect } = useAuth();

  if (user === undefined || user.principal.isAnonymous()) {
    return <UserVotesLogin connect={connect} />;
  }

  return <UserVotesContent user={user} />;
};

const UserVotesLogin = ({ connect }: { connect: () => void }) => (
  <div className="flex flex-col items-center bg-slate-50 dark:bg-slate-850 py-5 rounded-md w-full">
    <button
      className="button-simple flex items-center space-x-2 px-6 py-3"
      onClick={() => connect()}
    >
      <LoginIcon />
      <span>Login to see your opened votes</span>
    </button>
  </div>
);

const UserVotesContent = ({ user }: { user: NonNullable<ReturnType<typeof useAuth>["user"]> }) => {

  const [searchParams, setSearchParams] = useSearchParams();
  const voteRefs = useRef<Map<string, (HTMLLIElement | null)>>(new Map());
  const selectedVoteId = useMemo(() => searchParams.get("voteId"), [searchParams]);
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const [votes, setVotes] = useState<SYesNoVote[]>([]);
  const [previous, setPrevious] = useState<string | undefined>(undefined);
  const [hasMore, setHasMore] = useState<boolean>(true);
  const limit = isMobile ? 10 : 16;

  const { call: fetchVotes } = backendActor.unauthenticated.useQueryCall({
    functionName: "get_votes_by_author",
  });

  const selectVote = (voteId: string) => {
    setSearchParams((prevParams) => {
      const newParams = new URLSearchParams(prevParams);
  
      if (newParams.get("voteId") === voteId) {
        newParams.delete("voteId"); // Unselect if already selected
      } else {
        newParams.set("voteId", voteId); // Select if different
      }
  
      return newParams;
    });
  };
  

  const fetchAndSetVotes = async () => {

    const fetchedVotes = await fetchVotes([{ 
      author: {
        owner: user?.principal,
        subaccount: [],
      },
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
    <div className="flex flex-col items-center bg-slate-50 dark:bg-slate-850 p-2 rounded w-full">
      <AdaptiveInfiniteScroll
        dataLength={votes.length}
        next={fetchAndSetVotes}
        hasMore={hasMore}
        loader={<></>}
        className="w-full flex flex-col min-h-full overflow-auto"
        style={{ height: "auto", overflow: "visible" }}
      >
        <ul className="w-full flex flex-col gap-y-2">
          {
            /* Size of the header is 26 on mobile and 22 on desktop */
            votes.map((vote, index) => (
              <li key={index} ref={(el) => {voteRefs.current.set(vote.vote_id, el)}} 
                className="w-full scroll-mt-[104px] sm:scroll-mt-[88px]" 
                onClick={(e) => { selectVote(vote.vote_id); }}>
                <UserVoteRow vote={vote} selected={vote.vote_id === selectedVoteId}/>
              </li>
            ))
          }
        </ul>
      </AdaptiveInfiniteScroll>
    </div>
  );
};

export default UserVotes;
