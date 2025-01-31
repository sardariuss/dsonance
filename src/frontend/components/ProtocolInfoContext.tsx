import { createContext, useContext } from "react";
import { useAuth } from "@ic-reactor/react";
import { protocolActor } from "../actors/ProtocolActor";
import { DecayParameters, ProtocolParameters, STimeline_1 } from "@/declarations/protocol/protocol.did";

interface ProtocolInfoContextType {
  info: {
    protocolParameters: ProtocolParameters | undefined;
    totalLocked: STimeline_1 | undefined;
    amountMinted: STimeline_1 | undefined;
    currentTime: bigint | undefined;
    currentDecay: number | undefined;
    decayParams: DecayParameters | undefined
  };
  refreshInfo: () => void;
}

const ProtocolInfoContext = createContext<ProtocolInfoContextType | undefined>(undefined);

export const ProtocolProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {

  const { identity } = useAuth({});

  if(!identity) {
    return null;
  };

  const { data: protocolParameters, call: refreshProtocolParameters } = protocolActor.useQueryCall({
      functionName: "get_protocol_parameters",
      args: [],
  });

  const { data: totalLocked, call: refreshTotalLocked } = protocolActor.useQueryCall({
      functionName: "get_total_locked",
      args: [],
  });

  const { data: amountMinted, call: refreshAmountMinted } = protocolActor.useQueryCall({
      functionName: "get_amount_minted",
      args: [],
  });

  const { data: currentTime, call: refreshCurrentTime } = protocolActor.useQueryCall({
    functionName: "get_time",
  });

  const { data: currentDecay, call: refreshCurrentDecay } = protocolActor.useQueryCall({
    functionName: "current_decay",
  });

  const { data: decayParams, call: refreshDecayParams } = protocolActor.useQueryCall({
    functionName: "decay_params",
  });

  const refreshInfo = () => {
    refreshProtocolParameters();
    refreshTotalLocked();
    refreshAmountMinted();
    refreshCurrentTime();
    refreshCurrentDecay();
    refreshDecayParams();
  };

  return (
    <ProtocolInfoContext.Provider value={{ info : { protocolParameters, totalLocked, amountMinted, currentTime, currentDecay, decayParams }, refreshInfo }}>
      {children}
    </ProtocolInfoContext.Provider>
  );
};

export const useProtocolInfoContext = (): ProtocolInfoContextType => {
  const context = useContext(ProtocolInfoContext);
  if (context === undefined) {
    throw new Error("useProtocol must be used within an ProtocolProvider");
  }
  return context;
};

