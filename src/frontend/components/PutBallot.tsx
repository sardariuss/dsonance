import { protocolActor } from "../actors/ProtocolActor";
import { EYesNoChoice, toCandid } from "../utils/conversions/yesnochoice";
import { useEffect, useRef, useState } from "react";
import { BallotInfo } from "./types";
import ResetIcon from "./icons/ResetIcon";
import { v4 as uuidv4 } from 'uuid';
import { useCurrencyContext } from "./CurrencyContext";
import BitcoinIcon from "./icons/BitcoinIcon";
import { useWalletContext } from "./WalletContext";

interface PutBallotProps {
  vote_id: string;
  refreshVotes?: () => void;
  ballot: BallotInfo;
  setBallot: (ballot: BallotInfo) => void;
  resetVote: () => void;
}

const PutBallot: React.FC<PutBallotProps> = ({ vote_id, refreshVotes, ballot, setBallot, resetVote }) => {

  const { formatSatoshis, currencySymbol, currencyToSatoshis, satoshisToCurrency } = useCurrencyContext();

  const { refreshBtcBalance } = useWalletContext();

  const { call: putBallot, loading } = protocolActor.useUpdateCall({
    functionName: "put_ballot",
    onSuccess: () => {
      if (refreshVotes){
        refreshVotes();
      };
      refreshBtcBalance();
    },
    onError: (error) => {
      console.error(error);
    },
  });

  const { data: protocolParameters } = protocolActor.useQueryCall({
    functionName: "get_protocol_parameters",
    args: [],
  });

  const triggerVote = () => {
    putBallot([{
      vote_id,
      ballot_id: uuidv4(),
      from_subaccount: [],
      amount: ballot.amount,
      choice_type: { YES_NO: toCandid(ballot.choice) },
    }]);
  };

  const isTooSmall = () : boolean => {
    if (!protocolParameters) {
      return false;
    }
    return ballot.amount < protocolParameters.minimum_ballot_amount;
  }

  const inputRef = useRef<HTMLInputElement>(null);
  const [isActive, setIsActive] = useState(false);

  useEffect(() => {
    if (inputRef.current && !isActive) { // Only update if input is not focused, meaning that it comes from an external stimulus
      let amount = satoshisToCurrency(ballot.amount);
      if (amount !== undefined) {
        inputRef.current.value = amount.toString();
      }
    }
  },
  [ballot]);

  return (
    <div className="flex flex-col w-full items-center space-x-4 justify-center">
      <div className="flex flex-row w-full items-center space-x-4 justify-center">
        <div className="w-6 h-6 dark:hover:fill-white dark:fill-gray-200 fill-slate-700 hover:fill-slate-900" onClick={resetVote}>
          <ResetIcon />
        </div>
        <div className="flex items-center space-x-1">
          <span>{currencySymbol}</span>
          <input
            ref={inputRef}
            type="text"
            onFocus={() => setIsActive(true)}
            onBlur={() => setIsActive(false)}
            className="w-32 h-9 border dark:border-gray-300 border-gray-900 rounded px-2 appearance-none focus:outline outline-1 outline-purple-500 bg-gray-100 dark:bg-gray-900"
            onChange={(e) => { if(isActive) { setBallot({ choice: ballot.choice, amount: currencyToSatoshis(Number(e.target.value)) ?? 0n }) }} }
          />
          <BitcoinIcon />
        </div>
        <div>on</div>
        <div>
          <select
            className={`w-20 h-9 appearance-none bg-gray-100 dark:bg-gray-900 border dark:border-gray-300 border-gray-900 rounded px-2 focus:outline outline-1 outline-purple-500 ${ballot.choice === EYesNoChoice.Yes ? "text-brand-true" : "text-brand-false"}`}
            value={ballot.choice}
            onChange={(e) => setBallot({ choice: e.target.value as EYesNoChoice, amount: ballot.amount })}
            disabled={loading}
          >
            <option className="text-brand-true" value={EYesNoChoice.Yes}>{EYesNoChoice.Yes}</option>
            <option className="text-brand-false" value={EYesNoChoice.No}>{EYesNoChoice.No}</option>
          </select>
        </div>
        <button
          className="button-simple w-36 min-w-36 h-9 justify-center items-center text-base"
          disabled={loading || isTooSmall()}
          onClick={triggerVote}
        >
          Lock ballot
        </button>
      </div>
      { protocolParameters && 
        <div className={`${isTooSmall() ? "text-red-500" : "text-gray-500"} text-sm`}>
          Minimum {formatSatoshis(protocolParameters?.minimum_ballot_amount)}
        </div>
      }
    </div>
  );
};

export default PutBallot;
