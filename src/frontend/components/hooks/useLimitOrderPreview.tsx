import { protocolActor } from "../actors/ProtocolActor";
import { useEffect, useMemo, useState } from "react";
import { v4 as uuidv4 } from 'uuid';
import { toCandid, EYesNoChoice } from "../../utils/conversions/yesnochoice";
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
  if (preview && "ok" in preview) {
    // If there's a match, return it
    if (preview.ok.matching.length > 0) {
      return preview.ok.matching[0];
    }
    // If no match, return an empty position to show "No match" in the preview
    // We need to return a valid SPutPositionSuccess structure
    return {
      new: {
        YES_NO: {
          position_id: '',
          pool_id: pool_id,
          from: { owner: Principal.anonymous(), subaccount: [] },
          choice: debouncedPosition.choice === EYesNoChoice.Yes ? { YES: null } : { NO: null },
          amount: 0n,
          supply_index: 0,
          lock: [],
          dissent: 0,
          consent: 0,
          decay: 0,
          hotness: 0,
          foresight: {
            apr: { current: 0, potential: 0 },
            reward: 0n
          },
          timestamp: 0n,
          tx_id: 0n
        }
      },
      previous: []
    };
  }

  return undefined;
};
