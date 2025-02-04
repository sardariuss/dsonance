import { protocolActor } from "../actors/ProtocolActor";
import { EYesNoChoice, toCandid } from "../utils/conversions/yesnochoice";
import { useEffect, useRef, useState } from "react";
import { BallotInfo } from "./types";
import ResetIcon from "./icons/ResetIcon";
import { v4 as uuidv4 } from 'uuid';
import { useCurrencyContext } from "./CurrencyContext";
import BitcoinIcon from "./icons/BitcoinIcon";
import { useWalletContext } from "./WalletContext";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../constants";
import { useNavigate } from "react-router-dom";
import { useAuth } from "@ic-reactor/react";
import { useProtocolContext } from "./ProtocolContext";

interface PutBallotProps {
  vote_id: string;
  refreshVotes?: () => void;
  ballot: BallotInfo;
  setBallot: (ballot: BallotInfo) => void;
  resetVote: () => void;
}

const PutBallot: React.FC<PutBallotProps> = ({ vote_id, refreshVotes, ballot, setBallot, resetVote }) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const navigate = useNavigate();
  const { authenticated, identity, login } = useAuth({});

  const { formatSatoshis, currencySymbol, currencyToSatoshis, satoshisToCurrency } = useCurrencyContext();

  const { refreshBtcBalance } = useWalletContext();

  const { call: putBallot, loading } = protocolActor.useUpdateCall({
    functionName: "put_ballot",
    onSuccess: (result) => {
      if (result === undefined) {
        return;
      }
      if ('err' in result) {
        console.error(result.err);
        return;
      }
      if (identity !== null) {
        refreshBtcBalance();
        navigate(`/user/${identity.getPrincipal()}?ballotId=${result.ok.YES_NO.ballot_id}`);
      }
    },
    onError: (error) => {
      console.error(error);
    },
  });

  const { parameters } = useProtocolContext();

  const triggerVote = () => {
    if (!authenticated) {
      login();
      return;
    }
    putBallot([{
      vote_id,
      ballot_id: uuidv4(),
      from_subaccount: [],
      amount: ballot.amount,
      choice_type: { YES_NO: toCandid(ballot.choice) },
    }]);
  };

  const [tooSmall, setTooSmall] = useState(false);

  useEffect(() => {
    setTooSmall(parameters ? ballot.amount < parameters.minimum_ballot_amount : false);
  }
  , [ballot, parameters]);

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

  return isMobile ? (
    <div className="flex flex-col w-full items-center justify-center">
      <div className="flex flex-row w-full items-center space-x-4 justify-center">
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
      </div>

      <div className="grid grid-cols-6 items-center gap-x-2 justify-center mt-2">
        <div
          className="flex w-6 h-6 dark:hover:fill-white dark:fill-gray-200 fill-slate-700 hover:fill-slate-900 items-center justify-center"
          onClick={resetVote}
        >
          <ResetIcon />
        </div>
        <button
            className="button-simple w-36 min-w-36 h-9 justify-center items-center text-base col-span-4"
            disabled={loading || tooSmall}
            onClick={triggerVote}
        >
          Lock ballot
        </button>
        <span>{/*spacer*/}</span>
        <span>{/*spacer*/}</span>
        {parameters && tooSmall && (
          <div className="text-sm text-red-500 truncate col-span-4 text-center">
            Minimum {formatSatoshis(parameters.minimum_ballot_amount)}
          </div>
        )}
      </div>
    </div>
    ) : (
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
            style={{ textShadow: "0.2px 0.2px 1px rgba(0, 0, 0, 0.4)" }}
            onChange={(e) => setBallot({ choice: e.target.value as EYesNoChoice, amount: ballot.amount })}
            disabled={loading}
          >
            <option className="text-brand-true" value={EYesNoChoice.Yes}>{EYesNoChoice.Yes}</option>
            <option className="text-brand-false" value={EYesNoChoice.No}>{EYesNoChoice.No}</option>
          </select>
        </div>
        <button
          className="button-simple w-36 min-w-36 h-9 justify-center items-center text-base"
          disabled={loading || tooSmall}
          onClick={triggerVote}
        >
          Lock ballot
        </button>
      </div>
      { parameters && 
        <div className={`${tooSmall ? "text-red-500" : "text-gray-500"} text-sm`}>
          Minimum {formatSatoshis(parameters.minimum_ballot_amount)}
        </div>
      }
    </div>
  );
};

export default PutBallot;
