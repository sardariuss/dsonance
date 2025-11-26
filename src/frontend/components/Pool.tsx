import { useParams } from "react-router-dom";
import PoolView, { PoolViewSkeleton } from "./PoolView";
import { fromNullable } from "@dfinity/utils";
import { useEffect, useMemo } from "react";
import { backendActor } from "./actors/BackendActor";

const Pool = () => {

    const { id } = useParams();

    if (!id) {
        return <span>Invalid pool</span>;
    }

    const { data: pool, call: refreshPool, loading } = backendActor.unauthenticated.useQueryCall({
        functionName: 'get_pool',
        args: [{ pool_id: id }],
    });

    // Force a refresh of the pool on navigation
    useEffect(() => {
        refreshPool();
    }
    , [id]);
    
    const actualPool = useMemo(() => pool ? fromNullable(pool) : undefined, [pool]);

    return (
        <div className="flex flex-col items-center bg-slate-50 dark:bg-slate-850 py-6 sm:p-6 sm:my-6 sm:rounded-lg shadow-md w-full sm:w-4/5 md:w-11/12 lg:w-5/6 xl:w-4/5 mx-auto">
        {
            loading ? 
                <PoolViewSkeleton/> :
            actualPool && actualPool.info.visible ?
                <PoolView pool={actualPool}/>
            : 
                <span>Pool not found</span>
        }
        </div>
    );
}

export default Pool;