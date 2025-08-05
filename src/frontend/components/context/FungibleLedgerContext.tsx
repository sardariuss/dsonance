import React, { createContext, useContext, ReactNode } from "react";
import { useFungibleLedger, LedgerType, FungibleLedger } from "../hooks/useFungibleLedger";

interface FungibleLedgerContextType {
  supplyLedger: FungibleLedger;
  collateralLedger: FungibleLedger;
  participationLedger: FungibleLedger;
}

const FungibleLedgerContext = createContext<FungibleLedgerContextType | undefined>(undefined);

export const FungibleLedgerProvider = ({ children }: { children: ReactNode }) => {
  const supplyLedger = useFungibleLedger(LedgerType.SUPPLY);
  const collateralLedger = useFungibleLedger(LedgerType.COLLATERAL);
  const participationLedger = useFungibleLedger(LedgerType.PARTICIPATION);

  return (
    <FungibleLedgerContext.Provider value={{ supplyLedger, collateralLedger, participationLedger }}>
      {children}
    </FungibleLedgerContext.Provider>
  );
};

export const useFungibleLedgerContext = () => {
  const context = useContext(FungibleLedgerContext);
  if (!context) {
    throw new Error("useFungibleLedgerContext must be used within a FungibleLedgerProvider");
  }
  return context;
};
