import { protocolActor } from "../../actors/ProtocolActor";
import { useEffect, useState } from "react";
import { v4 as uuidv4 } from 'uuid';
import { toCandid } from "../../utils/conversions/yesnochoice";
import { BallotInfo } from "../types";

export const useBallotPreview = (vote_id: string, ballot: BallotInfo) => {
  const [debouncedBallot, setDebouncedBallot] = useState(ballot);
  const { data: preview, call: refreshPreview } = protocolActor.useQueryCall({
    functionName: "preview_ballot",
  });

  useEffect(() => {
    const handler = setTimeout(() => setDebouncedBallot(ballot), 100);
    return () => clearTimeout(handler);
  }, [ballot]);

  useEffect(() => {
    refreshPreview([
      {
        id: uuidv4(),
        vote_id,
        from_subaccount: [],
        amount: debouncedBallot.amount,
        choice_type: { YES_NO: toCandid(debouncedBallot.choice) },
      },
    ]);
  }, [debouncedBallot]);

  return (preview && "ok" in preview) ? preview.ok : undefined;
};
