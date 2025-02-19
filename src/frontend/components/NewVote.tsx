
import { useAuth } from "@ic-reactor/react";
import { backendActor } from "../actors/BackendActor";

import { useState, useEffect } from "react";

import { v4 as uuidv4 } from 'uuid';
import { useProtocolContext } from "./ProtocolContext";
import { useCurrencyContext } from "./CurrencyContext";
import BitcoinIcon from "./icons/BitcoinIcon";
import { useWalletContext } from "./WalletContext";
import { Link, useNavigate } from "react-router-dom";
import { DOCS_URL, NEW_VOTE_PLACEHOLDER, VOTE_MAX_CHARACTERS } from "../constants";
import CategorySelector from "./CategorySelector";

function NewVote() {

  const INPUT_BOX_ID = "new-vote-input";

  const { authenticated, login } = useAuth({});
  
  const [text, setText] = useState("");
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);

  const { parameters, refreshParameters } = useProtocolContext();
  const { formatSatoshis } = useCurrencyContext();
  const { refreshBtcBalance } = useWalletContext();
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
      refreshBtcBalance();
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
      newVote( [{ text, vote_id: uuidv4(), category: selectedCategory, from_subaccount: [] }]);
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
    <div className="flex flex-col gap-6 bg-slate-50 dark:bg-slate-850 p-6 my-6 rounded-lg shadow-md w-full sm:w-4/5 md:w-3/4 lg:w-2/3">

      {/* Guidelines Section */}
      <div className="bg-slate-100 dark:bg-slate-900 p-4 rounded-md text-gray-700 dark:text-gray-300">
        <ul className="mt-2 text-sm leading-relaxed">
          <li>✅ Be precise and measurable.</li>
          <li>✅ Ensure your statement is time-bound.</li>
          <li>❌ Avoid absolute moral or ideological claims.</li>
          <li>❌ No personal or defamatory statements.</li>
        </ul>
        <Link to={DOCS_URL} className="text-blue-600 dark:text-blue-400 mt-2 inline-block text-sm hover:underline">
          Read the full guidelines →
        </Link>
      </div>

      {/* Statement Input Box */}
      <div 
        id={INPUT_BOX_ID} 
        className={`input-box break-words w-full text-sm p-3 rounded-lg border transition-all duration-200 bg-slate-100 dark:bg-slate-900 border-gray-300 dark:border-slate-700 focus:ring-2 focus:ring-blue-500
          ${text.length > 0 ? "text-gray-900 dark:text-white" : "text-gray-500 dark:text-gray-400"}`}
        data-placeholder={NEW_VOTE_PLACEHOLDER}
        contentEditable="true"
      >
      </div>

      {/* Category Selector + Button Layout */}
      <div className="flex flex-col sm:flex-row justify-end w-full items-center gap-4">
        {/* Category Selector */}
        <CategorySelector selectedCategory={selectedCategory} setSelectedCategory={setSelectedCategory} />

        {/* Open Statement Button */}
        <button className={`button-simple text-lg`} 
                onClick={openVote}
                disabled={loading || text.length === 0 || text.length > VOTE_MAX_CHARACTERS || selectedCategory === null}>
          Open Statement
        </button>
      </div>
    </div>
  );
}

export default NewVote;
