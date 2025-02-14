
import { useAuth } from "@ic-reactor/react";
import { backendActor } from "../actors/BackendActor";

import { useState, useEffect } from "react";

import { v4 as uuidv4 } from 'uuid';
import { useProtocolContext } from "./ProtocolContext";
import { useCurrencyContext } from "./CurrencyContext";
import BitcoinIcon from "./icons/BitcoinIcon";
import { useWalletContext } from "./WalletContext";
import { useNavigate } from "react-router-dom";
import { NEW_VOTE_PLACEHOLDER, VOTE_MAX_CHARACTERS } from "../constants";

interface NewVoteProps {
  category: string
}

function NewVote({ category } : NewVoteProps) {

  const INPUT_BOX_ID = "new-vote-input";

  const { authenticated, login } = useAuth({});
  
  const [text, setText] = useState("");

  const { parameters, refreshParameters } = useProtocolContext();
  const { formatSatoshis } = useCurrencyContext();
  const { refreshBtcBalance } = useWalletContext();
  const navigate = useNavigate();

  const { call: newVote, loading } = backendActor.useUpdateCall({
    functionName: 'new_vote',
    args: [{ text, vote_id: uuidv4(), category, from_subaccount: [] }],
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
    <div className="flex flex-col w-full gap-y-1 bg-slate-50 dark:bg-slate-850">
      <div id={INPUT_BOX_ID} className={`input-box break-words w-full text-sm
        ${text.length > 0 ? "text-gray-900 dark:text-white" : "text-gray-500 dark:text-gray-400"}`}
        data-placeholder={NEW_VOTE_PLACEHOLDER} contentEditable="true">
      </div>
      <div className="flex flex-row space-x-2 items-center place-self-end mx-2 mb-1">
        <button 
          className="flex flex-row button-simple w-36 min-w-36 h-9 justify-center items-center text-base"
          disabled={loading || text.length === 0 || text.length > VOTE_MAX_CHARACTERS}
          onClick={ () => { authenticated ? newVote() : login() } }
        >
          <div className="flex flex-row items-baseline space-x-1">
            <span>Open</span>
            { parameters && <span className="text-sm">{"· " + formatSatoshis(parameters.opening_vote_fee) } </span> }
            <span className="flex self-center">
              <BitcoinIcon />
            </span>
          </div>
        </button>
      </div>
    </div>
  );
}

export default NewVote;
