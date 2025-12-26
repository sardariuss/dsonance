import { SYesNoPool } from "@/declarations/backend/backend.did";
import PutPosition from "./PutPosition";
import PoolPositions from "./PoolPositions";
import PoolLimitOrders from "./PoolLimitOrders";
import { useEffect, useMemo, useState } from "react";
import { EYesNoChoice } from "../utils/conversions/yesnochoice";
import CdvChart from "./charts/CdvChart";
import { PositionInfo } from "./types";
import { add_position, compute_pool_details } from "../utils/conversions/pooldetails";
import { useProtocolContext } from "./context/ProtocolContext";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY, PREVIEW_POOL_IMPACT } from "../constants";
import PoolFigures, { PoolFiguresSkeleton } from "./PoolFigures";
import { interpolate_now, map_timeline, get_current } from "../utils/timeline";
import ConsensusChart from "./charts/ConsensusChart";
import { protocolActor } from "./actors/ProtocolActor";
import LockChart from "./charts/LockChart";
import { usePositionPreview } from "./hooks/usePositionPreview";
import { useLimitOrderPreview } from "./hooks/useLimitOrderPreview";
import { DurationUnit } from "../utils/conversions/durationUnit";
import IntervalPicker from "./charts/IntervalPicker";
import ChartToggle, { ChartType } from "./charts/ChartToggle";
import { createThumbnailUrl } from "../utils/thumbnail";
import PoolSlider from "./PoolSlider";

interface PoolViewProps {
  pool: SYesNoPool;
}

