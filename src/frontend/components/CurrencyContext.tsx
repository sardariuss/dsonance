import { createContext, useContext, useState, useEffect } from "react";
import { currencyToE8s, e8sToCurrency, formatBalanceE8s, formatCurrency } from "../utils/conversions/token";
import { BITCOIN_TOKEN_SYMBOL, SAT_TOKEN_SYMBOL, USD_TOKEN_SYMBOL } from "../constants";
import { icpCoinsActor } from "../actors/IcpCoinsActor";

export enum SupportedCurrency {
  ckBTC = "ckBTC",
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
  currencyToSatoshis: (amount: number) => bigint | undefined;
  satoshisToCurrency: (amountE8s: bigint | number) => number | undefined;
  formatSatoshis: (amountE8s: bigint,  omit_unit?: boolean) => string | undefined;
}

const CurrencyContext = createContext<CurrencyContextType | undefined>(undefined);

export const CurrencyProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {

  const { call: fetchLatestPrices } = icpCoinsActor.useQueryCall({
    functionName: "get_latest",
    args: [],
    onSuccess: (data) => {
      if(data !== undefined) {
        let btcUsdPair = data.at(0);
        if (btcUsdPair !== undefined) {
          setPriceBtcInUsd(Number(btcUsdPair[2]));
          return;
        }
      }
      setPriceBtcInUsd(undefined);
    }
  });

  const [priceBtcInUsd, setPriceBtcInUsd] = useState<number | undefined>(undefined);

  useEffect(() => {
    fetchLatestPrices();
  }, []);
  
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
      case SupportedCurrency.ckBTC:
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

  const currencyToSatoshis = (amount: number) : bigint | undefined => {
    if (currency === "ckBTC") {
      return currencyToE8s(amount, 1);
    } else if (currency === "SAT") {
      return BigInt(amount);
    } else { // Default to USD
      if (priceBtcInUsd !== undefined) {
        return currencyToE8s(amount, priceBtcInUsd);
      } 
      return undefined;
    }
  }

  const satoshisToCurrency = (amountE8s: bigint | number) : number | undefined => {
    if (currency === "ckBTC") {
      return e8sToCurrency(amountE8s, 1);
    } else if (currency === "SAT") {
      return Number(amountE8s);
    } else { // Default to USD
      if (priceBtcInUsd !== undefined) {
        return e8sToCurrency(amountE8s, priceBtcInUsd);
      }
      return undefined;
    }
  }

  const formatSatoshis = (amountE8s: bigint, omit_unit?: boolean) : string | undefined => {
    if (currency === "ckBTC") {
      return formatBalanceE8s(amountE8s, omit_unit ? "" : BITCOIN_TOKEN_SYMBOL);
    } else if (currency === "SAT") {
      return formatCurrency(Number(amountE8s), omit_unit ? "" : SAT_TOKEN_SYMBOL);
    } else { // Default to USD
      if (priceBtcInUsd !== undefined) {
        return formatCurrency(e8sToCurrency(amountE8s, priceBtcInUsd), omit_unit ? "" : USD_TOKEN_SYMBOL);
      }
      return undefined;
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

