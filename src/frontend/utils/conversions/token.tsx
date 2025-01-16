
export const toE8s = (amount: number) : bigint | undefined => {
    if (isNaN(amount) || amount < 0) {
        return undefined;
    }
    return BigInt(Math.round(amount * 100_000_000));
}

export const fromE8s = (amountE8s: bigint) => Number(amountE8s) / 100_000_000;

export const formatBalanceE8s = (amountE8s: bigint, currencySymbol: string) => {
    return `${currencySymbol}${fromE8s(amountE8s).toFixed(2)}`
};

export const currencyToE8s = (amount: number, priceUnit: number) => {
    return BigInt(Math.round(amount * 100_000_000 / priceUnit));
}

export const e8sToCurrency = (amountE8s: bigint, priceUnit: number) => {
    return Number(amountE8s) * priceUnit / 100_000_000;
}

export const formatCurrency = (currencyAmount: number, currencySymbol: string, decimals?: number) => {

    const [balance, unit, precision] =
        currencyAmount < 10 ?                [currencyAmount,                      "", decimals ?? 2] :
        currencyAmount < 1_000_000 ?         [currencyAmount,                      "",             0] :
        currencyAmount < 1_000_000_000 ?     [currencyAmount / 1_000_000,         "M",             0] :
        currencyAmount < 1_000_000_000_000 ? [currencyAmount / 1_000_000_000,     "B",             0] :
                                             [currencyAmount / 1_000_000_000_000, "T",             0];

    return `${currencySymbol}${balance.toFixed(precision)}${unit}`;
}