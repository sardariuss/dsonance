import { useParams } from "react-router-dom";
import BallotView from "./BallotView";
import { fromNullable } from "@dfinity/utils";
import { protocolActor } from "../../actors/ProtocolActor";
import { useProtocolContext } from "../ProtocolContext";
import { useEffect } from "react";

const Ballot = () => {

    const { id } = useParams();

    if (!id) {
        return <span>Invalid ballot</span>;
    }

    const { data: ballot } = protocolActor.useQueryCall({
        functionName: 'find_ballot',
        args: [id],
    });

    const { info, refreshInfo } = useProtocolContext();

    const actualBallot = ballot ? fromNullable(ballot) : undefined;

    useEffect(() => {
        refreshInfo();
    }
    , [id]);

    return (
        actualBallot && info ?
            <div className="flex flex-col items-center bg-slate-50 dark:bg-slate-850 py-6 sm:p-6 sm:my-6 sm:rounded-lg shadow-md w-full sm:w-4/5 md:w-3/4 lg:w-2/3">
                <BallotView ballot={actualBallot} now={info?.current_time}/>
            </div> 
        : actualBallot === undefined ? 
            <span>Ballot not found</span>
        : 
            <span>Loading...</span>
    );
}

export default Ballot;