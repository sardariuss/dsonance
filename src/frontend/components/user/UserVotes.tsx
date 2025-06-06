import { SYesNoVote } from "../../../declarations/backend/backend.did";
import { backendActor } from "../../actors/BackendActor";
import { useEffect, useMemo, useRef, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { useMediaQuery } from "react-responsive";
import { DSONANCE_COIN_SYMBOL, MOBILE_MAX_WIDTH_QUERY } from "../../constants";
import { toNullable } from "@dfinity/utils";
import { useAuth } from "@ic-reactor/react";
import { formatBalanceE8s } from "../../utils/conversions/token";
import DsnCoinIcon from "../icons/DsnCoinIcon";
import UserVoteRow from "./UserVoteRow";
import AdaptiveInfiniteScroll from "../AdaptiveInfinitScroll";
import { protocolActor } from "../../actors/ProtocolActor";


const UserVotes = () => {

  const { login, identity } = useAuth();

  if (identity === null || identity?.getPrincipal().isAnonymous()) {
    return <div className="flex flex-col items-center bg-slate-50 dark:bg-slate-850 py-5 rounded-md w-full text-lg hover:cursor-pointer" onClick={() => login()}>
      Log in to see your opened votes
    </div>;
  }

  const [searchParams, setSearchParams] = useSearchParams();
  const voteRefs = useRef<Map<string, (HTMLLIElement | null)>>(new Map());
  const selectedVoteId = useMemo(() => searchParams.get("voteId"), [searchParams]);
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const [votes, setVotes] = useState<SYesNoVote[]>([]);
  const [previous, setPrevious] = useState<string | undefined>(undefined);
  const [hasMore, setHasMore] = useState<boolean>(true);
  const limit = isMobile ? 10 : 16;

  const { call: fetchVotes } = backendActor.useQueryCall({
    functionName: "get_votes_by_author",
  });

  // @int
//  const { data: minedByAuthor, call: refreshMinedByAuthor } = protocolActor.useQueryCall({
//    functionName: "get_mined_by_author",
//    args: [{ author: {
//      owner: identity?.getPrincipal(),
//      subaccount: [],
//    }}]
//  });

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
        owner: identity?.getPrincipal(),
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
    //refreshMinedByAuthor(); // @int
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
      <div className="flex flex-row w-full space-x-1 justify-center items-baseline py-5">
        <span>Total mined:</span>
          {/*
            minedByAuthor !== undefined ?
            <div className="flex flex-row items-baseline space-x-1">
              <span className="text-lg">{ formatBalanceE8s(BigInt(Math.trunc(minedByAuthor.earned)), DSONANCE_COIN_SYMBOL, 2) }</span>
              <div className="flex self-center">
                <DsnCoinIcon/>
              </div>
            </div>
              :
            <span className="w-12 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse self-center"/>*/
          }
      </div>
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
