
import { SYesNoVote } from "../../declarations/backend/backend.did";
import { backendActor } from "../actors/BackendActor";
import { useEffect, useMemo, useRef, useState } from "react";
import { MainTabButton } from "./MainTabButton";
import { toNullable } from "@dfinity/utils";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../constants";
import { useSearchParams } from "react-router-dom";
import VoteItem from "./VoteItem";
import BitcoinIcon from "./icons/BitcoinIcon";

const VoteList = () => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const [searchParams, setSearchParams] = useSearchParams();
  const voteRefs = useRef<Map<string, (HTMLTableRowElement | null)>>(new Map());
  const selectedVoteId = useMemo(() => searchParams.get("voteId"), [searchParams]);
  const selectedCategory = useMemo(() => searchParams.get("category"), [searchParams]);

  // Somehow a useState is required otherwise the votes require two fetches to show up
  const [votes, setVotes] = useState<SYesNoVote[]>([]);

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

  useEffect(() => {
    const fetchAndSetVotes = async () => {
      const fetchedVotes = await fetchVotes([{ category: toNullable(selectedCategory) }]);
      setVotes(fetchedVotes ?? []);
    };
    fetchAndSetVotes();
  }, [selectedCategory]);

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
    <div className="flex flex-col gap-y-1 w-full bg-slate-50 dark:bg-slate-850 rounded-md">
      <ul className="flex flex-wrap text-sm text-gray-800 dark:text-gray-200 font-medium text-center w-full gap-x-1 px-2 pt-2">
        { categories && <li key={0} className={`grow`}>
          <MainTabButton label={"All"} isCurrent={selectedCategory === undefined} setIsCurrent={() => { selectCategory(undefined); }}/>
        </li>
        }
        {
          categories && categories.map((cat, index) => (
            <li key={index + 1} className={`grow`}>
              {/* TODO: remove this hack which only shows the emoji on mobile */}
              <MainTabButton label={(cat === selectedCategory || !isMobile) ? cat : cat.split(" ")[0]} isCurrent={cat === selectedCategory} setIsCurrent={() => { selectCategory(cat); }}/>
            </li>
          ))
        }
      </ul>
      <table className="w-full px-10">
        <thead className="w-full">
          <tr className="w-full px-6">
            <th scope="col" className="text-left text-gray-600 dark:text-slate-850 font-light pl-6 py-5">#</th>
            <th scope="col" className="text-left text-gray-600 dark:text-gray-400 font-light px-3 py-5">Statement</th>
            <th scope="col" className="text-right text-gray-600 dark:text-gray-400 font-light px-3 py-5 flex flex-row items-center justify-self-center space-x-1">
              <BitcoinIcon />
              <span>TVL</span>
            </th>
            <th scope="col" className="text-right text-gray-600 dark:text-gray-400 font-light pl-3 pr-6 py-5">Consensus</th>
          </tr>
        </thead>
        <tbody className="">
        {
          votes.map((vote: SYesNoVote, index) => (
            vote.info.visible && 
              <VoteItem
                vote={vote}
                index={index}
                setRef={(el) => (voteRefs.current.set(vote.vote_id, el))}
              />
          ))
        }
        </tbody>
      </table>
    </div>
  );
}

export default VoteList;
