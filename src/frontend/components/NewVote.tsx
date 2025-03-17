
import { useAuth } from "@ic-reactor/react";
import { backendActor } from "../actors/BackendActor";

import { useState, useEffect } from "react";

import { v4 as uuidv4 } from 'uuid';
import { useProtocolContext } from "./ProtocolContext";
import { useCurrencyContext } from "./CurrencyContext";
import { useAllowanceContext } from "./AllowanceContext";
import { Link, useNavigate } from "react-router-dom";
import { DOCS_URL, DSONANCE_COIN_SYMBOL, NEW_VOTE_PLACEHOLDER, VOTE_MAX_CHARACTERS } from "../constants";
import CategorySelector from "./CategorySelector";
import { formatBalanceE8s } from "../utils/conversions/token";
import BackArrowIcon from "./icons/BackArrowIcon";

function NewVote() {

  const INPUT_BOX_ID = "new-vote-input";

  const { authenticated, login } = useAuth({});
  
  const [text, setText] = useState("");
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);

  const { parameters, refreshParameters } = useProtocolContext();
  const { formatSatoshis } = useCurrencyContext();
  const { refreshBtcAllowance } = useAllowanceContext();
  const navigate = useNavigate();

  const { call: newVote, loading } = backendActor.useUpdateCall({
    functionName: 'new_vote',
    onSuccess: (result) => {
      if (result === undefined) {
        return;
      }
      if ('err' in result) {
        console.error(result.err);
        return;
      }
      refreshBtcAllowance();
      navigate(`/vote/${result.ok.vote_id}`);
      
    },
    onError: (error) => {
      console.error(error);
    }
  });

  const openVote = () => {
    if (authenticated) {
      if (selectedCategory === null) {
        throw new Error("Category not selected");
      };
      newVote( [{ text, id: uuidv4(), category: selectedCategory, from_subaccount: [] }]);
    } else {
      login();
    }
  }

  useEffect(() => {

    refreshParameters();
    
    let proposeVoteInput = document.getElementById(INPUT_BOX_ID);

    const listener = function (this: HTMLElement, _ : Event) {
      setText(this.textContent ?? "");
      // see https://stackoverflow.com/a/73813273
      if (this.innerText.length === 1 && this.children.length === 1){
        this.firstChild?.remove();
      }      
    };
    
    proposeVoteInput?.addEventListener('input', listener);
    
    return () => {
      proposeVoteInput?.removeEventListener('input', listener);
    }
  }, []);

  return (
    <div className="flex flex-col gap-6 bg-slate-50 dark:bg-slate-850 p-6 sm:my-6 sm:rounded-md shadow-md w-full sm:w-4/5 md:w-3/4 lg:w-2/3 h-full sm:h-auto justify-between">

      <div className="w-full grid grid-cols-3 space-x-1 mb-3 items-center">
        <div className="hover:cursor-pointer justify-self-start" onClick={() => navigate(-1)}>
          <BackArrowIcon/>
        </div>
        <span className="text-xl font-semibold items-baseline justify-self-center truncate">Open new vote</span>
        <span className="grow">{/* spacer */}</span>
      </div>

      <div className="flex flex-col gap-y-2">
        <div className="bg-slate-200 dark:bg-gray-800 p-4 rounded-md">
          <ul className="mt-2 text-md leading-relaxed">
            <li>✅ Be precise and measurable.</li>
            <li>✅ Ensure your statement is time-bound.</li>
            <li>❌ Avoid absolute moral or ideological claims.</li>
            <li>❌ No personal or defamatory statements.</li>
          </ul>
          <Link to={DOCS_URL} className="text-blue-500 mt-2 inline-block text-md hover:underline" target="_blank" rel="noopener">
            Read the full guidelines →
          </Link>
        </div>
        <div 
          id={INPUT_BOX_ID} 
          className={`input-box break-words min-h-24 w-full text-sm p-3 rounded-lg border transition-all duration-200 bg-slate-200 dark:bg-gray-800 border-gray-300 dark:border-slate-700 focus:ring-2 focus:ring-purple-500
            ${text.length > 0 ? "text-gray-900 dark:text-white" : "text-gray-500 dark:text-gray-400"}`}
          data-placeholder={NEW_VOTE_PLACEHOLDER}
          contentEditable="true"
        />
      </div>

      <span className="grow">{/* spacer */}</span>

      {/* Category Selector + Button Layout */}
      <div className="flex flex-col sm:flex-row w-full items-end sm:items-center gap-4 justify-between">
        <div className="flex flex-row gap-x-2 items-center">
          <span className="text-sm text-gray-600 dark:text-gray-400">Category:</span>
          <CategorySelector selectedCategory={selectedCategory} setSelectedCategory={setSelectedCategory} />
        </div>
        
        <div className="flex flex-row gap-x-2 items-center justify-end">
          <div className="flex flex-row gap-x-2">
            <span className="text-sm text-gray-600 dark:text-gray-400">Fee:</span>
            {formatBalanceE8s(5_000_000_000n, DSONANCE_COIN_SYMBOL, 2)}
          </div>
          <button className={`button-simple text-lg`} 
                  onClick={openVote}
                  disabled={loading || text.length === 0 || text.length > VOTE_MAX_CHARACTERS || selectedCategory === null}>
            Open new vote
          </button>
        </div>
      </div>
    </div>
  );
}

export default NewVote;
