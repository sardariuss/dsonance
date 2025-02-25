import { createContext, useContext, useMemo } from "react";
import { ckBtcActor } from "../actors/CkBtcActor";
import { useAuth } from "@ic-reactor/react";
import { Account__1 } from "@/declarations/ck_btc/ck_btc.did";
import { canisterId as protocolCanisterId } from "../../declarations/protocol"
import { Principal } from "@dfinity/principal";

interface AllowanceContextType {
  btcAllowance: bigint | undefined;
  refreshBtcAllowance: () => void;
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

  const { call: refresh, data: allowance } = ckBtcActor.useQueryCall({
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
    refresh();
  };

  return (
    <AllowanceContext.Provider value={{ btcAllowance: allowance?.allowance, refreshBtcAllowance: refreshBtcAllowance }}>
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

