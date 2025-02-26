import { SYesNoVote } from "@/declarations/backend/backend.did";
import { EYesNoChoice } from "./yesnochoice";
import { BallotInfo } from "@/frontend/components/types";

export type VoteDetails = {
  yes: number;
  no: number;
  total: number;
  cursor: number | undefined;
};

export const compute_vote_details = (vote: SYesNoVote, compute_decay: (time: bigint) => number): VoteDetails => {
  const aggregate = vote.aggregate.current.data;
  const decay = compute_decay(vote.date);
  const yes = aggregate.current_yes.DECAYED / decay;
  const no = aggregate.current_no.DECAYED / decay;
  const total = yes + no;
  const cursor = total === 0 ? undefined : yes / total;
  return { total, yes, no, cursor };
}

export const add_ballot = (details: VoteDetails, ballot: BallotInfo) : VoteDetails => {
  const total = details.total + Number(ballot.amount);
  const cursor = total === 0 ? undefined : (details.yes + (ballot.choice === EYesNoChoice.Yes ? Number(ballot.amount) : 0)) / total;
  return { ...details, total, cursor };
}

export const deduce_ballot = (details: VoteDetails, live_cursor: number) : BallotInfo => {
  const { total, yes, cursor } = details;

  const choice = (cursor === undefined || live_cursor > cursor) ? EYesNoChoice.Yes : EYesNoChoice.No;
  const amount = BigInt(Math.floor(choice === EYesNoChoice.No ? (yes / live_cursor - total) : ((live_cursor * total - yes) / (1 - live_cursor))));

  return { choice, amount };
}
