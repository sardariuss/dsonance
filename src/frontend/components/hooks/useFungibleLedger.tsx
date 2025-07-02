import { ckBtcActor } from "../../actors/CkBtcActor";
import { ckUsdtActor } from "../../actors/CkUsdtActor";
import { icpCoinsActor } from "../../actors/IcpCoinsActor";
import { formatAmountCompact, fromFixedPoint } from "../../utils/conversions/token";
import { getTokenDecimals, getTokenLogo, getTokenName, getTokenSymbol } from "../../utils/metadata";
import { useEffect, useState } from "react";
import { canisterId as protocolCanisterId } from "../../../declarations/protocol"
import { Principal } from "@dfinity/principal";
import { Account, MetaDatum } from "@/declarations/ck_btc/ck_btc.did";

export enum LedgerType {
  SUPPLY = 'supply',
  COLLATERAL = 'collateral'
}

export interface FungibleLedger {
  metadata: MetaDatum[] | undefined;
  price: number | undefined;
  tokenDecimals: number | undefined;
  formatAmount: (amountFixedPoint: bigint | number | undefined) => string | undefined;
  convertToUsd: (amountFixedPoint: bigint | number | undefined) => number | undefined;
  approveIfNeeded: (account: Account, amount: bigint) => Promise<boolean>;
  userBalance: bigint | undefined;
}

export const useFungibleLedger = (ledgerType: LedgerType, userAccount?: Account) : FungibleLedger => {

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

  const tokenDecimals = getTokenDecimals(metadata);

  const formatAmount = (amount: bigint | number | undefined) => {
    
    if (amount === undefined || tokenDecimals === undefined) {
      return undefined;
    }
    return `${formatAmountCompact(fromFixedPoint(amount, tokenDecimals), ledgerType === LedgerType.SUPPLY ? 2 : tokenDecimals)}`;
  };

  const convertToUsd = (amount: bigint | number | undefined) : number | undefined => {
    if (amount === undefined || price === undefined || tokenDecimals === undefined) {
      return undefined;
    }
    return fromFixedPoint(amount, tokenDecimals) * price;
  }

  const { call: icrc2Approve } = actor.useUpdateCall({
    functionName: 'icrc2_approve',
  });
  const { call: icrc2Allowance } = actor.useQueryCall({
    functionName: 'icrc2_allowance',
  });

  const approveIfNeeded = async (account: Account, amount: bigint) => {
  
    if (amount <= 0n) {
      console.warn("Amount to approve must be greater than zero.");
      return false;
    }

    try {
      // Step 1: Check current allowance
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

      // Step 2: Only approve if not enough
      if (currentAllowance >= amount) {
        return true; // Enough allowance, no need to approve
      }

      // Step 3: Approve only the delta or full amount (your choice)
      const approveResult = await icrc2Approve([
        {
          fee: [],
          memo: [],
          from_subaccount: [],
          created_at_time: [],
          amount,
          expected_allowance: [], // optional safety check
          expires_at: [],
          spender: {
            owner: Principal.fromText(protocolCanisterId),
            subaccount: [],
          },
        },
      ]);

      if (approveResult === undefined) {
        throw new Error(`Failed to approve ${amount}: icrc2_approve returned an undefined result`);
      } 
      if ("err" in approveResult) {
        throw new Error(`Failed to approve ${amount}: ${approveResult.err}`);
      } 
      return true;

    } catch (error) {
      console.error("Error in approveIfNeeded:", error);
      return false;
    }
  };

  const { call: icrc1BalanceOf } = actor.useQueryCall({
    functionName: 'icrc1_balance_of',
  });

  const [userBalance, setUserBalance] = useState<bigint | undefined>(undefined);

  useEffect(() => {
    if (userAccount) {
      icrc1BalanceOf([userAccount]).then(balance => {
        setUserBalance(balance);
      }).catch(error => {
        console.error("Error fetching user balance:", error);
        setUserBalance(undefined);
      });
    } else {
      setUserBalance(undefined);
    }
  }, [userAccount, icrc1BalanceOf]);

  return {
    metadata,
    price,
    tokenDecimals,
    formatAmount,
    convertToUsd,
    approveIfNeeded,
    userBalance,
  };
  
};
