import { useMemo, useEffect } from "react";
import { backendActor } from "./actors/BackendActor";
import { timeDifference, timeToDate } from "../utils/conversions/date";
import { useFungibleLedgerContext } from "./context/FungibleLedgerContext";
import { SYesNoPositionWithUser } from "@/declarations/backend/backend.did";
import Avatar from "boring-avatars";
import { unwrapLock } from "../utils/conversions/position";
import { useProtocolContext } from "./context/ProtocolContext";
import { fromNullableExt } from "../utils/conversions/nullable";

interface PoolPositionsProps {
  poolId: string;
}

const PoolPositions = ({ poolId }: PoolPositionsProps) => {
  const { supplyLedger } = useFungibleLedgerContext();
  const { info } = useProtocolContext();

  // Get positions for this pool
  const { data: positions, call: fetchPositions } = backendActor.unauthenticated.useQueryCall({
    functionName: 'get_pool_positions',
    args: [poolId],
  });

  useEffect(() => {
    if (poolId) {
      fetchPositions();
    }
  }, [poolId]);

  const currentTime = useMemo(() => {
    return info ? BigInt(info.current_time) : undefined;
  }, [info]);

  const { yesPositions, noPositions } = useMemo(() => {
    if (!positions || !currentTime) return { yesPositions: [], noPositions: [] };

    const processedPositions = positions.map((position: SYesNoPositionWithUser) => {
      const lock = unwrapLock(position);
      const releaseTimestamp = position.timestamp + lock.duration_ns.current.data;
      const nickname = fromNullableExt(position.user)?.nickname || "Anonymous";
      return {
        ...position,
        nickname,
        releaseTimestamp,
        isExpired: releaseTimestamp <= currentTime,
      };
    });

    const yesPositions = processedPositions.filter(position => "YES" in position.choice);
    const noPositions = processedPositions.filter(position => "NO" in position.choice);

    return { yesPositions, noPositions };
  }, [positions, currentTime]);

  if (!positions) {
    return <PoolPositionsSkeleton />;
  }

  if (positions.length === 0) {
    return (
      <div className="flex flex-col space-y-4">
        <div className="text-center text-gray-500 dark:text-gray-400">
          No positions found.
        </div>
      </div>
    );
  }

  const renderPositionCard = (position: any) => (
    <div
      key={position.position_id}
      className="rounded-lg p-4 shadow-sm bg-slate-200 dark:bg-gray-800 border dark:border-gray-700 border-gray-300"
    >
      <div className="grid grid-cols-[auto_1fr_auto_auto] gap-4 items-center">
        
        {/* User Avatar and Name */}
        <div className="flex items-center space-x-3">
          <Avatar
            size={40}
            name={position.from.owner.toString()}
            variant="marble"
          />
          <div className="flex flex-col">
            <span className="text-sm font-medium text-gray-800 dark:text-gray-200">
              {position.nickname}
            </span>
            <span className="text-xs text-gray-500 dark:text-gray-400">
              {position.from.owner.toString().slice(0, 8)}...
            </span>
          </div>
        </div>

        {/* Amount Locked */}
        <div className="text-right">
          <div className="text-sm text-gray-600 dark:text-gray-400">Amount</div>
          <div className="font-medium">
            {supplyLedger.formatAmountUsd(position.amount)}
          </div>
        </div>

        {/* Position Date */}
        <div className="text-right">
          <div className="text-sm text-gray-600 dark:text-gray-400">Date</div>
          { currentTime && 
            <div className="text-sm">
              {timeDifference(timeToDate(currentTime), timeToDate(position.timestamp))} ago
            </div>
          }
        </div>

      </div>
    </div>
  );

  return (
    <div className="flex flex-col space-y-4">
      <div className="text-lg font-semibold text-gray-800 dark:text-gray-200 border-b pb-1 border-gray-500 dark:border-gray-300">
        Pool Positions
      </div>
      
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* YES Positions Column */}
        <div className="flex flex-col space-y-3">
          <div className="flex items-center space-x-2">
            <div className="text-base font-semibold">
              YES Positions
            </div>
            <div className="text-sm text-gray-500 dark:text-gray-400">
              ({yesPositions.length})
            </div>
          </div>
          <div className="space-y-3">
            {yesPositions.length > 0 ? (
              yesPositions.map(renderPositionCard)
            ) : (
              <div className="text-center text-gray-500 dark:text-gray-400 py-8">
                No YES positions yet
              </div>
            )}
          </div>
        </div>

        {/* NO Positions Column */}
        <div className="flex flex-col space-y-3">
          <div className="flex items-center space-x-2">
            <div className="text-base font-semibold">
              NO Positions
            </div>
            <div className="text-sm text-gray-500 dark:text-gray-400">
              ({noPositions.length})
            </div>
          </div>
          <div className="space-y-3">
            {noPositions.length > 0 ? (
              noPositions.map(renderPositionCard)
            ) : (
              <div className="text-center text-gray-500 dark:text-gray-400 py-8">
                No NO positions yet
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

const PoolPositionsSkeleton = () => {
  const renderSkeletonCard = (key: number) => (
    <div
      key={key}
      className="rounded-lg p-4 shadow-sm bg-slate-200 dark:bg-gray-800 border dark:border-gray-700 border-gray-300"
    >
      <div className="grid grid-cols-[auto_1fr_auto_auto] gap-4 items-center">
        
        {/* User Avatar and Name Skeleton */}
        <div className="flex items-center space-x-3">
          <div className="w-10 h-10 bg-gray-300 dark:bg-gray-700 rounded-full animate-pulse" />
          <div className="flex flex-col space-y-1">
            <div className="w-20 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
            <div className="w-16 h-3 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
          </div>
        </div>

        {/* Amount Skeleton */}
        <div className="text-right">
          <div className="w-12 h-3 bg-gray-300 dark:bg-gray-700 rounded animate-pulse mb-1" />
          <div className="w-16 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
        </div>

        {/* Date Skeleton */}
        <div className="text-right">
          <div className="w-8 h-3 bg-gray-300 dark:bg-gray-700 rounded animate-pulse mb-1" />
          <div className="w-12 h-3 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
        </div>

      </div>
    </div>
  );

  return (
    <div className="flex flex-col space-y-4">
      <div className="flex items-center space-x-2">
        <div className="w-32 h-6 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
        <div className="w-8 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
      </div>
      
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* YES Positions Column Skeleton */}
        <div className="flex flex-col space-y-3">
          <div className="flex items-center space-x-2">
            <div className="w-20 h-5 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
            <div className="w-6 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
          </div>
          <div className="space-y-3">
            {Array.from({ length: 3 }).map((_, i) => renderSkeletonCard(i))}
          </div>
        </div>

        {/* NO Positions Column Skeleton */}
        <div className="flex flex-col space-y-3">
          <div className="flex items-center space-x-2">
            <div className="w-20 h-5 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
            <div className="w-6 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
          </div>
          <div className="space-y-3">
            {Array.from({ length: 2 }).map((_, i) => renderSkeletonCard(i + 3))}
          </div>
        </div>
      </div>
    </div>
  );
};

export default PoolPositions;