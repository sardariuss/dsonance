import { DSONANCE_COIN_SYMBOL, MOBILE_MAX_WIDTH_QUERY } from "../../constants";
import { fromNullable } from "@dfinity/utils";
import { formatBalanceE8s } from "../../utils/conversions/token";

import { useEffect, useMemo } from "react";
import { protocolActor } from "../../actors/ProtocolActor";
import { SYesNoVote } from "@/declarations/backend/backend.did";
import DurationChart, { CHART_COLORS } from "../charts/DurationChart";
import { map_timeline_hack } from "../../utils/timeline";
import { useMediaQuery } from "react-responsive";

interface Props {
  vote: SYesNoVote;
  selected: boolean;
}

const UserVoteRow = ({ vote, selected }: Props) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const { data: debt_info, call: refreshDebtInfo } = protocolActor.useQueryCall({
    functionName: "get_debt_info",
    args: [vote.vote_id],
  });

  useEffect(() => {
    refreshDebtInfo();
  }
  , [vote]);

  const mined_dsn = useMemo(() => { 
      return debt_info ? fromNullable(debt_info) : undefined;
    },
    [debt_info]
  );

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

        { mined_dsn && <div className="grid grid-rows-2 w-full justify-items-end">
          <span className="text-sm text-gray-600 dark:text-gray-400">Mining earned</span>
          <span>
            {formatBalanceE8s(BigInt(Math.trunc(mined_dsn.amount.current.data.earned)), DSONANCE_COIN_SYMBOL, 2)}
          </span>
        </div> }

      </div>

      {
        mined_dsn && selected &&
          <div className={`w-2/3 ${isMobile ? "h-[200px]" : "h-[300px]"}`}>
            <DurationChart
              duration_timelines={new Map([
                [
                  "earned",
                  { timeline: map_timeline_hack(mined_dsn.amount, (contribution) => contribution.earned), color: CHART_COLORS.BLUE },
                ],
                [
                  "pending",
                  { timeline: map_timeline_hack(mined_dsn.amount, (contribution) => contribution.pending), color: CHART_COLORS.PURPLE },
                ],
              ])}
              format_value={(value: number) => formatBalanceE8s(BigInt(value), DSONANCE_COIN_SYMBOL, 2)}
              fillArea={true}
            />
          </div>
        }

    </div>
  );
}

export default UserVoteRow;