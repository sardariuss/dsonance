import { SYesNoVote } from "../../declarations/backend/backend.did";
import { backendActor } from "../actors/BackendActor";
import { useEffect, useMemo, useRef, useState } from "react";
import { useSearchParams } from "react-router-dom";
import VoteItem from "./VoteItem";
import BitcoinIcon from "./icons/BitcoinIcon";

const VoteList = () => {

  const [searchParams, setSearchParams] = useSearchParams();
  const voteRefs = useRef<Map<string, (HTMLTableRowElement | null)>>(new Map());
  const selectedVoteId = useMemo(() => searchParams.get("voteId"), [searchParams]);
  
  // Store selected categories as an array
  const selectedCategories = useMemo(() => {
    const categories = searchParams.get("categories");
    return categories ? categories.split(",") : [];
  }, [searchParams]);

  const [votes, setVotes] = useState<SYesNoVote[]>([]);
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const [checkedCategories, setCheckedCategories] = useState<string[]>(selectedCategories);

  const { call: fetchVotes } = backendActor.useQueryCall({
    functionName: "get_votes",
  });

  const { data: categories } = backendActor.useQueryCall({
    functionName: "get_categories",
  });

  useEffect(() => {
    const fetchAndSetVotes = async () => {
      const fetchedVotes = await fetchVotes([{ categories: checkedCategories.length ? [checkedCategories] : [] }]);
      setVotes(fetchedVotes ?? []);
    };
    fetchAndSetVotes();
  }, [checkedCategories]);

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

  // Handle category selection
  const toggleCategory = (category: string) => {
    setCheckedCategories((prev) =>
      prev.includes(category) ? prev.filter((c) => c !== category) : [...prev, category]
    );
  };

  return (
    <div className="flex flex-col gap-y-1 w-full bg-slate-50 dark:bg-slate-850 rounded-md">
      {/* Dropdown Button */}
      <div className="relative p-2">
        <button
          onClick={() => setDropdownOpen(!dropdownOpen)}
          className="bg-gray-200 dark:bg-gray-700 px-4 py-2 rounded-md"
        >
          Filter Categories
        </button>

        {dropdownOpen && (
          <div className="absolute mt-2 bg-white dark:bg-gray-800 shadow-md rounded-md p-3 w-48">
            <ul>
              {categories &&
                categories.map((cat, index) => (
                  <li key={index} className="flex items-center gap-2 p-1">
                    <input
                      type="checkbox"
                      checked={checkedCategories.includes(cat)}
                      onChange={() => toggleCategory(cat)}
                    />
                    <span>{cat}</span>
                  </li>
                ))}
            </ul>
          </div>
        )}
      </div>

      {/* Vote List */}
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
        <tbody>
          {votes.map((vote: SYesNoVote, index) => (
            vote.info.visible && 
              <VoteItem
                vote={vote}
                index={index}
                setRef={(el) => voteRefs.current.set(vote.vote_id, el)}
              />
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default VoteList;
