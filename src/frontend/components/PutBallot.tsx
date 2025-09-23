import { EYesNoChoice, toCandid } from '../utils/conversions/yesnochoice';
import { useEffect, useRef, useState } from 'react';
import { v4 as uuidv4 } from 'uuid';
import { BallotInfo } from './types';
import { useAuth } from '@nfid/identitykit/react';
import { useProtocolContext } from './context/ProtocolContext';
import PutBallotPreview from './PutBallotPreview';
import { protocolActor } from "./actors/ProtocolActor";
import { useNavigate } from 'react-router-dom';
import ResetIcon from './icons/ResetIcon';
import LoginIcon from './icons/LoginIcon';
import { SBallot } from '@/declarations/protocol/protocol.did';
import { useFungibleLedgerContext } from './context/FungibleLedgerContext';
import { getTokenLogo, getTokenSymbol } from '../utils/metadata';
import { showErrorToast, showSuccessToast, extractErrorMessage } from '../utils/toasts';

const PREDEFINED_PERCENTAGES = [0.1, 0.25, 0.5, 1.0];

type Props = {
  id: string;
  ballot: BallotInfo;
  setBallot: (ballot: BallotInfo) => void;
  ballotPreview: SBallot | undefined;
};

const PutBallot = ({id, ballot, setBallot, ballotPreview}: Props) => {

  const { supplyLedger: { formatAmount, formatAmountUsd, metadata, convertToFixedPoint, approveIfNeeded, userBalance, refreshUserBalance } } = useFungibleLedgerContext();
  const { user, connect } = useAuth();
  const authenticated = !!user;
  const { parameters } = useProtocolContext();
  const [putBallotLoading, setPutBallotLoading] = useState(false);
  const navigate = useNavigate();
  
  const { call: putBallot } = protocolActor.authenticated.useUpdateCall({
    functionName: "put_ballot",
  });

  const triggerVote = () => {
    if (!authenticated) {
      connect();
      return;
    }
    if (putBallotLoading) {
      console.warn("Put ballot is already in progress");
      return;
    }
    setPutBallotLoading(true);
    
    approveIfNeeded(ballot.amount).then(({tokenFee, approveCalled}) => {
      // Subtract the token fee from the amount if an approval was executed.
      // Second token fee is for the tranfer_from operation that will be executed by the protocol.
      const finalAmount = ballot.amount - tokenFee * (approveCalled ? 2n : 1n);
      putBallot([{
        vote_id: id,
        id: uuidv4(),
        from_subaccount: [],
        amount: finalAmount,
        choice_type: { YES_NO: toCandid(ballot.choice) },
      }]).then((result) => {
        if (result === undefined) {
          throw new Error("Put ballot returned undefined result");
        }
        if ('err' in result) {
          console.error("Put ballot failed:", result.err);
          showErrorToast(extractErrorMessage(result.err), "Put ballot");
          throw new Error(`Put ballot failed: ${result.err.toString()}`);
        }
        refreshUserBalance();
        showSuccessToast("Foresight locked successfully", "Put ballot");
        // Ballot successfully put, navigate to the ballot page
        navigate(`/?tab=your_foresights\&ballotId=${result.ok.new.YES_NO.ballot_id}`);
      });
    }).catch((error) => {
      console.error("Error during put ballot:", error);
      showErrorToast(extractErrorMessage(error), "Put ballot");
    }).finally(() => {
      setPutBallotLoading(false);
    });
  };

  useEffect(() => {
    // Only update if input is not focused, meaning that it comes from an external stimulus
    if (customRef.current && !isCustomActive) {
      let amount = formatAmount(ballot.amount, "standard");
      if (amount !== undefined) {
        customRef.current.value = amount;
      }
    }
  },
  [ballot]);

  const customRef = useRef<HTMLInputElement>(null);
  const [isCustomActive, setIsCustomActive] = useState(false);

  const [errorMsg, setErrorMsg] = useState<string | undefined>(undefined);

  useEffect(() => {
    if (parameters === undefined) {
      setErrorMsg(undefined);
      return;
    }
    const tokenSymbol = getTokenSymbol(metadata);
    const tooSmall = ballot.amount < parameters.minimum_ballot_amount;
    if (tooSmall) {
      setErrorMsg(`Minimum ${formatAmount(parameters.minimum_ballot_amount)} ${tokenSymbol}`);
    } else {
      setErrorMsg(undefined);
    }
  }
  , [ballot, parameters]);

	return (
    <div className="flex flex-col items-center w-full gap-y-2 rounded-lg shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800 p-3">
      <PutBallotPreview ballotPreview={ballotPreview} />
      <span className="w-full border-b border-gray-300 dark:border-gray-700 my-2">
        {/* Divider */}
      </span>
      <div className="flex flex-row w-full justify-between space-x-2">
        <button className={`w-1/2 h-9 text-base rounded-lg ${ballot.choice === EYesNoChoice.Yes ? "bg-brand-true text-white font-bold" : "bg-gray-100 dark:bg-gray-900 text-gray-700 dark:text-gray-300"}`} onClick={() => setBallot({ amount: ballot.amount, choice: EYesNoChoice.Yes })}>True</button>
        <button className={`w-1/2 h-9 text-base rounded-lg ${ballot.choice === EYesNoChoice.No ? "bg-brand-false text-white font-bold" : "bg-gray-100 dark:bg-gray-900 text-gray-700 dark:text-gray-300"}`} onClick={() => setBallot({ amount: ballot.amount, choice: EYesNoChoice.No })}>False</button>
      </div>
      <span className="w-full border-b border-gray-300 dark:border-gray-700 my-2">
        {/* Divider */}
      </span>
      <div className={`flex flex-col items-center w-full space-y-2`}>
        <div className="grid grid-cols-[auto_1fr_auto_auto] items-center space-x-1 w-full px-2">
          <span className="sm:pl-2">Amount</span>
          <input
            ref={customRef}
            type="text"
            onFocus={() => setIsCustomActive(true)}
            onBlur={() => setIsCustomActive(false)}
            className="w-full flex-grow h-9 rounded appearance-none bg-transparent text-right text-2xl px-1 outline-none focus:outline-none"
            onChange={(e) => {
              if (isCustomActive) {
                setBallot({
                  choice: ballot.choice,
                  amount: convertToFixedPoint(Number(e.target.value)) ?? 0n,
                });
              }
            }}
          />
          <img src={getTokenLogo(metadata)} alt="Logo" className="size-[24px]" />
          <div className="pl-2" onClick={() => setBallot({ amount: 0n, choice: ballot.choice })}>
            <div className="w-5 h-5 hover:cursor-pointer fill-black dark:fill-white">
              <ResetIcon />
            </div>
          </div>
          <span/>
          { ballot.amount > 0n &&
            <div className="text-gray-500 text-sm text-right">
              {formatAmountUsd(ballot.amount)}
            </div>
          }
        </div>
        <div className="flex flex-row items-center space-x-1 w-full">
          {
            PREDEFINED_PERCENTAGES.map((percentage) => (
              <button 
                key={percentage} 
                className={`rounded-lg h-9 text-base justify-center flex-grow ${userBalance && ballot.amount === BigInt(Math.floor(percentage * Number(userBalance))) ? "bg-purple-700 text-white font-bold" : "bg-gray-100 dark:bg-gray-900 text-gray-700 dark:text-gray-300"}`} 
                onClick={() => { if(!authenticated) { connect() } else { setBallot({ amount: BigInt(Math.floor(percentage * Number(userBalance))), choice: ballot.choice })}}}
                disabled={(userBalance !== undefined && userBalance === 0n) || putBallotLoading}
              >
                  {percentage * 100}%
              </button>
            ))
          }
        </div>
      </div>
      <button 
        className="button-simple w-full h-9 justify-center items-center text-base mt-2 flex space-x-2"
        disabled={putBallotLoading || errorMsg !== undefined || ballot.amount === 0n}
        onClick={triggerVote}
      >
        {!authenticated ? (
          <>
            <LoginIcon />
            <span>Login to lock foresight</span>
          </>
        ) : (
          <span>{ errorMsg ? errorMsg : (putBallotLoading ? "Locking foresight..." : "Lock foresight") }</span>
        )}
      </button>
    </div>
    
	);
};

export default PutBallot;