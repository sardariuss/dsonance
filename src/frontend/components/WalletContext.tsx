import { createContext, useContext } from "react";
import { ckBtcActor } from "../actors/CkBtcActor";
import { useAuth } from "@ic-reactor/react";

interface WalletContextType {
  btcBalance: bigint | undefined;
  refreshBtcBalance: () => void;
}

const WalletContext = createContext<WalletContextType | undefined>(undefined);

export const WalletProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {

  const { identity } = useAuth({});

  if(!identity) {
    return null;
  };

  const { call: refresh, data: btcBalance } = ckBtcActor.useQueryCall({
    functionName: 'icrc1_balance_of',
    args: [{
      owner: identity.getPrincipal(),
      subaccount: []
    }]
  });

  const refreshBtcBalance = () => {
    refresh();
  };

  return (
    <WalletContext.Provider value={{ btcBalance: btcBalance, refreshBtcBalance: refreshBtcBalance }}>
      {children}
    </WalletContext.Provider>
  );
};

export const useWalletContext = (): WalletContextType => {
  const context = useContext(WalletContext);
  if (context === undefined) {
    throw new Error("useWallet must be used within an WalletProvider");
  }
  return context;
};

