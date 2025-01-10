import { useParams } from "react-router-dom";
import VoteView from "./VoteView";
import { backendActor } from "../actors/BackendActor";
import { fromNullable } from "@dfinity/utils";
import { protocolActor } from "../actors/ProtocolActor";
import ChoiceView from "./ChoiceView";

const Vote = () => {

    const { id } = useParams();

    if (!id) {
        return <span>Invalid vote</span>;
    }

    const { data: vote } = backendActor.useQueryCall({
        functionName: 'get_vote',
        args: [{ vote_id: id }],
    });

    const { data: ballots } = protocolActor.useQueryCall({
        functionName: "get_vote_ballots",
        args: [id],
    });

    const actualVote = vote ? fromNullable(vote) : undefined;

    // @todo: the list of ballots is very ugly
    return (
        actualVote && <div className="flex flex-col">
            <VoteView vote={actualVote} selected={id} setSelected={()=>{}}/>
            <ul>
                {
                    ballots && ballots.map((ballot, index) => (
                        <li key={index} className="flex flex-row space-x-1">
                            <ChoiceView ballot={ballot}/>
                            <div>{ballot.YES_NO.amount.toString()}</div>
                        </li>
                    ))
                }
            </ul>
        </div>
    );
}

export default Vote;