import { useMemo, useEffect } from "react";
import { backendActor } from "./actors/BackendActor";
import { timeDifference, timeToDate } from "../utils/conversions/date";
import { useFungibleLedgerContext } from "./context/FungibleLedgerContext";
import { SYesNoBallotWithUser } from "@/declarations/backend/backend.did";
import Avatar from "boring-avatars";
import { unwrapLock } from "../utils/conversions/ballot";
import { useProtocolContext } from "./context/ProtocolContext";
import { fromNullableExt } from "../utils/conversions/nullable";

interface VoteBallotsProps {
  voteId: string;
}

const VoteBallots = ({ voteId }: VoteBallotsProps) => {
  const { supplyLedger } = useFungibleLedgerContext();
  const { info } = useProtocolContext();

  // Get ballots for this vote
  const { data: ballots, call: fetchBallots } = backendActor.unauthenticated.useQueryCall({
    functionName: 'get_vote_ballots',
    args: [voteId],
  });

  useEffect(() => {
    if (voteId) {
      fetchBallots();
    }
  }, [voteId]);

  const currentTime = useMemo(() => {
    return info ? BigInt(info.current_time) : undefined;
  }, [info]);

  const { yesBallots, noBallots } = useMemo(() => {
    if (!ballots || !currentTime) return { yesBallots: [], noBallots: [] };

    const processedBallots = ballots.map((ballot: SYesNoBallotWithUser) => {
      const lock = unwrapLock(ballot);
      const releaseTimestamp = ballot.timestamp + lock.duration_ns.current.data;
      const nickname = fromNullableExt(ballot.user)?.nickname || "Anonymous";
      return {
        ...ballot,
        nickname,
        releaseTimestamp,
        isExpired: releaseTimestamp <= currentTime,
      };
    });

    const yesBallots = processedBallots.filter(ballot => "YES" in ballot.choice);
    const noBallots = processedBallots.filter(ballot => "NO" in ballot.choice);

    return { yesBallots, noBallots };
  }, [ballots, currentTime]);

  if (!ballots) {
    return <VoteBallotsSkeleton />;
  }

  if (ballots.length === 0) {
    return (
      <div className="flex flex-col space-y-4">
        <div className="text-center text-gray-500 dark:text-gray-400">
          No positions found.
        </div>
      </div>
    );
  }

  const renderBallotCard = (ballot: any) => (
    <div
      key={ballot.ballot_id}
      className="rounded-lg p-4 shadow-sm bg-slate-200 dark:bg-gray-800 border dark:border-gray-700 border-gray-300"
    >
      <div className="grid grid-cols-[auto_1fr_auto_auto] gap-4 items-center">
        
        {/* User Avatar and Name */}
        <div className="flex items-center space-x-3">
          <Avatar
            size={40}
            name={ballot.from.owner.toString()}
            variant="marble"
          />
          <div className="flex flex-col">
            <span className="text-sm font-medium text-gray-800 dark:text-gray-200">
              {ballot.nickname}
            </span>
            <span className="text-xs text-gray-500 dark:text-gray-400">
              {ballot.from.owner.toString().slice(0, 8)}...
            </span>
          </div>
        </div>

        {/* Amount Locked */}
        <div className="text-right">
          <div className="text-sm text-gray-600 dark:text-gray-400">Amount</div>
          <div className="font-medium">
            {supplyLedger.formatAmountUsd(ballot.amount)}
          </div>
        </div>

        {/* Ballot Date */}
        <div className="text-right">
          <div className="text-sm text-gray-600 dark:text-gray-400">Date</div>
          <div className="text-sm">
            {timeDifference(timeToDate(ballot.timestamp), new Date())} ago
          </div>
        </div>

      </div>
    </div>
  );

  return (
    <div className="flex flex-col space-y-4">
      <div className="text-lg font-semibold text-gray-800 dark:text-gray-200 border-b pb-1 border-gray-500 dark:border-gray-300">
        Vote Ballots
      </div>
      
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* YES Ballots Column */}
        <div className="flex flex-col space-y-3">
          <div className="flex items-center space-x-2">
            <div className="text-base font-semibold">
              YES Votes
            </div>
            <div className="text-sm text-gray-500 dark:text-gray-400">
              ({yesBallots.length})
            </div>
          </div>
          <div className="space-y-3">
            {yesBallots.length > 0 ? (
              yesBallots.map(renderBallotCard)
            ) : (
              <div className="text-center text-gray-500 dark:text-gray-400 py-8">
                No YES votes yet
              </div>
            )}
          </div>
        </div>

        {/* NO Ballots Column */}
        <div className="flex flex-col space-y-3">
          <div className="flex items-center space-x-2">
            <div className="text-base font-semibold">
              NO Votes
            </div>
            <div className="text-sm text-gray-500 dark:text-gray-400">
              ({noBallots.length})
            </div>
          </div>
          <div className="space-y-3">
            {noBallots.length > 0 ? (
              noBallots.map(renderBallotCard)
            ) : (
              <div className="text-center text-gray-500 dark:text-gray-400 py-8">
                No NO votes yet
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

const VoteBallotsSkeleton = () => {
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
        {/* YES Ballots Column Skeleton */}
        <div className="flex flex-col space-y-3">
          <div className="flex items-center space-x-2">
            <div className="w-20 h-5 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
            <div className="w-6 h-4 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
          </div>
          <div className="space-y-3">
            {Array.from({ length: 3 }).map((_, i) => renderSkeletonCard(i))}
          </div>
        </div>

        {/* NO Ballots Column Skeleton */}
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

export default VoteBallots;