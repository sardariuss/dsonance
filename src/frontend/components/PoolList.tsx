import { SYesNoPool } from "../../declarations/backend/backend.did";
import { backendActor } from "./actors/BackendActor";
import { useEffect, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useMediaQuery } from "react-responsive";
import PoolCard, { PoolCardSkeleton } from "./PoolCard"
import { useProtocolContext } from "./context/ProtocolContext";
import { compute_pool_details } from "../utils/conversions/pooldetails";
import { toNullable } from "@dfinity/utils";
import InfiniteScroll from "react-infinite-scroll-component";

const SkeletonLoader = ({ count }: { count: number }) => (
  <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3 py-3">
    {Array(count).fill(null).map((_, index) => (
      <PoolCardSkeleton key={index} />
    ))}
  </div>
);

const PoolList = () => {

  const [searchParams, setSearchParams] = useSearchParams();
  const poolRefs = useRef<Map<string, (HTMLDivElement | null)>>(new Map());

  // Responsive breakpoints matching Tailwind grid layout
  const isLarge = useMediaQuery({ query: '(min-width: 1024px)' }); // lg breakpoint
  const isMedium = useMediaQuery({ query: '(min-width: 768px) and (max-width: 1023px)' }); // md breakpoint
  const isSmall = useMediaQuery({ query: '(min-width: 640px) and (max-width: 767px)' }); // sm breakpoint

  const [pools, setPools] = useState<SYesNoPool[]>([]);
  const [previous, setPrevious] = useState<string | undefined>(undefined);
  const [hasMore, setHasMore] = useState<boolean>(true);

  // Dynamic limit: 6 rows × columns per breakpoint
  // lg: 5 * 4 = 20, md: 5 * 3 = 15, sm: 5 * 2 = 10, default: 5 * 1 = 5
  const limit = isLarge ? 20 : isMedium ? 15 : isSmall ? 10 : 5;

  const { computeDecay, info } = useProtocolContext();
  const navigate = useNavigate();

  const { call: fetchPools } = backendActor.unauthenticated.useQueryCall({
    functionName: "get_pools",
  });

  const fetchAndSetPools = async () => {

    const fetchedPools = await fetchPools([{
      previous: toNullable(previous),
      limit: BigInt(limit),
      direction: { backward: null }
    }]);

    if (fetchedPools && fetchedPools.length > 0) {
      setPools((prevPools) => {
        const mergedPools = [...prevPools, ...fetchedPools];
        const uniquePools = Array.from(new Map(mergedPools.map(v => [v.pool_id, v])).values());
        return uniquePools;
      });
      setPrevious(fetchedPools.length === limit ? fetchedPools[limit - 1].pool_id : undefined);
      setHasMore(fetchedPools.length === limit);
    } else {
      setHasMore(false);
    }
  };

  // Initial Fetch on Mount
  useEffect(() => {
    fetchAndSetPools();
  }, [fetchPools]);

  return (
    <div className="flex flex-col gap-y-1 w-full sm:w-4/5 md:w-11/12 lg:w-5/6 xl:w-4/5 mx-auto rounded-md p-3 pt-6 sm:pt-10">
      {/* Pool Grid */}
      <InfiniteScroll
        dataLength={pools.length}
        next={fetchAndSetPools}
        hasMore={hasMore}
        loader={<SkeletonLoader count={limit} />}
        className="w-full flex flex-col min-h-full overflow-auto"
        style={{ height: "auto", overflow: "visible" }}
      >
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
          {pools.map((pool: SYesNoPool, index) => (
            computeDecay && pool.info.visible && info &&
              <div 
                key={index}
                ref={(el) => { poolRefs.current.set(pool.pool_id, el); }}
                onClick={() => { setSearchParams({ poolId: pool.pool_id }); navigate(`/pool/${pool.pool_id}`); }}
              >
                <PoolCard 
                  tvl={pool.tvl} 
                  poolDetails={compute_pool_details(pool, computeDecay(info.current_time))} 
                  text={pool.info.text}
                  thumbnail={pool.info.thumbnail}
                />
              </div>
          ))}
        </div>
      </InfiniteScroll>
    </div>
  );
};

export default PoolList;
