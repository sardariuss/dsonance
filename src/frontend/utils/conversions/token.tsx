/**
 * Converts a float to fixed-point BigInt based on decimals.
 * @param amount - Human-readable float (e.g. 1.23)
 * @param decimals - Number of decimals (e.g. 8 for e8s, 6 for e6s)
 */
export const toFixedPoint = (amount: number, decimals: number): bigint | undefined => {
  if (isNaN(amount) || amount < 0) {
    return undefined;
  }

  const scale = 10 ** decimals;
  return BigInt(Math.trunc(amount * scale));
};

/**
 * Converts a fixed-point BigInt to float based on decimals.
 * @param amount - Amount in fixed-point representation (e.g. e8s)
 * @param decimals - Number of decimals used (e.g. 8 for e8s)
 */
export const fromFixedPoint = (amount: bigint | number, decimals: number): number => {
  const scale = 10 ** decimals;
  return Number(amount) / scale;
};

export const formatCurrency = (currencyAmount: number, currencySymbol: string, decimals?: number) => {

    if (isNaN(currencyAmount) || currencyAmount < 0) {
        return `${currencySymbol}0.00`;
    }

    let precision = decimals ?? 2;

    const [balance, unit] =
        currencyAmount < 1_000 ?             [currencyAmount,                      ""] :
        currencyAmount < 1_000_000 ?         [currencyAmount / 1_000,             "K"] :
        currencyAmount < 1_000_000_000 ?     [currencyAmount / 1_000_000,         "M"] :
        currencyAmount < 1_000_000_000_000 ? [currencyAmount / 1_000_000_000,     "B"] :
                                             [currencyAmount / 1_000_000_000_000, "T"];

    return `${currencySymbol}${balance.toFixed(precision)}${unit}`;
}

export const toE8s = (amount: number) : bigint | undefined => {
    if (isNaN(amount) || amount < 0) {
        return undefined;
    }
    return BigInt(Math.round(amount * 100_000_000));
}

export const fromE8s = (amountE8s: bigint) => Number(amountE8s) / 100_000_000;

export const formatBalanceE8s = (amountE8s: bigint, currencySymbol: string, decimals?: number) => {
    if (decimals !== undefined) {
        return `${fromE8s(amountE8s).toFixed(decimals)} ${currencySymbol}`
    }
    return `${fromE8s(amountE8s).toString()} ${currencySymbol}`
};

export const currencyToE8s = (amount: number, priceUnit: number) => {
    return BigInt(Math.round(amount * 100_000_000 / priceUnit));
}

export const e8sToCurrency = (amountE8s: bigint | number, priceUnit: number) => {
    return Number(amountE8s) * priceUnit / 100_000_000;
}
