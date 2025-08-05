import { ckBtcActor } from "../../actors/CkBtcActor";
import { ckUsdtActor } from "../../actors/CkUsdtActor";
import { dsnLedgerActor } from "../../actors/DsnLedgerActor";
import { icpCoinsActor } from "../../actors/IcpCoinsActor";
import { faucetActor } from "../../actors/FaucetActor";
import { fromFixedPoint, toFixedPoint } from "../../utils/conversions/token";
import { getTokenDecimals, getTokenFee } from "../../utils/metadata";
import { useEffect, useState } from "react";
import { canisterId as protocolCanisterId } from "../../../declarations/protocol"
import { Principal } from "@dfinity/principal";
import { Account, MetadataValue } from "@/declarations/ckbtc_ledger/ckbtc_ledger.did";
import { useAuth } from "@ic-reactor/react";

export enum LedgerType {
  SUPPLY = 'supply',
  COLLATERAL = 'collateral',
  PARTICIPATION = 'participation',
}

export interface FungibleLedger {
  metadata: Array<[string, MetadataValue]> | undefined;
  price: number | undefined;
  tokenDecimals: number | undefined;
  totalSupply: bigint | undefined;
  formatAmount: (amountFixedPoint: bigint | number | undefined, notation?: "standard" | "compact") => string | undefined;
  formatAmountUsd: (amountFixedPoint: bigint | number | undefined, notation?: "standard" | "compact") => string | undefined;
  convertToUsd: (amountFixedPoint: bigint | number | undefined) => number | undefined;
  convertFromUsd: (amountFixedPoint: number | undefined) => bigint | undefined;
  convertToFixedPoint: (amount: number | undefined) => bigint | undefined;
  convertToFloatingPoint: (amountFixedPoint: bigint | number | undefined) => number | undefined;
  subtractFee?: (amount: bigint) => bigint;
  approveIfNeeded: (amount: bigint) => Promise<{ tokenFee: bigint, approveCalled: boolean }>;
  userBalance: bigint | undefined;
  refreshUserBalance: () => void;
  mint: (amount: number) => Promise<boolean>;
  mintLoading: boolean;
}

