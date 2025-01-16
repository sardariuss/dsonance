import { useParams } from "react-router-dom";
import VoteView from "./VoteView";
import { backendActor } from "../actors/BackendActor";
import { fromNullable } from "@dfinity/utils";

const Vote = () => {

    const { id } = useParams();

    if (!id) {
        return <span>Invalid vote</span>;
    }

    const { data: vote } = backendActor.useQueryCall({
        functionName: 'get_vote',
        args: [{ vote_id: id }],
    });

    const actualVote = vote ? fromNullable(vote) : undefined;

    return (
        actualVote && <div className="flex flex-col border-x border-t dark:border-gray-700 bg-white dark:bg-slate-900 w-2/3">
            <VoteView vote={actualVote} selected={id} setSelected={()=>{}}/>
        </div>
    );
}

export default Vote;