import { createContext, useContext } from "react";
import { useAuth } from "@ic-reactor/react";
import { protocolActor } from "../../actors/ProtocolActor";
import { SProtocolInfo, SProtocolParameters } from "@/declarations/protocol/protocol.did";
import { compute_decay } from "../../utils/decay";
import { durationToNs } from "../../utils/conversions/duration";

interface ProtocolContextType {
  parameters: SProtocolParameters | undefined;
  info: SProtocolInfo | undefined;
  refreshParameters: () => void;
  refreshInfo: () => void;
  computeDecay?: (time: bigint) => number;
}

const ProtocolContext = createContext<ProtocolContextType | undefined>(undefined);

export const ProtocolProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {

  const { identity } = useAuth({});

  if(!identity) {
    return null;
  };

  const { data: parameters, call: refreshParameters } = protocolActor.useQueryCall({
      functionName: "get_parameters",
      args: [],
  });

  const { data: info, call: refreshInfo } = protocolActor.useQueryCall({
      functionName: "get_info",
      args: [],
  });

  return (
    <ProtocolContext.Provider value={{ 
      parameters, 
      info, 
      refreshParameters, 
      refreshInfo,
      computeDecay: parameters ? (time: bigint) => {
        return compute_decay(parameters.decay.time_init, durationToNs(parameters.decay.half_life), time);
      } : undefined
    }}>
      {children}
    </ProtocolContext.Provider>
  );
};

export const useProtocolContext = (): ProtocolContextType => {
  const context = useContext(ProtocolContext);
  if (context === undefined) {
    throw new Error("useProtocol must be used within an ProtocolProvider");
  }
  return context;
};