const PoolView: React.FC<PoolViewProps> = ({ pool }) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  const [position, setPosition] = useState<PositionInfo>({ choice: EYesNoChoice.Yes, amount: 0n });
  const [duration, setDuration] = useState<DurationUnit | undefined>(DurationUnit.MONTH);
  const [selectedChart, setSelectedChart] = useState<ChartType>(ChartType.Consensus);

  // Calculate initial consensus from pool
  const initialConsensus = useMemo(() => {
    const currentAggregate = get_current(pool.aggregate).data;
    const totalYes = Number(currentAggregate.total_yes);
    const totalNo = Number(currentAggregate.total_no);
    const total = totalYes + totalNo;

    if (total === 0) {
      return 50; // Default to 50% if no votes yet
    }

    const consensus = (totalYes / total) * 100;
    return Math.round(consensus); // Round to integer
  }, [pool.aggregate]);

  const [limitConsensus, setLimitConsensus] = useState<number>(initialConsensus);

  const { data: poolPositions } = protocolActor.unauthenticated.useQueryCall({
    functionName: "get_pool_positions",
    args: [pool.pool_id],
  });

  const { computeDecay, info } = useProtocolContext();

  const positionPreview = usePositionPreview(pool.pool_id, position, true);
  const positionPreviewWithoutImpact = usePositionPreview(pool.pool_id, position, false);
  const limitOrderPreview = useLimitOrderPreview(pool.pool_id, position, limitConsensus);

  // TODO: remove redundant code
  const { poolDetails, liveDetails } = useMemo(() => {
    if (computeDecay === undefined || info === undefined) {
      return { poolDetails: undefined, liveDetails: undefined };
    }
  
    const poolDetails = compute_pool_details(pool, computeDecay(info.current_time));
    const liveDetails = position ? add_position(poolDetails, position) : poolDetails;
  
    return { poolDetails, liveDetails };
  }, [pool, computeDecay, info, position]);
  
  const consensusTimeline = useMemo(() => {
    if (liveDetails === undefined || info === undefined) {
      return undefined;
    }
  
    let timeline = interpolate_now(
      map_timeline(pool.aggregate, (aggregate) => 
        Number(aggregate.total_yes) / Number(aggregate.total_yes + aggregate.total_no)
      ),
      info.current_time
    );
  
    if (liveDetails.cursor !== undefined && PREVIEW_POOL_IMPACT) {
      timeline = {
        history: [...timeline.history, timeline.current],
        current: {
          timestamp: info.current_time,
          data: liveDetails.cursor,
        },
      } 
    }
  
    return timeline;
  }, [liveDetails]);
    
  const resetPool = () => {
    setPosition({ choice: EYesNoChoice.Yes, amount: 0n });
    setLimitConsensus(initialConsensus);
  }

  useEffect(() => {
    resetPool();
  }, [pool, initialConsensus]);

  const thumbnail = useMemo(() => createThumbnailUrl(pool.info.thumbnail), [pool]);

  return (
    <div className={`flex flex-col items-center ${isMobile ? "px-3 py-1 w-full" : "py-3 w-full"}`}>
      
      {/* Mobile Layout: Keep original structure */}
      <div className="block md:hidden w-full">
        {/* Top Row: Image and Pool Text */}
        <div className="w-full flex flex-row items-center gap-4 mb-2">
          {/* Placeholder Image */}
          <img 
            className="w-16 h-16 bg-contain bg-no-repeat bg-center rounded-md self-start"
            src={thumbnail}
          />
          {/* Pool Text */}
          <div className="flex-grow text-gray-800 dark:text-gray-200 text-lg font-bold">
            {pool.info.text}
          </div>
        </div>

        {/* Pool Details */}
        {poolDetails !== undefined ? 
          <PoolFigures timestamp={pool.date} poolDetails={poolDetails} position={position} tvl={pool.tvl} /> :
          <PoolFiguresSkeleton />
        }
      </div>

      {/* Desktop Layout: Main content + Sidebar */}
      <div className="hidden md:flex w-full gap-8">
        {/* Main Content Panel */}
        <div className="flex-1 flex flex-col items-center">
          {/* Top Row: Image and Pool Text */}
          <div className="w-full flex flex-row items-center gap-4 mb-4">
            {/* Placeholder Image */}
            <img 
              className="w-16 h-16 bg-contain bg-no-repeat bg-center rounded-md self-start"
              src={thumbnail}
            />
            {/* Pool Text */}
            <div className="flex-grow text-gray-800 dark:text-gray-200 text-lg max-w-none font-bold">
              {pool.info.text}
            </div>
          </div>

          {/* Pool Details */}
          {poolDetails !== undefined ? 
            <PoolFigures timestamp={pool.date} poolDetails={poolDetails} position={position} tvl={pool.tvl} /> :
            <PoolFiguresSkeleton />
          }

          {/* Charts and Positions for Desktop */}
          {poolDetails !== undefined && pool.pool_id !== undefined && (
            <div className="flex flex-col space-y-4 w-full">
              {poolPositions && poolPositions.length > 0 &&
                <div className="w-full flex flex-col items-center justify-between space-y-2">
                  <div className="w-full h-[250px]">
                    {selectedChart === ChartType.CDV ?
                      (poolDetails.total > 0 && 
                        <CdvChart pool={pool} position={position} durationWindow={duration} />
                      )
                      : selectedChart === ChartType.Consensus ?
                      (consensusTimeline !== undefined && liveDetails?.cursor !== undefined &&
                        <ConsensusChart timeline={consensusTimeline} format_value={(value: number) => (value * 100).toFixed(0) + "%"} durationWindow={duration}/> 
                      ) 
                      : selectedChart === ChartType.TVL ?
                      (poolPositions !== undefined && 
                        <LockChart positions={poolPositions.map(position => position.YES_NO)} positionPreview={PREVIEW_POOL_IMPACT ? positionPreview : undefined} durationWindow={duration}/>
                      )
                      : <></>
                    }
                  </div>
                  <div className="flex flex-row justify-between items-center w-full">
                    <IntervalPicker duration={duration} setDuration={setDuration} availableDurations={[DurationUnit.WEEK, DurationUnit.MONTH, DurationUnit.YEAR]} />
                    <ChartToggle selected={selectedChart} setSelected={setSelectedChart}/>
                  </div>
                </div>
              }
              { PREVIEW_POOL_IMPACT && <PoolSlider
                id={pool.pool_id}
                position={position}
                setPosition={setPosition}
                poolDetails={poolDetails}
              /> }
              <PoolLimitOrders poolId={pool.pool_id} />
              <PoolPositions poolId={pool.pool_id} />
            </div>
          )}
        </div>

        {/* PutPosition Sidebar */}
        <div className="w-96 flex-shrink-0 sticky top-24 self-start">
          {poolDetails !== undefined && pool.pool_id !== undefined && (
            <PutPosition
              id={pool.pool_id}
              position={position}
              setPosition={setPosition}
              positionPreview={positionPreview?.new.YES_NO}
              positionPreviewWithoutImpact={positionPreviewWithoutImpact?.new.YES_NO}
              limitOrderPreview={limitOrderPreview?.new.YES_NO}
              pool={pool}
              limitConsensus={limitConsensus}
              setLimitConsensus={setLimitConsensus}
              initialConsensus={initialConsensus}
            />
          )}
        </div>
      </div>

      {/* Mobile Layout: Charts and Positions */}
      <div className="block md:hidden w-full">
        {poolDetails !== undefined && pool.pool_id !== undefined ? 
          <div className="flex flex-col space-y-4 items-center w-full">
            {poolPositions && poolPositions.length > 0 &&
              <div className="w-full flex flex-col items-center justify-between space-y-2">
                <div className="w-full h-[200px]">
                  {selectedChart === ChartType.CDV ?
                    (poolDetails.total > 0 && <CdvChart pool={pool} position={position} durationWindow={duration} />)
                    : selectedChart === ChartType.Consensus ?
                    (consensusTimeline !== undefined && liveDetails?.cursor !== undefined &&
                      <ConsensusChart timeline={consensusTimeline} format_value={(value: number) => (value * 100).toFixed(0) + "%"} durationWindow={duration}/> 
                    ) 
                    : selectedChart === ChartType.TVL ?
                    (poolPositions !== undefined && <LockChart positions={poolPositions.map(position => position.YES_NO)} positionPreview={positionPreview} durationWindow={duration}/>)
                    : <></>
                  }
                </div>
                <div className="flex flex-row justify-between items-center w-full">
                  <IntervalPicker duration={duration} setDuration={setDuration} availableDurations={[DurationUnit.WEEK, DurationUnit.MONTH, DurationUnit.YEAR]} />
                  <ChartToggle selected={selectedChart} setSelected={setSelectedChart}/>
                </div>
              </div>
            }
            { PREVIEW_POOL_IMPACT && <PoolSlider
              id={pool.pool_id}
              position={position}
              setPosition={setPosition}
              poolDetails={poolDetails}
            />}
            <PutPosition
              id={pool.pool_id}
              position={position}
              setPosition={setPosition}
              positionPreview={positionPreview?.new.YES_NO}
              positionPreviewWithoutImpact={positionPreviewWithoutImpact?.new.YES_NO}
              limitOrderPreview={limitOrderPreview?.new.YES_NO}
              pool={pool}
              limitConsensus={limitConsensus}
              setLimitConsensus={setLimitConsensus}
              initialConsensus={initialConsensus}
            />
            <PoolLimitOrders poolId={pool.pool_id} />
            <PoolPositions poolId={pool.pool_id} />
          </div> : 
        <div className="flex flex-col space-y-2 items-center w-full">
          <div className="w-full h-64 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"/>
          <div className="w-full h-32 bg-gray-300 dark:bg-gray-700 rounded animate-pulse"/>
        </div>
        }
      </div>
    </div>
  );
  
};

