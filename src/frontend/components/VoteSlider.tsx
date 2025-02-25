import { EYesNoChoice } from '../utils/conversions/yesnochoice';
import { useEffect, useRef, useState } from 'react';
import { BallotInfo } from './types';
import { useCurrencyContext } from './CurrencyContext';
import { useAllowanceContext } from './AllowanceContext';
import BitcoinIcon from './icons/BitcoinIcon';

const CURSOR_HEIGHT = "1.3rem";
const PREDEFINED_PERCENTAGES = [0.1, 0.25, 0.5, 1.0];

type Props = {
  id: string;
  disabled: boolean;
  ballot: BallotInfo;
  setBallot: (ballot: BallotInfo) => void;
  onMouseUp: () => (void);
  onMouseDown: () => (void);
};

const VoteSlider = ({id, disabled, ballot, setBallot, onMouseUp, onMouseDown}: Props) => {

  const { formatSatoshis, currencySymbol, currencyToSatoshis, satoshisToCurrency } = useCurrencyContext();
  const { btcAllowance } = useAllowanceContext();

  useEffect(() => {
  // Only update if input is not focused, meaning that it comes from an external stimulus
    if (inputRef.current && !isActive) {
      let amount = satoshisToCurrency(ballot.amount);
      if (amount !== undefined) {
        inputRef.current.value = amount.toString();
      }
    }
  },
  [ballot]);

  const inputRef = useRef<HTMLInputElement>(null);
  const [isActive, setIsActive] = useState(false);

	return (
    <div className="flex flex-col items-center w-full">
      <div id={"cursor_" + id} className="w-full flex flex-col items-center" style={{ position: 'relative' }}>
        <div className="flex w-full rounded-sm z-0" style={{ height: CURSOR_HEIGHT, position: 'relative' }}>
          <div 
            className={`flex flex-col justify-center items-center text-xs font-medium leading-none text-white bg-brand-true border border-black dark:border-white h-full`}
            style={{ width: `${(ballot.choice === EYesNoChoice.Yes ? 0.5 + 0.5 * (Number(ballot.amount) / Number(btcAllowance)) : 0.5 - 0.5 *(Number(ballot.amount) / Number(btcAllowance))) * 100 + "%"}`}}
          >
            { 
              ballot.choice === EYesNoChoice.Yes && ballot.amount > 0n &&
                <span className={`truncate animate-pulse`}>
                  { "+ " + formatSatoshis(ballot.amount) + " on " + EYesNoChoice.Yes } 
                </span>
            } 
          </div>
          <div className={`flex flex-col justify-center items-center text-xs font-medium text-center leading-none text-white bg-brand-false border border-black dark:border-white h-full`}
            style={{ width: `${(ballot.choice === EYesNoChoice.No ? 0.5 + 0.5 *(Number(ballot.amount) / Number(btcAllowance)) : 0.5 - 0.5 *(Number(ballot.amount) / Number(btcAllowance))) * 100 + "%"}`}}
          >
            { 
              ballot.choice === EYesNoChoice.No && ballot.amount > 0n &&
                <span className={`truncate animate-pulse`}>
                  { "+ " + formatSatoshis(ballot.amount) + " on " + EYesNoChoice.No } 
                </span>
            }
          </div>
        </div>
        <input 
          id={"cursor_input_" + id}
          min={-Number(btcAllowance)}
          max={Number(btcAllowance)}
          step="1"
          type="range"
          defaultValue={0}
          onChange={(e) =>  setBallot({ amount: BigInt(Math.floor(Math.abs(Number(e.target.value)))), choice: Number(e.target.value) < 0 ? EYesNoChoice.No : EYesNoChoice.Yes })}
          onTouchEnd={(e) => onMouseUp()}
          onMouseUp={(e) => onMouseUp()}
          onTouchStart={(e) => onMouseDown()}
          onMouseDown={(e) => onMouseDown()}
          className={`w-full z-10 appearance-none focus:outline-none`}
          style={{position: 'absolute', background: 'transparent', height: CURSOR_HEIGHT, cursor: 'pointer'}}
          disabled={disabled}
        />
      </div>
      <div className="flex flex-row w-full justify-between">
        <button className={`w-1/2 h-9 text-base bg-brand-true ${ballot.choice === EYesNoChoice.Yes ? "opacity-100 font-bold" : "opacity-70"}`} onClick={() => setBallot({ amount: ballot.amount, choice: EYesNoChoice.Yes })}>Yes</button>
        <button className={`w-1/2 h-9 text-base bg-brand-false ${ballot.choice === EYesNoChoice.No ? "opacity-100 font-bold" : "opacity-70"}`} onClick={() => setBallot({ amount: ballot.amount, choice: EYesNoChoice.No })}>No</button>
      </div>
      <div className="flex flex-row w-full justify-between">
        {
          PREDEFINED_PERCENTAGES.map((percentage) => (
            <button key={percentage} className={`button-simple w-1/4 h-9 text-base`} 
              onClick={() => setBallot({ amount: BigInt(Math.floor(percentage * Number(btcAllowance))), choice: ballot.choice })}>{percentage * 100}%</button>
          ))
        }
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
    </div>
    
	);
};

export default VoteSlider;