import { createContext, useContext, useMemo } from "react";
import { ckBtcActor } from "../actors/CkBtcActor";
import { useAuth } from "@ic-reactor/react";
import { Account } from "@/declarations/ck_btc/ck_btc.did";
import { canisterId as protocolCanisterId } from "../../declarations/protocol"
import { Principal } from "@dfinity/principal";
import { ckUsdtActor } from "../actors/CkUsdtActor";

interface AllowanceContextType {
  btcAllowance: bigint | undefined;
  usdtAllowance: bigint | undefined;
  refreshBtcAllowance: () => void;
  refreshUsdtAllowance: () => void;
}

const AllowanceContext = createContext<AllowanceContextType | undefined>(undefined);

export const WalletProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {

  const { identity } = useAuth({});

  if (!identity) {
    return null;
  };

  const account : Account = useMemo(() => ({
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

  const { call: usdtRefresh, data: usdtAllowance } = ckUsdtActor.useQueryCall({
    functionName: 'icrc2_allowance',
    args: [{
      account,
      spender: {
        owner: Principal.fromText(protocolCanisterId),
        subaccount: []
      }
    }]
  });

  const refreshUsdtAllowance = () => {
    usdtRefresh();
  }

  return (
    <AllowanceContext.Provider value={{ btcAllowance: btcAllowance?.allowance, usdtAllowance: usdtAllowance?.allowance, refreshBtcAllowance, refreshUsdtAllowance }}>
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

