import { protocolActor } from "../actors/ProtocolActor";
import { useEffect, useMemo, useState } from "react";
import { v4 as uuidv4 } from 'uuid';
import { toCandid } from "../../utils/conversions/yesnochoice";
import { PositionInfo } from "../types";
import { PutPositionPreview } from "@/declarations/protocol/protocol.did";

export const usePositionPreview = (pool_id: string, position: PositionInfo, with_supply_apy_impact: boolean) => {
  const [debouncedPosition, setDebouncedPosition] = useState(position);

  const args : PutPositionPreview = useMemo(() => {
    return {
      id: uuidv4(),
      pool_id,
      from_subaccount: [],
      amount: debouncedPosition.amount,
      choice_type: { YES_NO: toCandid(debouncedPosition.choice) },
      with_supply_apy_impact,
      origin: { FROM_WALLET: null }
    };
  }, [debouncedPosition, pool_id, with_supply_apy_impact]);

  const { data: preview } = protocolActor.unauthenticated.useQueryCall({
    functionName: "preview_position",
    args: [ args ],
    onError: (error) => {
      console.error("Error fetching use position preview:", error);
    },
    onSuccess: (data) => {
      console.log("Successfully fetched use position preview:", data);
    }
  });

  useEffect(() => {
    const handler = setTimeout(() => setDebouncedPosition(position), 100);
    return () => clearTimeout(handler);
  }, [position]);

  return (preview && "ok" in preview) ? preview.ok : undefined;
};
