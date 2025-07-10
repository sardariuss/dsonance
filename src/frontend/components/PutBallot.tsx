import { EYesNoChoice, toCandid } from '../utils/conversions/yesnochoice';
import { useEffect, useRef, useState } from 'react';
import { v4 as uuidv4 } from 'uuid';
import { BallotInfo } from './types';
import { useAuth } from '@ic-reactor/react';
import { add_ballot, deduce_ballot, VoteDetails } from '../utils/conversions/votedetails';
import { useProtocolContext } from './context/ProtocolContext';
import PutBallotPreview from './PutBallotPreview';
import { protocolActor } from '../actors/ProtocolActor';
import { useNavigate } from 'react-router-dom';
import ResetIcon from './icons/ResetIcon';
import { SBallot } from '@/declarations/protocol/protocol.did';
import { useFungibleLedgerContext } from './context/FungibleLedgerContext';
import { getTokenLogo } from '../utils/metadata';

const CURSOR_HEIGHT = "0.3rem";
const PREDEFINED_PERCENTAGES = [0.1, 0.25, 0.5, 1.0];
// Avoid 0 division, arbitrary use 0.001 and 0.999 values instead of 0 and 1
const MIN_CURSOR = 0.001;
const MAX_CURSOR = 0.999;
const clampCursor = (cursor: number) => {
  return Math.min(Math.max(cursor, MIN_CURSOR), MAX_CURSOR);
}

type Props = {
  id: string;
  disabled: boolean;
  voteDetails: VoteDetails;
  ballot: BallotInfo;
  setBallot: (ballot: BallotInfo) => void;
  ballotPreview: SBallot | undefined;
  onMouseUp: () => (void);
  onMouseDown: () => (void);
};

