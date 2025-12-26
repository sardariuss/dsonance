import { useMemo, useEffect, useRef } from "react";
import { protocolActor } from "./actors/ProtocolActor";
import { useFungibleLedgerContext } from "./context/FungibleLedgerContext";
import { LimitOrder } from "@/declarations/protocol/protocol.did";
import { MAX_VISIBLE_LIMIT_ORDERS } from "../constants";

interface PoolLimitOrdersProps {
  poolId: string;
  consensus: number;
}

interface OrderRow {
  consensus: number;
  amount: number;
  total: number;
}

const PoolLimitOrders = ({ poolId, consensus }: PoolLimitOrdersProps) => {
  const { supplyLedger } = useFungibleLedgerContext();
  const separatorRowRef = useRef<HTMLTableRowElement>(null);

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

  // Scroll to center the separator row when data loads
  useEffect(() => {
    if (limitOrdersByChoice && separatorRowRef.current) {
      separatorRowRef.current.scrollIntoView({ block: 'center', behavior: 'auto' });
    }
  }, [limitOrdersByChoice]);

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

  const { yesRows, noRows } = useMemo(() => {
    // Group orders by consensus and calculate cumulative totals
    const groupOrders = (orders: LimitOrder[], reverseTotal: boolean = false): OrderRow[] => {
      const grouped = new Map<number, number>();

      orders.forEach(order => {
        const consensus = Math.round(order.limit_consensus * 1000) / 1000; // Round to 3 decimals
        grouped.set(consensus, (grouped.get(consensus) || 0) + order.amount);
      });

      // Sort by consensus descending (high to low)
      const sorted = Array.from(grouped.entries())
        .sort(([a], [b]) => b - a);

      // For FALSE orders, compute cumulative totals in reverse order (low to high)
      if (reverseTotal) {
        const reversed = [...sorted].reverse();
        let cumulative = 0;
        const rowsWithTotals = reversed.map(([consensus, amount]) => {
          cumulative += amount;
          return { consensus, amount, total: cumulative };
        });
        return rowsWithTotals.reverse(); // Reverse back to descending order for display
      }

      // For TRUE orders, compute cumulative totals in descending order (high to low)
      let cumulative = 0;
      return sorted.map(([consensus, amount]) => {
        cumulative += amount;
        return { consensus, amount, total: cumulative };
      });
    };

    return {
      yesRows: groupOrders(yesOrders, false), // TRUE: cumulative from high to low
      noRows: groupOrders(noOrders, true)     // FALSE: cumulative from low to high
    };
  }, [yesOrders, noOrders]);

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

  // For FALSE: max is at first row (highest consensus) after reverse
  // For TRUE: max is at last row (lowest consensus)
  const maxFalseTotal = noRows.length > 0 ? noRows[0].total : 0;
  const maxTrueTotal = yesRows.length > 0 ? yesRows[yesRows.length - 1].total : 0;

  // Calculate max height for scrollable area: header + max visible rows
  // Header with py-2 and text-xs is ~32px, each row is h-9 (36px)
  const headerHeight = 32;
  const rowHeight = 36;
  const maxHeight = headerHeight + (MAX_VISIBLE_LIMIT_ORDERS * rowHeight);

  return (
    <div className="flex flex-col space-y-4">
      <h3 className="text-xl font-semibold text-gray-800 dark:text-gray-200">
        Order book
      </h3>

      <div className="rounded-lg border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-800 overflow-hidden">
        <div className="overflow-y-auto [&::-webkit-scrollbar]:hidden [scrollbar-width:none] [-ms-overflow-style:none]" style={{ maxHeight: `${maxHeight}px` }}>
          <table className="w-full table-fixed">
          <colgroup>
            <col style={{ width: '40%' }} />
            <col style={{ width: '20%' }} />
            <col style={{ width: '20%' }} />
            <col style={{ width: '20%' }} />
          </colgroup>
          <thead className="sticky top-0 z-10">
            <tr className="border-b border-gray-300 dark:border-gray-700 bg-gray-50 dark:bg-gray-900">
              <th className="px-2 py-2 text-left text-xs font-medium text-gray-600 dark:text-gray-400 uppercase tracking-wider">
                &nbsp;
              </th>
              <th className="px-2 py-2 text-center text-xs font-medium text-gray-600 dark:text-gray-400 uppercase tracking-wider">
                Consensus
              </th>
              <th className="px-2 py-2 text-center text-xs font-medium text-gray-600 dark:text-gray-400 uppercase tracking-wider">
                Amount
              </th>
              <th className="px-2 py-2 text-center text-xs font-medium text-gray-600 dark:text-gray-400 uppercase tracking-wider">
                Total
              </th>
            </tr>
          </thead>
          <tbody>
            {/* False Orders */}
            {noRows.map((row, idx) => {
              const percentage = maxFalseTotal > 0 ? (row.total / maxFalseTotal) * 100 : 0;

              return (
                <tr
                  key={`no-${row.consensus}-${idx}`}
                  className="group h-9 hover:bg-red-50 dark:hover:bg-red-950/20"
                >
                  <td className="p-0 relative h-9">
                    <div
                      className="absolute inset-0 bg-red-500/30 dark:bg-red-500/40 group-hover:bg-red-500/50 dark:group-hover:bg-red-500/60"
                      style={{ width: `${percentage}%` }}
                    />
                  </td>
                  <td className="px-2 py-1.5 text-sm text-center font-bold text-red-600 dark:text-red-400">
                    {(row.consensus * 100).toFixed(0)}%
                  </td>
                  <td className="px-2 py-1.5 text-sm text-center text-gray-900 dark:text-gray-100">
                    {supplyLedger.formatAmountUsd(BigInt(Math.floor(row.amount)))}
                  </td>
                  <td className="px-2 py-1.5 text-sm text-center font-medium text-gray-900 dark:text-gray-100">
                    {supplyLedger.formatAmountUsd(BigInt(Math.floor(row.total)))}
                  </td>
                </tr>
              );
            })}

            {/* Separator row with current pool consensus */}
            <tr ref={separatorRowRef} className="border-t border-b border-gray-300 dark:border-gray-600">
              <td className="p-0"></td>
              <td className="px-2 py-1.5 text-sm text-center text-gray-500 dark:text-gray-400">
                Current: {consensus.toFixed(0)}%
              </td>
              <td className="px-2 py-1.5"></td>
              <td className="px-2 py-1.5"></td>
            </tr>

            {/* True Orders */}
            {yesRows.map((row, idx) => {
              const percentage = maxTrueTotal > 0 ? (row.total / maxTrueTotal) * 100 : 0;

              return (
                <tr
                  key={`yes-${row.consensus}-${idx}`}
                  className="group h-9 hover:bg-green-50 dark:hover:bg-green-950/20"
                >
                  <td className="p-0 relative h-9">
                    <div
                      className="absolute inset-0 bg-green-500/30 dark:bg-green-500/40 group-hover:bg-green-500/50 dark:group-hover:bg-green-500/60"
                      style={{ width: `${percentage}%` }}
                    />
                  </td>
                  <td className="px-2 py-1.5 text-sm text-center font-bold text-green-600 dark:text-green-400">
                    {(row.consensus * 100).toFixed(0)}%
                  </td>
                  <td className="px-2 py-1.5 text-sm text-center text-gray-900 dark:text-gray-100">
                    {supplyLedger.formatAmountUsd(BigInt(Math.floor(row.amount)))}
                  </td>
                  <td className="px-2 py-1.5 text-sm text-center font-medium text-gray-900 dark:text-gray-100">
                    {supplyLedger.formatAmountUsd(BigInt(Math.floor(row.total)))}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
        </div>
      </div>
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
