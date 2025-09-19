import { protocolActor } from "../actors/ProtocolActor";
import { useEffect, useMemo, useState } from "react";
import { v4 as uuidv4 } from 'uuid';
import { toCandid } from "../../utils/conversions/yesnochoice";
import { BallotInfo } from "../types";
import { PutBallotArgs } from "@/declarations/protocol/protocol.did";

export const useBallotPreview = (vote_id: string, ballot: BallotInfo) => {
  const [debouncedBallot, setDebouncedBallot] = useState(ballot);

  const args = useMemo(() : PutBallotArgs => {
    return {
      id: uuidv4(),
      vote_id,
      from_subaccount: [],
      amount: debouncedBallot.amount,
      choice_type: { YES_NO: toCandid(debouncedBallot.choice) },
    };
  }, [debouncedBallot, vote_id]);

  // @todo: why is return APY always 0 ?
  const { data: preview } = protocolActor.unauthenticated.useQueryCall({
    functionName: "preview_ballot",
    args: [ args ],
  });

  useEffect(() => {
    const handler = setTimeout(() => setDebouncedBallot(ballot), 100);
    return () => clearTimeout(handler);
  }, [ballot]);

  return (preview && "ok" in preview) ? preview.ok : undefined;
};
