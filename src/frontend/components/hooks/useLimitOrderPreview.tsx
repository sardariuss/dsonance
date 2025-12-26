import { protocolActor } from "../actors/ProtocolActor";
import { useEffect, useMemo, useState } from "react";
import { v4 as uuidv4 } from 'uuid';
import { toCandid } from "../../utils/conversions/yesnochoice";
import { PositionInfo } from "../types";
import { PreviewLimitOrderArgs, SPutPositionSuccess } from "@/declarations/protocol/protocol.did";
import { Principal } from "@dfinity/principal";

export const useLimitOrderPreview = (
  pool_id: string,
  position: PositionInfo,
  limitConsensus: number
): SPutPositionSuccess | undefined => {
  const [debouncedPosition, setDebouncedPosition] = useState(position);
  const [debouncedConsensus, setDebouncedConsensus] = useState(limitConsensus);

  const args: PreviewLimitOrderArgs = useMemo(() => {
    return {
      order_id: uuidv4(),
      pool_id,
      choice_type: { YES_NO: toCandid(debouncedPosition.choice) },
      amount: debouncedPosition.amount,
      limit_consensus: debouncedConsensus / 100, // Convert from percentage (0-100) to decimal (0-1)
      from: {
        owner: Principal.anonymous(),
        subaccount: []
      },
      from_origin: { FROM_WALLET: null }
    };
  }, [debouncedPosition, debouncedConsensus, pool_id]);

  const { data: preview } = protocolActor.unauthenticated.useQueryCall({
    functionName: "preview_limit_order",
    args: [args],
    onError: (error) => {
      console.error("Error fetching limit order preview:", error);
    },
    onSuccess: (data) => {
      console.log("Successfully fetched limit order preview:", data);
    }
  });

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedPosition(position);
      setDebouncedConsensus(limitConsensus);
    }, 100);
    return () => clearTimeout(handler);
  }, [position, limitConsensus]);

  // Extract the matching field from the result
  if (preview && "ok" in preview && preview.ok.matching.length > 0) {
    return preview.ok.matching[0];
  }

  return undefined;
};
