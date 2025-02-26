import { SYesNoVote } from "../../declarations/backend/backend.did";
import { backendActor } from "../actors/BackendActor";
import { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import BitcoinIcon from "./icons/BitcoinIcon";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../constants";
import VoteRow from "./VoteRow";
import { useProtocolContext } from "./ProtocolContext";
import { compute_vote_details } from "../utils/conversions/votedetails";

const VoteList = () => {

  const [searchParams, setSearchParams] = useSearchParams();
  const voteRefs = useRef<Map<string, (HTMLLIElement | null)>>(new Map());
  const selectedVoteId = useMemo(() => searchParams.get("voteId"), [searchParams]);
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const [votes, setVotes] = useState<SYesNoVote[]>([]);
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const [checkedCategories, setCheckedCategories] = useState<string[]>([]);
  const { computeDecay } = useProtocolContext();
  const navigate = useNavigate();

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
      {/* Vote List */}
      <div className="grid grid-cols-[1fr_60px] sm:grid-cols-[100px_1fr_100px_100px] gap-x-2 sm:gap-x-4 grow py-5 pr-3 sm:pr-5">
        { !isMobile && <div className="text-center text-gray-600 dark:text-gray-400 font-light relative" onClick={() => setDropdownOpen(!dropdownOpen)}>
          Category
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
        </div>}
        <div className={`justify-self-start text-gray-600 dark:text-gray-400 font-light ${isMobile ? "pl-3" : ""}`}>Statement</div>
        { !isMobile && <div className="justify-self-end text-gray-600 dark:text-gray-400 font-light flex flex-row items-center space-x-1">
          <BitcoinIcon />
          <span>TVL</span>
        </div>}
        <div className="justify-self-end text-gray-600 dark:text-gray-400 font-light">Consensus</div>
      </div>
      <ul className="w-full flex flex-col">
        {votes.map((vote: SYesNoVote, index) => (
          computeDecay && vote.info.visible && 
            <li key={index} ref={(el) => (voteRefs.current.set(vote.vote_id, el))} className="flex w-full scroll-mt-[104px] sm:scroll-mt-[88px] border-t border-slate-100 dark:border-slate-900">
              <div 
                className={`flex flex-row items-baseline w-full bg-slate-50 dark:bg-slate-850 hover:cursor-pointer py-1`}
                onClick={() => { setSearchParams({voteId: vote.vote_id}); navigate(`/vote/${vote.vote_id}`)} }
              >
                <VoteRow category={vote.info.category} voteDetails={compute_vote_details(vote, computeDecay)} text={vote.info.text}/>
              </div>
            </li>
        ))}
      </ul>
    </div>
  );
};

export default VoteList;
