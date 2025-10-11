import React, { createContext, useContext, ReactNode } from 'react';
import { useMiningRates, MiningRates } from '../hooks/useMiningRates';

interface MiningRatesContextType {
  miningRates: MiningRates | null;
}

const MiningRatesContext = createContext<MiningRatesContextType | undefined>(undefined);

export const MiningRatesProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const miningRates = useMiningRates();

  return (
    <MiningRatesContext.Provider value={{ miningRates }}>
      {children}
    </MiningRatesContext.Provider>
  );
};

export const useMiningRatesContext = (): MiningRatesContextType => {
  const context = useContext(MiningRatesContext);
  if (context === undefined) {
    throw new Error('useMiningRatesContext must be used within a MiningRatesProvider');
  }
  return context;
};
