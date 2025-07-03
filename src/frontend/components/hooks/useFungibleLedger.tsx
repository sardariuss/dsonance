import { ckBtcActor } from "../../actors/CkBtcActor";
import { ckUsdtActor } from "../../actors/CkUsdtActor";
import { icpCoinsActor } from "../../actors/IcpCoinsActor";
import { minterActor } from "../../actors/MinterActor";
import { formatAmountCompact, fromFixedPoint, toFixedPoint } from "../../utils/conversions/token";
import { getTokenDecimals, getTokenFee } from "../../utils/metadata";
import { useEffect, useState } from "react";
import { canisterId as protocolCanisterId } from "../../../declarations/protocol"
import { Principal } from "@dfinity/principal";
import { Account, MetaDatum } from "@/declarations/ck_btc/ck_btc.did";
import { useAuth } from "@ic-reactor/react";

export enum LedgerType {
  SUPPLY = 'supply',
  COLLATERAL = 'collateral'
}

export interface FungibleLedger {
  metadata: MetaDatum[] | undefined;
  price: number | undefined;
  tokenDecimals: number | undefined;
  formatAmount: (amountFixedPoint: bigint | number | undefined) => string | undefined;
  formatAmountUsd: (amountFixedPoint: bigint | number | undefined) => string | undefined;
  convertToUsd: (amountFixedPoint: bigint | number | undefined) => number | undefined;
  approveIfNeeded: (amount: bigint) => Promise<boolean>;
  userBalance: bigint | undefined;
  mint: (amount: number) => Promise<boolean>;
  mintLoading: boolean;
}

export const useFungibleLedger = (ledgerType: LedgerType) : FungibleLedger => {

  const actor = ledgerType === LedgerType.SUPPLY ? ckUsdtActor : ckBtcActor;

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

  const [price, setPrice] = useState<number | undefined>(undefined);

  useEffect(() => {
    fetchLatestPrices();
  }, []);

  const tokenDecimals = getTokenDecimals(metadata);
  const tokenFee = getTokenFee(metadata);

  const formatAmount = (amount: bigint | number | undefined) => {
    if (amount === undefined || tokenDecimals === undefined) {
      return undefined;
    }
    return `${formatAmountCompact(fromFixedPoint(amount, tokenDecimals), ledgerType === LedgerType.SUPPLY ? 2 : tokenDecimals)}`;
  };

  const formatAmountUsd = (amount: bigint | number | undefined) => {
    let usdValue = convertToUsd(amount);
    if (usdValue === undefined) {
      return undefined;
    }
    return `$${formatAmountCompact(usdValue, 2)}`;
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

  const approveIfNeeded = async (amount: bigint) => {
    if (!account) {
      console.warn("User account is not provided.");
      return false;
    }
    if (tokenFee === undefined){
      console.warn(`Token fee is undefined. Cannot proceed with approval.`);
      return false;
    }
    if (amount <= 0n) {
      console.warn("Amount to approve must be greater than zero.");
      return false;
    }
    try {
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
      const requiredAllowance = amount + 2n * tokenFee; // @todo: verify why we need to add 2x fee
      if (currentAllowance >= requiredAllowance) {
        return true;
      }
      const approveResult = await icrc2Approve([
        {
          fee: [],
          memo: [],
          from_subaccount: [],
          created_at_time: [],
          amount: requiredAllowance,
          expected_allowance: [],
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

  const refreshUserBalance = () => {
    if (account) {
      icrc1BalanceOf([account]).then(balance => {
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

  const { call: mintToken, loading: mintLoading } = minterActor.useUpdateCall({
    functionName: ledgerType === LedgerType.SUPPLY ? 'mint_usdt' : 'mint_btc',
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
    formatAmount,
    formatAmountUsd,
    convertToUsd,
    approveIfNeeded,
    userBalance,
    mint,
    mintLoading,
  };
};
