import { createContext, useContext, useState, useEffect } from "react";
import { formatBalanceE8s, formatBalanceSats, formatBTCInUSD } from "../utils/conversions/token";
import { BITCOIN_TOKEN_SYMBOL, PRICE_BTC_IN_USD } from "../constants";

export enum SupportedCurrency {
  BTC = "BTC",
  SAT = "SAT",
  USD = "USD",
}

export const SupportedCurrencies = Object.values(SupportedCurrency).map((currency) => ({
  value: currency,
  label: currency,
}));

interface CurrencyContextType {
  currency: SupportedCurrency;
  setCurrency: (currency: SupportedCurrency) => void;
  formatSatoshis: (amountE8s: bigint) => string;
}

const CurrencyContext = createContext<CurrencyContextType | undefined>(undefined);

export const CurrencyProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [currency, setCurrency] = useState<SupportedCurrency>(() => {
    // Retrieve the saved currency state from localStorage on initial render
    const savedCurrency = localStorage.getItem("currency");
    if (savedCurrency && Object.values(SupportedCurrency).includes(savedCurrency as SupportedCurrency)) {
      return savedCurrency as SupportedCurrency;
    } else {
      console.warn("Invalid currency found in localStorage. Defaulting to USD.");
      return SupportedCurrency.USD;
    }
  });

  // Update localStorage whenever `currency` changes
  useEffect(() => {
    localStorage.setItem("currency", currency.toString());
  }, [currency]);

  const formatSatoshis = (amountE8s: bigint) : string => {
    if (currency === "BTC") {
      return formatBalanceE8s(amountE8s) + " " + BITCOIN_TOKEN_SYMBOL;
    } else if (currency === "SAT") {
      return formatBalanceSats(amountE8s);
    } else { // Default to USD
      return formatBTCInUSD(amountE8s, PRICE_BTC_IN_USD);
    }
  };

  return (
    <CurrencyContext.Provider value={{ currency, setCurrency, formatSatoshis }}>
      {children}
    </CurrencyContext.Provider>
  );
};

export const useCurrencyContext = (): CurrencyContextType => {
  const context = useContext(CurrencyContext);
  if (context === undefined) {
    throw new Error("useCurrency must be used within an CurrencyProvider");
  }
  return context;
};

