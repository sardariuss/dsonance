import { ckBtcActor } from "../../actors/CkBtcActor";
import { ckUsdtActor } from "../../actors/CkUsdtActor";
import { icpCoinsActor } from "../../actors/IcpCoinsActor";
import { formatAmountCompact, fromFixedPoint } from "../../utils/conversions/token";
import { getTokenDecimals, getTokenLogo, getTokenName, getTokenSymbol } from "../../utils/metadata";
import { useEffect, useState } from "react";

export enum LedgerType {
  SUPPLY = 'supply',
  COLLATERAL = 'collateral'
}

export enum Currency {
  ORIGINAL = 'original',
  USD = 'usd'
}

export const useFungibleLedger = (ledgerType: LedgerType) => {

  const actor = ledgerType === LedgerType.SUPPLY ? ckUsdtActor : ckBtcActor;
  
  const { data: metadata } = actor.useQueryCall({
    functionName: 'icrc1_metadata'
  });

  const { call: fetchLatestPrices } = icpCoinsActor.useQueryCall({
    functionName: "get_latest",
    args: [],
    onSuccess: (data) => {
      if(data !== undefined) {
        // Search for the pair ckBTC/USD or ckUSDT/USD depending on the ledger type
        const priceRow = data.find(row => {
          const [tokenIds, tokenName] = row;
          return (ledgerType === LedgerType.SUPPLY && tokenName === "ckUSDT/USD") ||
                 (ledgerType === LedgerType.COLLATERAL && tokenName === "ckBTC/USD");
        });
        if (priceRow) {
          const [, , price] = priceRow;
          setPrice(price);
        } else {
          console.warn(`Price for ${ledgerType} not found in latest prices.`);
          setPrice(undefined);
        }
      } else {
        console.warn("No latest prices data available.");
        setPrice(undefined);
      }
    }
  });

  const [price, setPrice] = useState<number | undefined>(undefined);

  useEffect(() => {
    fetchLatestPrices();
  }, [fetchLatestPrices]);

  const tokenLogo = getTokenLogo(metadata);
  const tokenName = getTokenName(metadata);
  const tokenSymbol = getTokenSymbol(metadata); 
  const tokenDecimals = getTokenDecimals(metadata);

  const formatAmount = (amount: bigint | number | undefined, currency?: Currency) => {
    if (tokenDecimals === undefined || amount === undefined) {
      return undefined;
    }
    if (currency === undefined || currency === Currency.ORIGINAL) {
      return `${formatAmountCompact(fromFixedPoint(amount, tokenDecimals), ledgerType === LedgerType.SUPPLY ? 2 : tokenDecimals)}`;
    }
    if (price === undefined) {
      return undefined;
    }
    const amountInCurrency = fromFixedPoint(amount, tokenDecimals) * price;
    return `$${formatAmountCompact(amountInCurrency, 2)}`;
  };

  return {
    tokenLogo,
    tokenName,
    tokenSymbol,
    tokenDecimals,
    metadata,
    price,
    formatAmount,
  };
  
};