export default PoolView;

export const PoolViewSkeleton: React.FC = () => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  return (
    <div className={`flex flex-col items-center ${isMobile ? "px-3 py-1 w-full" : "py-3 w-full"}`}>
      
      {/* Mobile Layout: Keep original structure */}
      <div className="block md:hidden w-full">
        {/* Top Row: Image and Pool Text */}
        <div className="w-full flex flex-row items-center gap-4 mb-4">
          <div className="w-20 h-20 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
          <div className="flex-grow h-6 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
        </div>

        {/* Pool Details Skeleton */}
        <PoolFiguresSkeleton />
      </div>

      {/* Desktop Layout: Main content + Sidebar */}
      <div className="hidden md:flex w-full gap-8">
        {/* Main Content Panel */}
        <div className="flex-1 flex flex-col space-y-4 items-center">
          {/* Top Row: Image and Pool Text */}
          <div className="w-full flex flex-row items-center gap-4 mb-4">
            <div className="w-20 h-20 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
            <div className="flex-grow h-6 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
          </div>

          {/* Pool Details Skeleton */}
          <PoolFiguresSkeleton />

          {/* Charts and Positions Skeleton for Desktop */}
          <div className="flex flex-col space-y-4 w-full">
            <div className="w-full flex flex-col items-center justify-between space-y-2">
              <div className="w-full h-[400px] bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
              <div className="flex flex-row justify-between items-center w-full">
                <div className="w-1/3 h-8 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
                <div className="w-1/3 h-8 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
              </div>
            </div>
            <div className="w-full h-32 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
          </div>
        </div>

        {/* PutPosition Sidebar Skeleton */}
        <div className="w-96 flex-shrink-0 sticky top-24 self-start">
          <div className="w-full h-64 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
        </div>
      </div>

      {/* Mobile Layout: Charts and Positions */}
      <div className="block md:hidden w-full">
        <div className="flex flex-col space-y-2 items-center w-full">
          <div className="w-full h-[200px] bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
          <div className="flex flex-row justify-between items-center w-full">
            <div className="w-1/3 h-8 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
            <div className="w-1/3 h-8 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
          </div>
          <div className="w-full h-12 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
          <div className="w-full h-32 bg-gray-300 dark:bg-gray-700 rounded animate-pulse" />
        </div>
      </div>
    </div>
  );
}
