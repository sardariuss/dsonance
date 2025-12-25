import { useMemo, useEffect } from "react";
import { protocolActor } from "./actors/ProtocolActor";
import { timeDifference, timeToDate } from "../utils/conversions/date";
import { useFungibleLedgerContext } from "./context/FungibleLedgerContext";
import { LimitOrder } from "@/declarations/protocol/protocol.did";
import Avatar from "boring-avatars";
import { useProtocolContext } from "./context/ProtocolContext";

interface PoolLimitOrdersProps {
  poolId: string;
}

const PoolLimitOrders = ({ poolId }: PoolLimitOrdersProps) => {
  const { supplyLedger } = useFungibleLedgerContext();
  const { info } = useProtocolContext();

  // Get limit orders for this pool
  const { data: limitOrdersByChoice, call: fetchLimitOrders } = protocolActor.unauthenticated.useQueryCall({
    functionName: 'get_pool_limit_orders',
    args: [poolId],
  });

  useEffect(() => {
    if (poolId) {
      fetchLimitOrders();
    }
  }, [poolId]);

  const { yesOrders, noOrders } = useMemo(() => {
    if (!limitOrdersByChoice) return { yesOrders: [], noOrders: [] };

    let yesOrders: LimitOrder[] = [];
    let noOrders: LimitOrder[] = [];

    limitOrdersByChoice.forEach(([choiceType, orders]) => {
      if ('YES_NO' in choiceType) {
        orders.forEach(order => {
          if ('YES_NO' in order) {
            const limitOrder = order.YES_NO;
            if ('YES' in limitOrder.choice) {
              yesOrders.push(limitOrder);
            } else {
              noOrders.push(limitOrder);
            }
          }
        });
      }
    });

    return { yesOrders, noOrders };
  }, [limitOrdersByChoice]);

  if (!limitOrdersByChoice) {
    return <PoolLimitOrdersSkeleton />;
  }

  const totalOrders = yesOrders.length + noOrders.length;

  if (totalOrders === 0) {
    return (
      <div className="flex flex-col space-y-4">
        <div className="text-center text-gray-500 dark:text-gray-400">
          No limit orders found.
        </div>
      </div>
    );
  }

  const renderOrderCard = (order: LimitOrder, isYes: boolean) => (
    <div
      key={order.order_id}
      className="rounded-lg p-4 shadow-sm bg-slate-200 dark:bg-gray-800 border dark:border-gray-700 border-gray-300"
    >
      <div className="grid grid-cols-[auto_1fr_auto_auto_auto] gap-4 items-center">

        {/* User Avatar and Address */}
        <div className="flex items-center space-x-3">
          <Avatar
            size={40}
            name={order.from.owner.toString()}
            variant="marble"
          />
          <div className="flex flex-col">
            <span className="text-xs text-gray-500 dark:text-gray-400">
              {order.from.owner.toString().slice(0, 8)}...
            </span>
          </div>
        </div>

        {/* Amount */}
        <div className="text-right">
          <div className="text-sm text-gray-600 dark:text-gray-400">Amount</div>
          <div className="font-medium">
            {supplyLedger.formatAmountUsd(BigInt(Math.floor(order.amount)))}
          </div>
        </div>

        {/* Limit Consensus */}
        <div className="text-right">
          <div className="text-sm text-gray-600 dark:text-gray-400">Limit</div>
          <div className="font-medium">
            {(order.limit_consensus * 100).toFixed(1)}%
          </div>
        </div>

        {/* Timestamp */}
        <div className="text-right">
          <div className="text-sm text-gray-600 dark:text-gray-400">Placed</div>
          <div className="text-sm">
            {info ? timeDifference(timeToDate(order.timestamp), timeToDate(info.current_time)) : '—'}
          </div>
        </div>

        {/* Choice Badge */}
        <div className="flex justify-end">
          <span className={`px-3 py-1 rounded text-sm font-semibold text-white ${
            isYes ? 'bg-brand-true dark:bg-brand-true-dark' : 'bg-brand-false'
          }`}>
            {isYes ? 'True' : 'False'}
          </span>
        </div>
      </div>
    </div>
  );

  return (
    <div className="flex flex-col space-y-4">
      <h3 className="text-xl font-semibold text-gray-800 dark:text-gray-200">
        Limit Orders ({totalOrders})
      </h3>

      {/* Yes Orders */}
      {yesOrders.length > 0 && (
        <div className="flex flex-col space-y-2">
          <h4 className="text-md font-medium text-gray-700 dark:text-gray-300">
            True Orders ({yesOrders.length})
          </h4>
          {yesOrders.map(order => renderOrderCard(order, true))}
        </div>
      )}

      {/* No Orders */}
      {noOrders.length > 0 && (
        <div className="flex flex-col space-y-2">
          <h4 className="text-md font-medium text-gray-700 dark:text-gray-300">
            False Orders ({noOrders.length})
          </h4>
          {noOrders.map(order => renderOrderCard(order, false))}
        </div>
      )}
    </div>
  );
};

export default PoolLimitOrders;

export const PoolLimitOrdersSkeleton = () => {
  return (
    <div className="flex flex-col space-y-4">
      <div className="h-6 w-48 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
      <div className="rounded-lg p-4 bg-slate-200 dark:bg-gray-800 border dark:border-gray-700 border-gray-300">
        <div className="grid grid-cols-[auto_1fr_auto_auto_auto] gap-4 items-center">
          <div className="h-10 w-10 bg-gray-300 dark:bg-gray-700 rounded-full animate-pulse"></div>
          <div className="h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
          <div className="h-4 w-20 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
          <div className="h-4 w-16 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
          <div className="h-8 w-16 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"></div>
        </div>
      </div>
    </div>
  );
};
