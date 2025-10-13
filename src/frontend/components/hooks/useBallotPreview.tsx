import { protocolActor } from "../actors/ProtocolActor";
import { useEffect, useMemo, useState } from "react";
import { v4 as uuidv4 } from 'uuid';
import { toCandid } from "../../utils/conversions/yesnochoice";
import { BallotInfo } from "../types";
import { PutBallotPreview } from "@/declarations/protocol/protocol.did";

export const useBallotPreview = (vote_id: string, ballot: BallotInfo, with_supply_apy_impact: boolean) => {
  const [debouncedBallot, setDebouncedBallot] = useState(ballot);

  const args : PutBallotPreview = useMemo(() => {
    return {
      id: uuidv4(),
      vote_id,
      from_subaccount: [],
      amount: debouncedBallot.amount,
      choice_type: { YES_NO: toCandid(debouncedBallot.choice) },
      with_supply_apy_impact
    };
  }, [debouncedBallot, vote_id, with_supply_apy_impact]);

  const { data: preview } = protocolActor.unauthenticated.useQueryCall({
    functionName: "preview_ballot",
    args: [ args ],
    onError: (error) => {
      console.error("Error fetching use ballot preview:", error);
    },
    onSuccess: (data) => {
      console.log("Successfully fetched use ballot preview:", data);
    }
  });

  useEffect(() => {
    const handler = setTimeout(() => setDebouncedBallot(ballot), 100);
    return () => clearTimeout(handler);
  }, [ballot]);

  return (preview && "ok" in preview) ? preview.ok : undefined;
};
