import { createContext, useContext, useMemo } from "react";
import { ckBtcActor } from "../actors/CkBtcActor";
import { useAuth } from "@ic-reactor/react";
import { Account__1 } from "@/declarations/ck_btc/ck_btc.did";
import { canisterId as protocolCanisterId } from "../../declarations/protocol"
import { Principal } from "@dfinity/principal";
import { ckUsdtActor } from "../actors/CkUsdtActor";

interface AllowanceContextType {
  btcAllowance: bigint | undefined;
  dsnAllowance: bigint | undefined;
  refreshBtcAllowance: () => void;
  refreshDsnAllowance: () => void;
}

const AllowanceContext = createContext<AllowanceContextType | undefined>(undefined);

export const WalletProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {

  const { identity } = useAuth({});

  if (!identity) {
    return null;
  };

  const account : Account__1 = useMemo(() => ({
    owner: identity.getPrincipal(),
    subaccount: []
  }), [identity]);

  const { call: btcRefresh, data: btcAllowance } = ckBtcActor.useQueryCall({
    functionName: 'icrc2_allowance',
    args: [{
      account,
      spender: {
        owner: Principal.fromText(protocolCanisterId),
        subaccount: []
      }
    }]
  });

  const refreshBtcAllowance = () => {
    btcRefresh();
  };

  const { call: dsnRefresh, data: dsnAllowance } = ckUsdtActor.useQueryCall({
    functionName: 'icrc2_allowance',
    args: [{
      account,
      spender: {
        owner: Principal.fromText(protocolCanisterId),
        subaccount: []
      }
    }]
  });

  const refreshDsnAllowance = () => {
    dsnRefresh();
  }

  return (
    <AllowanceContext.Provider value={{ btcAllowance: btcAllowance?.allowance, dsnAllowance: dsnAllowance?.allowance, refreshBtcAllowance, refreshDsnAllowance }}>
      {children}
    </AllowanceContext.Provider>
  );
};

export const useAllowanceContext = (): AllowanceContextType => {
  const context = useContext(AllowanceContext);
  if (context === undefined) {
    throw new Error("useWallet must be used within an WalletProvider");
  }
  return context;
};