export const useFungibleLedger = (ledgerType: LedgerType) : FungibleLedger => {

  const actor = ledgerType === LedgerType.SUPPLY ? ckUsdtActor : ledgerType === LedgerType.COLLATERAL ? ckBtcActor : dsnLedgerActor;

  const { authenticated, identity } = useAuth({});

  const [account, setAccount] = useState<Account | undefined>(undefined);

  useEffect(() => {
    if (authenticated && identity) {
      setAccount({
        owner: identity.getPrincipal(),
        subaccount: []
      });
    } else {
      setAccount(undefined);
    }
  }, [authenticated, identity]);
  
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

  const { data: totalSupply } = actor.useQueryCall({
    functionName: 'icrc1_total_supply',
    args: [],
  });

  const [price, setPrice] = useState<number | undefined>(undefined);

  useEffect(() => {
    if (ledgerType === LedgerType.SUPPLY || ledgerType === LedgerType.COLLATERAL) {
      fetchLatestPrices();
    }
  }, []);

  const tokenDecimals = getTokenDecimals(metadata);
  const tokenFee = getTokenFee(metadata);

  const formatAmount = (amount: bigint | number | undefined, notation: "standard" | "compact" = "compact") => {
    if (amount === undefined || tokenDecimals === undefined) {
      return undefined;
    }
    return new Intl.NumberFormat("en-US", {
      notation,
      minimumFractionDigits: 0,
      maximumFractionDigits: ledgerType === LedgerType.SUPPLY ? 2 : tokenDecimals,
    }).format(fromFixedPoint(amount, tokenDecimals));
  };

  const formatAmountUsd = (amount: bigint | number | undefined, notation: "standard" | "compact" = "compact") => {
    let usdValue = convertToUsd(amount);
    if (usdValue === undefined) {
      return undefined;
    }
    let formattedValue = new Intl.NumberFormat("en-US", {
      notation,
      minimumFractionDigits: 0,
      maximumFractionDigits: 2,
    }).format(usdValue);
    return `$${formattedValue}`;
  };

  const convertToUsd = (amount: bigint | number | undefined) : number | undefined => {
    if (amount === undefined || price === undefined || tokenDecimals === undefined) {
      return undefined;
    }
    return fromFixedPoint(amount, tokenDecimals) * price;
  }

  const convertFromUsd = (amount: number | undefined) : bigint | undefined => {
    if (amount === undefined || price === undefined || tokenDecimals === undefined) {
      return undefined;
    }
    return toFixedPoint(amount / price, tokenDecimals);
  };

  const convertToFixedPoint = (amount: number | undefined) : bigint | undefined => {
    if (amount === undefined || tokenDecimals === undefined) {
      return undefined;
    }
    return toFixedPoint(amount, tokenDecimals);
  };

  const convertToFloatingPoint = (amount: bigint | number | undefined) : number | undefined => {
    if (amount === undefined || tokenDecimals === undefined) {
      return undefined;
    }
    return fromFixedPoint(amount, tokenDecimals);
  };

  const { call: icrc2Approve } = actor.useUpdateCall({
    functionName: 'icrc2_approve',
  });
  const { call: icrc2Allowance } = actor.useQueryCall({
    functionName: 'icrc2_allowance',
  });

  const subtractFee = tokenFee === undefined ? undefined : (amount: bigint) : bigint => {
    if (amount < tokenFee) {
      return 0n; // If amount is less than fee, return 0, transfer will fail anyway
    }
    return amount - tokenFee; // Subtract the token fee from the amount
  };

  /**
   * Approves the specified amount for the protocol canister if needed.
   * If the current allowance is sufficient, it returns the original amount 
   * minus the token fee (required by the upcoming transfer).
   * If the approval is successful, it returns the approved amount minus two 
   * times the token fee (one for the approval and one required by the upcoming transfer).
   * 
   * @param {bigint} amount - The amount to approve.
   * @returns {Promise<{ tokenFee: bigint, approveCalled: boolean }>} - The token fee, and whether the approval was called.
   */
  const approveIfNeeded = async (amount: bigint) : Promise<{ tokenFee: bigint, approveCalled: boolean }> =>  {

    if (!account) {
      throw new Error("User account is not provided.");
    }
    if (tokenFee === undefined){
      throw new Error("Token fee is not defined.");
    }
    if (amount <= 0n || isNaN(Number(amount))) {
      throw new Error("Amount must be greater than zero.");
    }
    if (amount < 2n * tokenFee) {
      throw new Error(`Amount ${amount} is less than two times the token fee ${tokenFee}.`);
    }
    
    const allowanceResult = await icrc2Allowance([
      {
        account,
        spender: {
          owner: Principal.fromText(protocolCanisterId),
          subaccount: [],
        },
      },
    ]);
    if (allowanceResult === undefined) {
      throw new Error(`Failed to fetch allowance`);
    }
    const currentAllowance: bigint = allowanceResult.allowance;
    console.log(`Current allowance for ${account.owner.toText()} is ${currentAllowance}, requested amount is ${amount}`);
    if (currentAllowance >= amount) {
      return { tokenFee, approveCalled: false }; // No need to call approve
    }
    const approveResult = await icrc2Approve([
      {
        fee: [tokenFee],
        memo: [],
        from_subaccount: [],
        created_at_time: [ BigInt(Date.now()) * 1_000_000n ], // Convert to nanoseconds
        amount: amount - tokenFee,
        expected_allowance: [],
        expires_at: [],
        spender: {
          owner: Principal.fromText(protocolCanisterId),
          subaccount: [],
        },
      },
    ]);
    console.log(`Approve result:`, approveResult);
    if (approveResult === undefined) {
      throw new Error(`Failed to approve ${amount}: icrc2_approve returned an undefined result`);
    } 
    if ("Err" in approveResult) {
      console.error(`Error approving ${amount}:`, approveResult.Err);
      throw new Error(`Failed to approve ${amount}`);
    }
    return { tokenFee, approveCalled: true };
  };

  const { call: icrc1BalanceOf } = actor.useQueryCall({
    functionName: 'icrc1_balance_of',
  });

  const [userBalance, setUserBalance] = useState<bigint | undefined>(undefined);

  const refreshUserBalance = () => {
    console.log("Refreshing user balance for account:", account);
    if (account) {
      icrc1BalanceOf([account]).then(balance => {
        console.log("Fetched user balance:", balance);
        setUserBalance(balance);
      }).catch(error => {
        console.error("Error fetching user balance:", error);
        setUserBalance(undefined);
      });
    } else {
      setUserBalance(undefined);
    }
  }

  useEffect(() => {
    refreshUserBalance();
  }, [account]);

  const { call: mintToken, loading: mintLoading } = faucetActor.useUpdateCall({
    functionName: ledgerType === LedgerType.SUPPLY ? 'mint_usdt' : ledgerType === LedgerType.COLLATERAL ? 'mint_btc' : 'mint_dsn',
  });

  const mint = async(amount: number) => {
    if (isNaN(amount) || amount <= 0) {
      console.error("Invalid amount to mint:", amount);
      return false;
    }
    if (tokenDecimals === undefined){
      console.error("Token decimals are not defined.");
      return false;
    }
    if (!account) {
      console.warn("User account is not provided.");
      return false;
    }
    try {
      const mintResult = await mintToken([{
        amount: toFixedPoint(amount, tokenDecimals) ?? 0n,
        to: account,
      }]);
      if (mintResult === undefined) {
        throw new Error(`Failed to mint ${amount}: mintToken returned an undefined result`);
      }
      if ("err" in mintResult) {
        throw new Error(`Failed to mint ${amount}: ${mintResult.err}`);
      }
      // Refresh user balance after minting
      refreshUserBalance();
      return true;
    } catch (error) {
      console.error("Error in mint:", error);
      return false;
    }
  };

  return {
    metadata,
    price,
    tokenDecimals,
    totalSupply,
    formatAmount,
    formatAmountUsd,
    convertToUsd,
    convertFromUsd,
    convertToFixedPoint,
    convertToFloatingPoint,
    subtractFee,
    approveIfNeeded,
    userBalance,
    refreshUserBalance,
    mint,
    mintLoading,
  };
};
