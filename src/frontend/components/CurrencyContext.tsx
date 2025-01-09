import { createContext, useContext, useState, useEffect } from "react";
import { currencyToE8s, e8sToCurrency, formatBalanceE8s, formatCurrency } from "../utils/conversions/token";
import { BITCOIN_TOKEN_SYMBOL, PRICE_BTC_IN_USD, SAT_TOKEN_SYMBOL, USD_TOKEN_SYMBOL } from "../constants";

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
  currencySymbol: string;
  setCurrency: (currency: SupportedCurrency) => void;
  currencyToSatoshis: (amount: number) => bigint;
  satoshisToCurrency: (amountE8s: bigint) => number;
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

  const currencySymbol = (() => {
    switch (currency) {
      case SupportedCurrency.BTC:
        return BITCOIN_TOKEN_SYMBOL;
      case SupportedCurrency.SAT:
        return SAT_TOKEN_SYMBOL;
      case SupportedCurrency.USD:
        return USD_TOKEN_SYMBOL
    }
  })();

  // Update localStorage whenever `currency` changes
  useEffect(() => {
    localStorage.setItem("currency", currency.toString());
  }, [currency]);

  const currencyToSatoshis = (amount: number) : bigint => {
    if (currency === "BTC") {
      return currencyToE8s(amount, 1);
    } else if (currency === "SAT") {
      return BigInt(amount);
    } else { // Default to USD
      return currencyToE8s(amount, PRICE_BTC_IN_USD);
    }
  }

  const satoshisToCurrency = (amountE8s: bigint) : number => {
    if (currency === "BTC") {
      return e8sToCurrency(amountE8s, 1);
    } else if (currency === "SAT") {
      return Number(amountE8s);
    } else { // Default to USD
      return e8sToCurrency(amountE8s, PRICE_BTC_IN_USD);
    }
  }

  const formatSatoshis = (amountE8s: bigint) : string => {
    if (currency === "BTC") {
      return formatBalanceE8s(amountE8s, BITCOIN_TOKEN_SYMBOL);
    } else if (currency === "SAT") {
      return formatCurrency(Number(amountE8s), SAT_TOKEN_SYMBOL);
    } else { // Default to USD
      return formatCurrency(e8sToCurrency(amountE8s, PRICE_BTC_IN_USD), USD_TOKEN_SYMBOL);
    }
  };

  return (
    <CurrencyContext.Provider value={{ currency, setCurrency, currencySymbol, currencyToSatoshis, satoshisToCurrency, formatSatoshis }}>
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

