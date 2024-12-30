
export const toE8s = (amount: number) : bigint | undefined => {
    if (isNaN(amount) || amount < 0) {
        return undefined;
    }
    return BigInt(Math.round(amount * 100_000_000));
}

export const fromE8s = (amountE8s: bigint) => Number(amountE8s) / 100_000_000;

export const formatBalanceE8s = (amountE8s: bigint) => {
    return (Number(amountE8s) / 10e8).toString();
};

export const formatBTCInUSD = (amountE8s: bigint, price: number) => {

    price = 100_000; // 1 BTC = 100,000 USD

    const usd = (Number(amountE8s) * price / 100_000_000);

    const [balance, unit, precision] =
        usd < 10 ?                [usd,                      "", 2] :
        usd < 1_000_000 ?         [usd,                      "", 0] :
        usd < 1_000_000_000 ?     [usd / 1_000_000,         "M", 0] :
        usd < 1_000_000_000_000 ? [usd / 1_000_000_000,     "B", 0] :
                                  [usd / 1_000_000_000_000, "T", 0];

    return `$${balance.toFixed(precision)}${unit}`;
}

export const formatBalanceSats = (amountE8s: bigint) => {

    const [balance, unit] =
        amountE8s < 1_000n ?             [amountE8s,                       ""] :
        amountE8s < 1_000_000n ?         [amountE8s / 1_000n,             "k"] :
        amountE8s < 1_000_000_000n ?     [amountE8s / 1_000_000n,         "M"] :
        amountE8s < 1_000_000_000_000n ? [amountE8s / 1_000_000_000n,     "B"] :
                                         [amountE8s / 1_000_000_000_000n, "T"];

    return `${(Number(balance))}${unit}`;
};

