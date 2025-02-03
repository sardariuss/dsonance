
import { SYesNoVote } from "../../declarations/backend/backend.did";
import { backendActor } from "../actors/BackendActor";
import { useAuth } from "@ic-reactor/react";
import VoteView from "./VoteView";
import { useEffect, useMemo, useRef, useState } from "react";
import NewVote from "./NewVote";
import { TabButton } from "./TabButton";
import { toNullable } from "@dfinity/utils";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../constants";
import { useSearchParams } from "react-router-dom";

function VoteList() {

  const { authenticated } = useAuth();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const [searchParams, setSearchParams] = useSearchParams();
  const voteRefs = useRef<Map<string, (HTMLLIElement | null)>>(new Map());
  const selectedVoteId = useMemo(() => searchParams.get("voteId"), [searchParams]);
  const selectedCategory = useMemo(() => searchParams.get("category"), [searchParams]);

  // Somehow a useState is required otherwise the votes require two fetches to show up
  const [votes, setVotes] = useState<SYesNoVote[] | undefined>(undefined);

  const selectCategory = (category: string | undefined) => {
    setSearchParams(category ? { category: category } : {});
  }

  const selectVote = (voteId: string | null) => {
    // Do not remove the selected category when selecting a vote
    setSearchParams(oldParams => {
      const newParams = new URLSearchParams(oldParams);
      if (voteId) {
        newParams.set("voteId", voteId);
      } else {
        newParams.delete("voteId");
      }
      return newParams;
    });
  }

  const { call: fetchVotes } = backendActor.useQueryCall({
    functionName: 'get_votes',
  });

  const { data: categories } = backendActor.useQueryCall({
    functionName: 'get_categories',
  });

  const refreshVotes = () => {
    fetchVotes([{ category: toNullable(selectedCategory) }]).then(setVotes);
  }

  useEffect(() => {
    refreshVotes();
  }
  , [selectedCategory]);

  useEffect(() => {
    if (votes && selectedVoteId !== null) {
      const voteElement = voteRefs.current.get(selectedVoteId);
      
      if (voteElement) {
        setTimeout(() => {
          voteElement.scrollIntoView({
            behavior: "smooth",
            block: "start",
          });
        }, 50);
      }
    }
  }, [votes]);

  return (
    <div className="flex flex-col border-x dark:border-gray-700 w-full sm:w-4/5 md:w-3/4 lg:w-2/3">
      <ul className="flex flex-wrap text-sm text-gray-800 dark:text-gray-200 font-medium text-center w-full">
        <li key={0} className={`border-b dark:border-gray-700 grow`}>
          <TabButton label={"All"} isCurrent={selectedCategory === undefined} setIsCurrent={() => { selectCategory(undefined); }}/>
        </li>
        {
          categories && categories.map((cat, index) => (
            <li key={index + 1} className={`border-b dark:border-gray-700 border-l grow`}>
              {/* TODO: remove this hack which only shows the emoji on mobile */}
              <TabButton label={(cat === selectedCategory || !isMobile) ? cat : cat.split(" ")[0]} isCurrent={cat === selectedCategory} setIsCurrent={() => { selectCategory(cat); }}/>
            </li>
          ))
        }
      </ul>
      {
        selectedCategory && <div className="w-full" onClick={() => selectVote(null)}>
          <NewVote category={selectedCategory}/>
        </div>
      }
      <ul>
        {
          votes && votes.map((vote: SYesNoVote, index) => (
            vote.info.visible && <li key={index} ref={(el) => (voteRefs.current.set(vote.vote_id, el))} className="w-full scroll-mt-[104px] sm:scroll-mt-[88px]">
              <VoteView 
                selected={selectedVoteId === vote.vote_id}
                setSelected={() => selectVote(selectedVoteId === vote.vote_id ? null : vote.vote_id)}
                vote={vote}
                refreshVotes={refreshVotes}
              />
            </li>
          ))
        }
      </ul>
    </div>
  );
}

export default VoteList;
