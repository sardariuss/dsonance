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
  ballotPreviewWithoutImpact?: SBallot | undefined;
};

const PutBallot = ({id, ballot, setBallot, ballotPreview, ballotPreviewWithoutImpact}: Props) => {

  const { supplyLedger: { formatAmount, formatAmountUsd, metadata, convertToFixedPoint, approveIfNeeded, userBalance, refreshUserBalance } } = useFungibleLedgerContext();
  const { user, connect } = useAuth();
  const authenticated = !!user;
  const { parameters } = useProtocolContext();
  const [putBallotLoading, setPutBallotLoading] = useState(false);
  const [selectedPredefined, setSelectedPredefined] = useState<number | null>(null);
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
    <div className="flex flex-col items-center w-full gap-y-2 rounded-lg shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800 p-4">
      <div className="flex flex-row w-full justify-between space-x-2">
        <button className={`w-1/2 h-10 text-lg rounded-lg ${ballot.choice === EYesNoChoice.Yes ? "bg-brand-true dark:bg-brand-true-dark text-white font-bold" : "bg-gray-100 dark:bg-gray-900 text-gray-700 dark:text-gray-300"}`} onClick={() => setBallot({ amount: ballot.amount, choice: EYesNoChoice.Yes })}>True</button>
        <button className={`w-1/2 h-10 text-lg rounded-lg ${ballot.choice === EYesNoChoice.No ? "bg-brand-false text-white font-bold" : "bg-gray-100 dark:bg-gray-900 text-gray-700 dark:text-gray-300"}`} onClick={() => setBallot({ amount: ballot.amount, choice: EYesNoChoice.No })}>False</button>
      </div>
      <div className={`flex flex-col items-center w-full space-y-2`}>
        <div className="grid grid-cols-[auto_1fr_auto_auto] items-center space-x-1 w-full">
          <span className="">Amount</span>
          <input
            ref={customRef}
            type="text"
            onFocus={() => setIsCustomActive(true)}
            onBlur={() => setIsCustomActive(false)}
            className="w-full flex-grow h-9 rounded appearance-none bg-transparent text-right text-3xl px-1 outline-none focus:outline-none"
            onChange={(e) => {
              if (isCustomActive) {
                setBallot({
                  choice: ballot.choice,
                  amount: convertToFixedPoint(Number(e.target.value)) ?? 0n,
                });
                setSelectedPredefined(null);
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
          <div className="text-gray-500 text-sm text-right">
            {formatAmountUsd(ballot.amount)}
          </div>
        </div>
        <div className="flex flex-row items-center self-end space-x-1 w-3/4">
          {
            PREDEFINED_PERCENTAGES.map((percentage, index) => (
              <button 
                key={percentage} 
                className={`rounded-lg h-8 text-base justify-center flex-grow ${selectedPredefined === index ? "bg-blue-700 text-white font-bold" : "bg-gray-100 dark:bg-gray-900 text-gray-700 dark:text-gray-300"}`} 
                onClick={() => { if(!authenticated) { connect() } else { setBallot({ amount: BigInt(Math.floor(percentage * Number(userBalance))), choice: ballot.choice }), setSelectedPredefined(index); }}}
                disabled={putBallotLoading}
              >
                {percentage * 100}%
              </button>
            ))
          }
        </div>
      </div>
      <span className="w-full border-b border-gray-300 dark:border-gray-700">
        {/* Divider */}
      </span>
      {ballotPreview && (
        <div className="animate-in slide-in-from-top-4 fade-in-0 duration-300 w-full">
          <PutBallotPreview
            ballotPreview={ballotPreview}
            ballotPreviewWithoutImpact={ballotPreviewWithoutImpact}
          />
        </div>
      )}
      <button 
        className="button-simple w-full h-9 justify-center items-center text-base mt-2 flex space-x-2"
        disabled={authenticated && (putBallotLoading || errorMsg !== undefined || ballot.amount === 0n)}
        onClick={() => { if (!authenticated) { connect() } else { triggerVote() } }}
      >
        <span>{ putBallotLoading ? "Locking foresight..." : "Lock foresight" }</span>
      </button>
    </div>
    
	);
};

export default PutBallot;