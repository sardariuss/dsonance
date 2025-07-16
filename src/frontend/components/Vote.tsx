import { useParams } from "react-router-dom";
import VoteView, { VoteViewSkeleton } from "./VoteView";
import { backendActor } from "../actors/BackendActor";
import { fromNullable } from "@dfinity/utils";
import { useEffect, useMemo } from "react";

const Vote = () => {

    const { id } = useParams();

    if (!id) {
        return <span>Invalid vote</span>;
    }

    const { data: vote, call: refreshVote, loading } = backendActor.useQueryCall({
        functionName: 'get_vote',
        args: [{ vote_id: id }],
    });

    // Force a refresh of the vote on navigation
    useEffect(() => {
        refreshVote();
    }
    , [id]);
    
    const actualVote = useMemo(() => vote ? fromNullable(vote) : undefined, [vote]);

    return (
        <div className="flex flex-col items-center bg-slate-50 dark:bg-slate-850 py-6 sm:p-6 sm:my-6 sm:rounded-lg shadow-md w-full max-w-7xl mx-auto">
        {
            loading ? 
                <VoteViewSkeleton/> :
            actualVote && actualVote.info.visible ?
                <VoteView vote={actualVote}/>
            : 
                <span>Vote not found</span>
        }
        </div>
    );
}

export default Vote;