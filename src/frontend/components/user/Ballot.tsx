import { useParams } from "react-router-dom";
import BallotView, { BallotViewSkeleton } from "./BallotView";
import { fromNullable } from "@dfinity/utils";
import { protocolActor } from "../actors/ProtocolActor";
import { useProtocolContext } from "../context/ProtocolContext";
import { useEffect, useMemo } from "react";

const Ballot = () => {

    const { id } = useParams();

    if (!id) {
        return <span>Invalid ballot</span>;
    }

    const { data: ballot, call: refreshBallot, loading } = protocolActor.unauthenticated.useQueryCall({
        functionName: 'find_ballot',
        args: [id],
    });

    const { info, refreshInfo } = useProtocolContext();

    // Force a refresh of the ballot on navigation (otherwise the ballot is not up to date after a vote)
    useEffect(() => {
        refreshBallot();
        refreshInfo();
    }
    , [id]);

    const actualBallot = useMemo(() => ballot ? fromNullable(ballot) : undefined, [ballot]);

    return (
        <div className="flex flex-col items-center bg-slate-50 dark:bg-slate-850 py-6 sm:p-6 sm:my-6 sm:rounded-lg shadow-md w-full sm:w-4/5 md:w-3/4 lg:w-2/3">
        { 
            loading ? 
                <BallotViewSkeleton/> :
            actualBallot && info ?
                <BallotView ballot={actualBallot} now={info?.current_time}/>
            :
            <span>Ballot not found</span> 
        }
        </div>
    );
}

export default Ballot;