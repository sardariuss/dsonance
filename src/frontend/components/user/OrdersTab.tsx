import { useEffect, useMemo, useState } from "react";
import { protocolActor } from "../actors/ProtocolActor";
import { useAuth } from "@nfid/identitykit/react";
import { toAccount } from "@/frontend/utils/conversions/account";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";
import { LimitOrder, LimitOrderType } from "@/declarations/protocol/protocol.did";
import { Link } from "react-router-dom";
import { toNullable } from "@dfinity/utils";

type OrderEntries = {
  orders: Array<{
    order: LimitOrder;
    choice: 'YES' | 'NO';
  }>;
  previous: string | undefined;
  hasMore: boolean;
};

const OrdersTab = ({ user }: { user: NonNullable<ReturnType<typeof useAuth>["user"]> }) => {
  const { supplyLedger } = useFungibleLedgerContext();
  const [orderEntries, setOrderEntries] = useState<OrderEntries>({ orders: [], previous: undefined, hasMore: true });
  const limit = 100n;

  // Fetch user's limit orders
  const { call: refetchOrders, loading } = protocolActor.unauthenticated.useQueryCall({
    functionName: 'get_limit_orders',
    onSuccess: (data) => {
      console.log("Fetched limit orders:", data);
      updateOrderEntries(data);
    }
  });

  const updateOrderEntries = (newOrders: LimitOrderType[] | undefined) => {
    if (!newOrders) return;

    const flatOrders = newOrders.map(orderType => {
      if ('YES_NO' in orderType) {
        const order = orderType.YES_NO;
        return {
          order,
          choice: ('YES' in order.choice ? 'YES' : 'NO') as 'YES' | 'NO'
        };
      }
      return null;
    }).filter((o): o is NonNullable<typeof o> => o !== null);

    setOrderEntries({
      orders: flatOrders,
      previous: flatOrders.length > 0 ? flatOrders[flatOrders.length - 1].order.order_id : undefined,
      hasMore: flatOrders.length === Number(limit)
    });
  };

  useEffect(() => {
    refetchOrders([{
      account: toAccount(user),
      previous: toNullable(orderEntries.previous),
      limit,
      direction: { backward: null }
    }]);
  }, [user]);

  if (loading) {
    return (
      <div className="flex flex-col w-full bg-white dark:bg-slate-800 shadow-md rounded-md p-4 border border-slate-300 dark:border-slate-700">
        <div className="text-center py-8 text-gray-500 dark:text-gray-400">
          Loading orders...
        </div>
      </div>
    );
  }

  if (orderEntries.orders.length === 0) {
    return (
      <div className="flex flex-col w-full bg-white dark:bg-slate-800 shadow-md rounded-md p-4 border border-slate-300 dark:border-slate-700">
        <div className="text-center py-8 text-gray-500 dark:text-gray-400">
          No limit orders found.
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col w-full bg-white dark:bg-slate-800 shadow-md rounded-md p-2 sm:p-4 border border-slate-300 dark:border-slate-700">
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead>
            <tr className="border-b border-gray-300 dark:border-gray-700">
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-600 dark:text-gray-400 uppercase tracking-wider">
                Pool
              </th>
              <th className="px-4 py-3 text-center text-xs font-medium text-gray-600 dark:text-gray-400 uppercase tracking-wider">
                Choice
              </th>
              <th className="px-4 py-3 text-center text-xs font-medium text-gray-600 dark:text-gray-400 uppercase tracking-wider">
                Limit Consensus
              </th>
              <th className="px-4 py-3 text-right text-xs font-medium text-gray-600 dark:text-gray-400 uppercase tracking-wider">
                Amount
              </th>
            </tr>
          </thead>
          <tbody>
            {orderEntries.orders.map((orderData, idx) => (
              <tr
                key={`${orderData.order.order_id}-${idx}`}
                className="border-b border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700/50"
              >
                <td className="px-4 py-3">
                  <Link
                    to={`/pool/${orderData.order.pool_id}`}
                    className="text-blue-600 dark:text-blue-400 hover:underline text-sm"
                  >
                    {orderData.order.pool_id.substring(0, 8)}...
                  </Link>
                </td>
                <td className="px-4 py-3 text-center">
                  <span
                    className={`px-2 py-1 text-xs font-semibold rounded ${
                      orderData.choice === 'YES'
                        ? 'bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-400'
                        : 'bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-400'
                    }`}
                  >
                    {orderData.choice}
                  </span>
                </td>
                <td className="px-4 py-3 text-center text-sm text-gray-900 dark:text-gray-100">
                  {(orderData.order.limit_consensus * 100).toFixed(1)}%
                </td>
                <td className="px-4 py-3 text-right text-sm text-gray-900 dark:text-gray-100">
                  {supplyLedger.formatAmountUsd(BigInt(Math.floor(orderData.order.amount)))}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default OrdersTab;
