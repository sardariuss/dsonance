import { SYesNoPool } from "../../declarations/backend/backend.did";
import { backendActor } from "./actors/BackendActor";
import { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../constants";
import PoolCard from "./PoolCard"
import { useProtocolContext } from "./context/ProtocolContext";
import { compute_pool_details } from "../utils/conversions/pooldetails";
import { toNullable } from "@dfinity/utils";
import InfiniteScroll from "react-infinite-scroll-component";

const SkeletonLoader = ({ count }: { count: number }) => (
  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 p-3">
    {Array(count).fill(null).map((_, index) => (
      <div key={index} className="bg-gray-300 dark:bg-gray-700 rounded-lg shadow-md p-4 animate-pulse h-32"></div>
    ))}
  </div>
);

const PoolList = () => {

  const [searchParams, setSearchParams] = useSearchParams();
  const poolRefs = useRef<Map<string, (HTMLDivElement | null)>>(new Map());
  const selectedPoolId = useMemo(() => searchParams.get("poolId"), [searchParams]);
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const [pools, setPools] = useState<SYesNoPool[]>([]);
  const [previous, setPrevious] = useState<string | undefined>(undefined);
  const [hasMore, setHasMore] = useState<boolean>(true);
  const limit = isMobile ? 10 : 16;

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

  useEffect(() => {
    if (pools && selectedPoolId !== null) {
      const poolElement = poolRefs.current.get(selectedPoolId);
      if (poolElement) {
        setTimeout(() => {
          poolElement.scrollIntoView({ behavior: "smooth", block: "start" });
        }, 50);
      }
    }
  }, [pools]);

  return (
    <div className="flex flex-col gap-y-1 w-full sm:w-4/5 md:w-11/12 lg:w-5/6 xl:w-4/5 mx-auto rounded-md p-3">
      {/* Pool Grid */}
      <InfiniteScroll
        dataLength={pools.length}
        next={fetchAndSetPools}
        hasMore={hasMore}
        loader={<SkeletonLoader count={5} />} // Adjust count as needed
        className="w-full flex flex-col min-h-full overflow-auto"
        style={{ height: "auto", overflow: "visible" }}
      >
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
          {pools.map((pool: SYesNoPool, index) => (
            computeDecay && pool.info.visible && info &&
              <div 
                key={index}
                ref={(el) => { poolRefs.current.set(pool.pool_id, el); }}
                className="bg-white dark:bg-slate-800 rounded-lg shadow-md p-3 hover:cursor-pointer border border-slate-200 dark:border-slate-700 hover:shadow-lg transition-all duration-200 ease-in-out"
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
