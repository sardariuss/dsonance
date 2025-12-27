import { useMemo } from "react";
import { fromNullable } from "@dfinity/utils";
import { backendActor } from "../actors/BackendActor";
import { LimitOrder } from "@/declarations/protocol/protocol.did";
import { createThumbnailUrl } from "../../utils/thumbnail";
import { useNavigate } from "react-router-dom";
import ChoiceView from "../ChoiceView";
import { toEnum } from "../../utils/conversions/yesnochoice";

interface OrderRowProps {
  order: LimitOrder;
  choice: 'YES' | 'NO';
}

const OrderRow = ({ order, choice }: OrderRowProps) => {
  const navigate = useNavigate();

  const { data: opt_pool } = backendActor.unauthenticated.useQueryCall({
    functionName: "get_pool",
    args: [{ pool_id: order.pool_id }],
  });

  const pool = useMemo(() => {
    return opt_pool ? fromNullable(opt_pool) : undefined;
  }, [opt_pool]);

  const thumbnailUrl = useMemo(() => {
    if (pool === undefined) {
      return undefined;
    }
    return createThumbnailUrl(pool.info.thumbnail);
  }, [pool]);

  return (
    <div className="py-2 h-[60px] sm:h-[68px] flex items-center">
      <div
        className="flex flex-row items-center hover:cursor-pointer gap-x-1 sm:gap-x-2 w-full"
        onClick={() => {
          navigate(`/pool/${order.pool_id}`);
        }}
      >
        <img
          className="w-8 h-8 sm:w-10 sm:h-10 min-w-8 min-h-8 sm:min-w-10 sm:min-h-10 bg-contain bg-no-repeat bg-center rounded-md"
          src={thumbnailUrl}
          alt="Pool Thumbnail"
        />
        <div className="flex flex-col space-y-0.5 sm:space-y-1 min-w-0 pl-1">
          <div className="text-xs sm:text-sm line-clamp-1 overflow-hidden">
            {pool === undefined ? (
              <span className="w-full h-4 sm:h-2 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
            ) : (
              <span className="line-clamp-1 overflow-hidden">{pool.info.text}</span>
            )}
          </div>
          <div className="flex">
            <ChoiceView choice={toEnum(choice === 'YES' ? { YES: null } : { NO: null })} />
          </div>
        </div>
      </div>
    </div>
  );
};

export default OrderRow;
