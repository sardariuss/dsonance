import { useParams } from "react-router-dom";
import VoteView, { VoteViewSkeleton } from "./VoteView";
import { backendActor } from "../actors/BackendActor";
import { fromNullable } from "@dfinity/utils";

const Vote = () => {

    const { id } = useParams();

    if (!id) {
        return <span>Invalid vote</span>;
    }

    const { data: vote, loading } = backendActor.useQueryCall({
        functionName: 'get_vote',
        args: [{ vote_id: id }],
    });

    const actualVote = vote ? fromNullable(vote) : undefined;

    return (
        <div className="flex flex-col items-center bg-slate-50 dark:bg-slate-850 py-6 sm:p-6 sm:my-6 sm:rounded-lg shadow-md w-full sm:w-4/5 md:w-3/4 lg:w-2/3">
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