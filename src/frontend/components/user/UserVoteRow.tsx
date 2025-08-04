import { MOBILE_MAX_WIDTH_QUERY } from "../../constants";

import { useMemo } from "react";
import { SYesNoVote } from "@/declarations/backend/backend.did";
import { useMediaQuery } from "react-responsive";

interface Props {
  vote: SYesNoVote;
  selected: boolean;
}

const UserVoteRow = ({ vote, selected }: Props) => {

  const thumbnail = useMemo(() => {
    const byteArray = new Uint8Array(vote.info.thumbnail);
    const blob = new Blob([byteArray]);
    return URL.createObjectURL(blob);
  }, [vote]);

  return (
    <div className={`flex flex-col items-center rounded-lg p-2 shadow-sm bg-slate-200 dark:bg-gray-800 hover:cursor-pointer w-full ${ selected ? "border-2 dark:border-gray-500 border-gray-500" : "border dark:border-gray-700 border-gray-300"}`}>
      <div className={`grid grid-cols-[auto_minmax(100px,1fr)_minmax(60px,auto)] gap-2 sm:gap-x-8 w-full items-center px-2 sm:px-3`}>

        {/* Thumbnail Image */}
        <img 
          className="w-10 h-10 min-w-10 min-h-10 bg-contain bg-no-repeat bg-center rounded-md" 
          src={thumbnail}
          alt="Vote Thumbnail"
        />
        
        <div className="flex items-center h-[4.5em] sm:h-[3em]">
          <span className="line-clamp-3 sm:line-clamp-2 overflow-hidden"> {vote.info.text} </span>
        </div>

      </div>

    </div>
  );
}

export default UserVoteRow;