const PutBallot = ({id, disabled, voteDetails, ballot, setBallot, ballotPreview, onMouseUp, onMouseDown}: Props) => {

  const { supplyLedger: { formatAmount, formatAmountUsd, metadata, convertToFixedPoint, approveIfNeeded, userBalance, refreshUserBalance } } = useFungibleLedgerContext();
  const { authenticated, login } = useAuth();
  const { parameters } = useProtocolContext();
  const [putBallotLoading, setPutBallotLoading] = useState(false);
  const navigate = useNavigate();
  
  const { call: putBallot } = protocolActor.useUpdateCall({
    functionName: "put_ballot",
  });

  const triggerVote = () => {
    if (!authenticated) {
      login();
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
          throw new Error(`Put ballot failed: ${result.err.toString()}`);
        }
        refreshUserBalance();
        // Ballot successfully put, navigate to the ballot page
        navigate(`/?tab=your_ballots\&ballotId=${result.ok.new.YES_NO.ballot_id}`);
      });
    }).catch((error) => {
      console.error("Error during put ballot:", error);
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
    if (sliderRef.current && !isSliderActive) {
      const liveDetails = add_ballot(voteDetails, ballot);
      setCursor(liveDetails.cursor);
      if (liveDetails.cursor !== undefined) {
        sliderRef.current.value = liveDetails.cursor.toString();
      }
    }
  },
  [ballot]);

  const customRef = useRef<HTMLInputElement>(null);
  const sliderRef = useRef<HTMLInputElement>(null);
  const [isCustomActive, setIsCustomActive] = useState(false);
  const [isSliderActive, setIsSliderActive] = useState(false);

  const initCursor = voteDetails.cursor;

  const [cursor, setCursor] = useState(initCursor);

  const updateBallot = (value: number) => {
    value = clampCursor(value);
    setCursor(value);
    setBallot(deduce_ballot(voteDetails, value));
  };

  const [tooSmall, setTooSmall] = useState(false);

  useEffect(() => {
    setTooSmall(parameters ? ballot.amount < parameters.minimum_ballot_amount : false);
  }
  , [ballot, parameters]);

	return (
    <div className="flex flex-col items-center w-full gap-y-2">
      { cursor === undefined ? <div className="pt-2"></div> : 
        <div id={"cursor_" + id} className="w-full flex flex-col items-center my-2 sm:my-1" style={{ position: 'relative' }}>
          <div className="flex w-full rounded-sm z-0" style={{ height: CURSOR_HEIGHT, position: 'relative' }}>  
            { cursor > MIN_CURSOR && <div className={`bg-brand-true h-full rounded-l ${ballot.choice === EYesNoChoice.Yes ? "" : "opacity-70"}`}  style={{ width: `${cursor * 100 + "%"       }`}}/> }
            { cursor < MAX_CURSOR && <div className={`bg-brand-false h-full rounded-r ${ballot.choice === EYesNoChoice.No ? "" : "opacity-70"}`} style={{ width: `${( 1 - cursor) * 100 + "%"}`}}/> }
          </div>
          <input 
            ref={sliderRef}
            id={"cursor_input_" + id}
            min={0}
            max={1}
            step={0.01}
            type="range"
            defaultValue={initCursor}
            onFocus={() => setIsSliderActive(true)}
            onBlur={() => setIsSliderActive(false)}
            onChange={(e) =>  updateBallot(Number(e.target.value))}
            onTouchEnd={(e) => onMouseUp()}
            onMouseUp={(e) => onMouseUp()}
            onTouchStart={(e) => onMouseDown()}
            onMouseDown={(e) => onMouseDown()}
            className={`w-full z-10 appearance-none focus:outline-none`}
            style={{position: 'absolute', background: 'transparent', height: CURSOR_HEIGHT, cursor: 'pointer'}}
            disabled={disabled}
          />
        </div>
      }
      <div className="w-full items-center rounded-lg p-2 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800">
        <PutBallotPreview ballotPreview={ballotPreview} />
      </div>
      <div className={`flex flex-col items-center w-full rounded-lg p-3 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800 space-y-2`}>
        <div className="flex flex-row w-full justify-between space-x-2">
          <button className={`w-1/2 h-9 text-base rounded-lg ${ballot.choice === EYesNoChoice.Yes ? "bg-brand-true text-white font-bold" : "bg-gray-100 dark:bg-gray-900 text-gray-700 dark:text-gray-300"}`} onClick={() => setBallot({ amount: ballot.amount, choice: EYesNoChoice.Yes })}>True</button>
          <button className={`w-1/2 h-9 text-base rounded-lg ${ballot.choice === EYesNoChoice.No ? "bg-brand-false text-white font-bold" : "bg-gray-100 dark:bg-gray-900 text-gray-700 dark:text-gray-300"}`} onClick={() => setBallot({ amount: ballot.amount, choice: EYesNoChoice.No })}>False</button>
        </div>
        <div className={`flex flex-col sm:flex-row space-y-2 sm:space-y-0 items-center w-full justify-around pb-2`}>
          <div className="flex flex-row items-center space-x-1 flex-grow">
          {
            PREDEFINED_PERCENTAGES.map((percentage) => (
              <button key={percentage} className={`rounded-lg h-9 text-base justify-center sm:flex-grow ${userBalance && ballot.amount === BigInt(Math.floor(percentage * Number(userBalance))) ? "bg-purple-700 text-white font-bold" : "bg-gray-100 dark:bg-gray-900 text-gray-700 dark:text-gray-300"}`} 
                onClick={() => { if(!authenticated) { login() } else { setBallot({ amount: BigInt(Math.floor(percentage * Number(userBalance))), choice: ballot.choice })}}}>{percentage * 100}%</button>
            ))
          }
          </div>
          <div className="flex flex-row items-center space-x-1 self-end">
            <span className="px-2 sm:pl-2">Custom:</span>
            <div className="relative">
              <input
                ref={customRef}
                type="text"
                onFocus={() => setIsCustomActive(true)}
                onBlur={() => setIsCustomActive(false)}
                className="w-full sm:w-32 h-9 border dark:border-gray-300 border-gray-900 rounded px-2 appearance-none focus:outline outline-1 outline-purple-500 bg-gray-100 dark:bg-gray-900"
                onChange={(e) => {
                  if (isCustomActive) {
                    setBallot({
                      choice: ballot.choice,
                      amount: convertToFixedPoint(Number(e.target.value)) ?? 0n,
                    });
                  }
                }}
              />
              { tooSmall ? parameters && 
                <div className="text-red-500 text-sm absolute top-full left-1/2 -translate-x-1/2 truncate right">
                  Minimum {formatAmount(parameters.minimum_ballot_amount)}
                </div> :
                <div className="text-gray-500 text-sm absolute top-full left-1/2 -translate-x-1/2 truncate right">
                  {formatAmountUsd(ballot.amount)}
                </div>
              }
            </div>
            <img src={getTokenLogo(metadata)} alt="Logo" className="size-[24px]" />
            <div className="pl-2" onClick={() => setBallot({ amount: 0n, choice: ballot.choice })}>
              <div className="w-5 h-5 hover:cursor-pointer fill-black dark:fill-white">
                <ResetIcon />
              </div>
            </div>
          </div>
        </div>
      </div>
      <button 
        className="button-simple w-full h-9 justify-center items-center text-base"
        disabled={putBallotLoading || tooSmall}
        onClick={triggerVote}
      >
        Lock ballot
      </button>
    </div>
    
	);
};

export default PutBallot;