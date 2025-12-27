import { useEffect, useState } from "react";
import { protocolActor } from "../actors/ProtocolActor";
import { useAuth } from "@nfid/identitykit/react";
import { toAccount } from "@/frontend/utils/conversions/account";
import { LimitOrder, LimitOrderType } from "@/declarations/protocol/protocol.did";
import { toNullable } from "@dfinity/utils";
import OrderRow from "./OrderRow";
import OrderDataRow from "./OrderDataRow";
import InfiniteScroll from "react-infinite-scroll-component";
import Spinner from "../Spinner";

type OrderEntries = {
  orders: Array<{
    order: LimitOrder;
    choice: 'YES' | 'NO';
  }>;
  previous: string | undefined;
  hasMore: boolean;
};

const OrdersTab = ({ user }: { user: NonNullable<ReturnType<typeof useAuth>["user"]> }) => {
  const [orderEntries, setOrderEntries] = useState<OrderEntries>({ orders: [], previous: undefined, hasMore: true });
  const limit = 10n;

  // Fetch user's limit orders
  const { call: refetchOrders } = protocolActor.unauthenticated.useQueryCall({
    functionName: 'get_limit_orders',
    args: [{
      account: toAccount(user),
      previous: toNullable(orderEntries.previous),
      limit,
      direction: { backward: null }
    }],
    onError: (error) => {
      console.error("Error fetching limit orders:", error);
    },
    onSuccess: (data) => {
      console.log("Fetched limit orders:", data);
      updateOrderEntries(data);
    }
  });

  const updateOrderEntries = (newOrders: LimitOrderType[]) => {
    setOrderEntries((prevEntries) => {
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

      const mergedOrders = [...prevEntries.orders, ...flatOrders];
      const uniqueOrders = Array.from(new Map(mergedOrders.map(v => [v.order.order_id, v])).values());
      const previous = flatOrders.length > 0 ? flatOrders[flatOrders.length - 1].order.order_id : prevEntries.previous;
      const hasMore = flatOrders.length === Number(limit);
      return { orders: uniqueOrders, previous, hasMore };
    });
  };

  useEffect(() => {
    refetchOrders();
  }, [user]);

  return (
    <div className="flex flex-col w-full bg-white dark:bg-slate-800 shadow-md rounded-md p-2 sm:p-4 border border-slate-300 dark:border-slate-700 space-y-4">
      {/* Layout: Fixed column + Scrollable section */}
      {orderEntries.orders.length === 0 ? (
        <div className="w-full text-center py-8 text-gray-500 dark:text-gray-400">
          No limit orders found.
        </div>
      ) : (
        <InfiniteScroll
          dataLength={orderEntries.orders.length}
          next={refetchOrders}
          hasMore={orderEntries.hasMore}
          loader={<Spinner size={"25px"} />}
          style={{ height: "auto", overflow: "visible" }}
        >
          <div className="w-full flex">
            {/* Fixed Pool column */}
            <div className="flex-shrink-0 flex flex-col w-[200px] sm:w-[700px]">
              {/* Pool header */}
              <span className="pb-2 text-sm text-gray-500 dark:text-gray-500">POOL</span>
              {/* Pool data rows */}
              <ul className="flex flex-col gap-y-2">
                {orderEntries.orders.map((orderData, index) => (
                  <li
                    key={index}
                    className="scroll-mt-[104px] sm:scroll-mt-[88px]"
                  >
                    <OrderRow order={orderData.order} choice={orderData.choice} />
                  </li>
                ))}
              </ul>
            </div>

            {/* Scrollable columns section (header + data together) */}
            <div className="flex-1 overflow-x-auto">
              <div className="min-w-[200px] flex flex-col">
                {/* Scrollable header */}
                <div className="grid grid-cols-2 gap-2 sm:gap-4 pb-2">
                  <span className="text-sm text-gray-500 dark:text-gray-500 text-right">LIMIT CONSENSUS</span>
                  <span className="text-sm text-gray-500 dark:text-gray-500 text-right">AMOUNT</span>
                </div>
                {/* Scrollable data rows */}
                <ul className="flex flex-col gap-y-2">
                  {orderEntries.orders.map((orderData, index) => (
                    <li key={index}>
                      <OrderDataRow order={orderData.order} />
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          </div>
        </InfiniteScroll>
      )}
    </div>
  );
};

export default OrdersTab;
