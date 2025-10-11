import { createContext, useContext } from "react";
import { useAuth } from "@nfid/identitykit/react";
import { protocolActor } from "../actors/ProtocolActor";
import { ProtocolInfo, SParameters, LendingIndex } from "@/declarations/protocol/protocol.did";
import { compute_decay } from "../../utils/decay";
import { durationToNs } from "../../utils/conversions/duration";

// Timeline type until it's generated in the .did file
interface TimedData<T> {
  timestamp: bigint;
  data: T;
}

interface STimeline<T> {
  current: TimedData<T>;
  history: TimedData<T>[];
  minIntervalNs: bigint;
}

interface ProtocolContextType {
  parameters: SParameters | undefined;
  info: ProtocolInfo | undefined;
  lendingIndexTimeline: STimeline<LendingIndex> | undefined;
  refreshParameters: () => void;
  refreshInfo: () => void;
  refreshLendingIndex: () => void;
  computeDecay?: (time: bigint) => number;
}

const ProtocolContext = createContext<ProtocolContextType | undefined>(undefined);

export const ProtocolProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {

  const { data: parameters, call: refreshParameters } = protocolActor.unauthenticated.useQueryCall({
      functionName: "get_parameters",
      args: [],
  });

  const { data: info, call: refreshInfo } = protocolActor.unauthenticated.useQueryCall({
      functionName: "get_info",
      args: [],
  });

  const { data: lendingIndexTimeline, call: refreshLendingIndex } = protocolActor.unauthenticated.useQueryCall({
      functionName: "get_lending_index",
      args: [],
  });

  return (
    <ProtocolContext.Provider value={{
      parameters,
      info,
      lendingIndexTimeline,
      refreshParameters,
      refreshInfo,
      refreshLendingIndex,
      computeDecay: parameters && info ? (time: bigint) => {
        return compute_decay(info.genesis_time, durationToNs(parameters.ballot_half_life), time);
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

