import { useEffect, useRef, useState } from 'react';
import { EYesNoChoice } from '../utils/conversions/yesnochoice';
import { PositionInfo } from './types';
import { add_position, deduce_position, PoolDetails } from '../utils/conversions/pooldetails';

const CURSOR_HEIGHT = "0.3rem";
const MIN_CURSOR = 0.001;
const MAX_CURSOR = 0.999;

const clampCursor = (cursor: number) => {
  return Math.min(Math.max(cursor, MIN_CURSOR), MAX_CURSOR);
};

interface PoolSliderProps {
  id: string;
  position: PositionInfo;
  setPosition: (position: PositionInfo) => void;
  poolDetails: PoolDetails;
}

const PoolSlider: React.FC<PoolSliderProps> = ({ 
  id, 
  position, 
  setPosition, 
  poolDetails,
}) => {
  const sliderRef = useRef<HTMLInputElement>(null);
  const [isSliderActive, setIsSliderActive] = useState(false);
  
  const initCursor = poolDetails.cursor;
  const [cursor, setCursor] = useState(initCursor);

  const updatePosition = (value: number) => {
    value = clampCursor(value);
    setCursor(value);
    setPosition(deduce_position(poolDetails, value));
  };

  useEffect(() => {
    if (sliderRef.current && !isSliderActive) {
      const liveDetails = add_position(poolDetails, position);
      setCursor(liveDetails.cursor);
      if (liveDetails.cursor !== undefined) {
        sliderRef.current.value = liveDetails.cursor.toString();
      }
    }
  }, [position, poolDetails, isSliderActive]);

  if (cursor === undefined) {
    return <div className="pt-2"></div>;
  }

  return (
    <div id={"cursor_" + id} className="w-full flex flex-col items-center my-2 sm:my-1" style={{ position: 'relative' }}>
      <div className="flex w-full rounded-sm z-0" style={{ height: CURSOR_HEIGHT, position: 'relative' }}>  
        {cursor > MIN_CURSOR && (
          <div 
            className={`bg-brand-true dark:bg-brand-true-dark h-full rounded-l ${position.choice === EYesNoChoice.Yes ? "" : "opacity-70"}`}  
            style={{ width: `${cursor * 100}%` }}
          />
        )}
        {cursor < MAX_CURSOR && (
          <div 
            className={`bg-brand-false h-full rounded-r ${position.choice === EYesNoChoice.No ? "" : "opacity-70"}`} 
            style={{ width: `${(1 - cursor) * 100}%` }}
          />
        )}
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
        onChange={(e) => updatePosition(Number(e.target.value))}
        onTouchEnd={() => {}}
        onMouseUp={() => {}}
        onTouchStart={() => {}}
        onMouseDown={() => {}}
        className="w-full z-10 appearance-none focus:outline-none"
        style={{position: 'absolute', background: 'transparent', height: CURSOR_HEIGHT, cursor: 'pointer'}}
      />
    </div>
  );
};

export default PoolSlider;