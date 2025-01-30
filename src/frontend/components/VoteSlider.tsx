import { EYesNoChoice } from '../utils/conversions/yesnochoice';
import { useEffect, useRef, useState } from 'react';
import { BallotInfo } from './types';
import { add_ballot, deduce_ballot, VoteDetails } from '../utils/conversions/votedetails';
import { useCurrencyContext } from './CurrencyContext';
import { useMediaQuery } from 'react-responsive';
import { MOBILE_MAX_WIDTH_QUERY } from '../constants';

const CURSOR_HEIGHT = "1.3rem";
const DEFAULT_CURSOR = 0.5;
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
  onMouseUp: () => (void);
  onMouseDown: () => (void);
};

const VoteSlider = ({id, disabled, voteDetails, ballot, setBallot, onMouseUp, onMouseDown}: Props) => {

  const { formatSatoshis } = useCurrencyContext();

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const initCursor = voteDetails.cursor ?? DEFAULT_CURSOR

  const [cursor, setCursor] = useState(initCursor);

  const updateBallot = (value: number) => {
    value = clampCursor(value);
    setCursor(value);
    setBallot(deduce_ballot(voteDetails, value));
  };

  const inputRef = useRef<HTMLInputElement>(null);
  const [isActive, setIsActive] = useState(false);

  const updateCursor = (ballot: BallotInfo) => {
    if (inputRef.current && !isActive) { // Only update if input is not focused, i.e. the stimulus comes from an external component
      const liveDetails = add_ballot(voteDetails, ballot);
      setCursor(liveDetails.cursor);
      inputRef.current.value = liveDetails.cursor.toString();
    }
  };

  useEffect(() => {
    updateCursor(ballot);
  },
  [ballot, voteDetails]);

  const limitDisplayRatio = isMobile ? 0.3 : 0.2;

	return (
    <div id={"cursor_" + id} className="w-full flex flex-col items-center" style={{ position: 'relative' }}>
      <div className="flex w-full rounded-sm z-0" style={{ height: CURSOR_HEIGHT, position: 'relative' }}>
        {
          cursor > MIN_CURSOR &&
            <div 
              className={`flex flex-col justify-center items-center text-xs font-medium leading-none text-white bg-brand-true border-y border-l border-black dark:border-white h-full`}
              style={{ width: `${cursor * 100 + "%"}`}}
            >
              { 
                cursor > limitDisplayRatio && 
                  <span className={`truncate ${ballot.choice === EYesNoChoice.Yes && (ballot.amount ?? 0n) > 0n ? "animate-pulse" : ""}`}>
                    { formatSatoshis(BigInt(Math.trunc(voteDetails.yes + (ballot.choice === EYesNoChoice.Yes ? Number(ballot.amount) : 0)))) + " " + EYesNoChoice.Yes } 
                  </span>
              }
            </div>
        }
        <div className="absolute text-xl overflow-visible" style={{ left: `${(cursor * 100 - (isMobile ? 4 : 1)) + "%"}`, top: -4, bottom: 0, width: 0, zIndex: 20 }}>
          { ballot.choice === EYesNoChoice.Yes ? "👍" : "👎" }
        </div>
        {
          cursor < MAX_CURSOR &&    
            <div className={`flex flex-col justify-center items-center text-xs font-medium text-center leading-none text-white bg-brand-false border-y border-r border-black dark:border-white h-full`}
              style={{ width: `${( 1 - cursor) * 100 + "%"}`}}>
              { 
                (1 - cursor) > limitDisplayRatio && 
                  <span className={`truncate ${ballot.choice === EYesNoChoice.No && (ballot.amount ?? 0n) > 0n ? "animate-pulse" : ""}`}>
                    { formatSatoshis(BigInt(Math.trunc(voteDetails.no + (ballot.choice === EYesNoChoice.No ? Number(ballot.amount) : 0)))) + " " + EYesNoChoice.No } 
                  </span>
              }
            </div>
        }
      </div>
      <input 
        id={"cursor_input_" + id}
        ref={inputRef}
        min="0"
        max="1"
        step="0.01"
        type="range"
        defaultValue={initCursor}
        onFocus={() => setIsActive(true)}
        onBlur={() => setIsActive(false)}
        onChange={(e) => updateBallot(Number(e.target.value))}
        onTouchEnd={(e) => onMouseUp()}
        onMouseUp={(e) => onMouseUp()}
        onTouchStart={(e) => onMouseDown()}
        onMouseDown={(e) => onMouseDown()}
        className={`w-full z-10 appearance-none focus:outline-none`}
        style={{position: 'absolute', background: 'transparent', height: CURSOR_HEIGHT, cursor: 'pointer'}}
        disabled={disabled}
      />
    </div>
    
	);
};

export default VoteSlider;