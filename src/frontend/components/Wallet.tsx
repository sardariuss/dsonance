import { Account } from '@/declarations/protocol/protocol.did';
import { useEffect, useMemo, useRef, useState } from "react";
import { useAuth } from '@ic-reactor/react';
import { ckBtcActor } from '../actors/CkBtcActor';
import { Principal } from '@dfinity/principal';
import { canisterId as protocolCanisterId } from "../../declarations/protocol"
import { ckUsdtActor } from '../actors/CkUsdtActor';
import { formatBalanceE8s, toE8s } from '../utils/conversions/token';
import { minterActor } from '../actors/MinterActor';
import { useCurrencyContext } from './CurrencyContext';
import { useAllowanceContext } from './AllowanceContext';
import { MetaDatum } from '@/declarations/ck_btc/ck_btc.did';

const Wallet = () => {

  const { authenticated, identity } = useAuth({});
  const { formatSatoshis, currencySymbol, currencyToSatoshis } = useCurrencyContext();
  const { btcAllowance, usdtAllowance, refreshBtcAllowance, refreshUsdtAllowance } = useAllowanceContext();
  const [btcToApprove, setBtcToApprove] = useState<bigint>(0n);
  const [usdtToApprove, setUsdtToApprove] = useState<bigint>(0n);
  const inputRef = useRef<HTMLInputElement>(null);

  if (!authenticated || identity === null) {
    return (
      <></>
    );
  }

  const account : Account = useMemo(() => ({
    owner: identity?.getPrincipal(),
    subaccount: []
  }), [identity]);

  const { data: usdtBalance, call: refreshUsdtBalance } = ckUsdtActor.useQueryCall({
    functionName: 'icrc1_balance_of',
    args: [account]
  });

  const { data: usdtMetadata } = ckUsdtActor.useQueryCall({
    functionName: 'icrc1_metadata'
  });

  const { data: btcBalance, call: refreshBtcBalance } = ckBtcActor.useQueryCall({
    functionName: 'icrc1_balance_of',
    args: [account]
  });

  const { data: btcMetadata } = ckBtcActor.useQueryCall({
    functionName: 'icrc1_metadata'
  });

  const { call: getBtcAirdrop, loading: btcAirdroping } = minterActor.useUpdateCall({
    functionName: 'btc_airdrop_user',
  });

  const { call: refreshBtcAirdropAvailable, data: btcAirdropAvailable } = minterActor.useQueryCall({
    functionName: 'is_btc_airdrop_available',
  });

  const triggerBtcAirdrop = () => {
    getBtcAirdrop().catch((error) => {
      console.error(error);
    }).finally(() => {
        refreshBtcBalance();
        refreshBtcAirdropAvailable();
      }
    );
  }

  const { call: getUsdtAirdrop, loading: usdtAirdroping } = minterActor.useUpdateCall({
    functionName: 'usdt_airdrop_user',
  });

  const { call: refreshUsdtAirdropAvailable, data: usdtAirdropAvailable } = minterActor.useQueryCall({
    functionName: 'is_usdt_airdrop_available',
  });

  const triggerUsdtAirdrop = () => {
    getUsdtAirdrop().catch((error) => {
      console.error(error);
    }).finally(() => {
        refreshUsdtBalance();
        refreshUsdtAirdropAvailable();
      }
    );
  }

  const { call: btcApprove, loading: btcApproving } = ckBtcActor.useUpdateCall({
    functionName: 'icrc2_approve',
    args: [{
      fee: [],
      memo: [],
      from_subaccount: [],
      created_at_time: [],
      amount: btcToApprove,
      expected_allowance: [],
      expires_at: [],
      spender: {
        owner: Principal.fromText(protocolCanisterId),
        subaccount: []
      },
    }]
  });

  const { call: usdtApprove, loading: usdtApproving } = ckUsdtActor.useUpdateCall({
    functionName: 'icrc2_approve',
    args: [{
      fee: [],
      memo: [],
      from_subaccount: [],
      created_at_time: [],
      amount: usdtToApprove,
      expected_allowance: [],
      expires_at: [],
      spender: {
        owner: Principal.fromText(protocolCanisterId),
        subaccount: []
      },
    }]
  });

  const triggerBtcApprove = () => {
    btcApprove().catch((error) => {
      console.error(error);
    }).finally(() => {
        refreshBtcAllowance()
      }
    );
  }

  const triggerUsdtApprove = () => {
    usdtApprove().catch((error) => {
      console.error(error);
    }).finally(() => {
        refreshUsdtAllowance()
      }
    );
  }

  // Hook to refresh balance and allowance when account changes
  useEffect(() => {
    refreshBtcBalance();
    refreshBtcAllowance();
    refreshUsdtBalance();
    refreshUsdtAllowance();
  }, [authenticated, identity]);

  const getTokenLogo = (metadata: MetaDatum[] | undefined) : string | undefined => {
    if (!metadata) {
      return undefined;
    }
    const logo = metadata.find((item) => item[0] === "icrc1:logo");
    if (logo !== undefined && "Text" in logo?.[1]) {
      return logo?.[1].Text;
    }
    return undefined;
  }

  const getTokenName = (metadata: MetaDatum[] | undefined) : string | undefined => {
    if (!metadata) {
      return undefined;
    }
    const name = metadata.find((item) => item[0] === "icrc1:name");
    if (name !== undefined && "Text" in name?.[1]) {
      return name?.[1].Text;
    }
    return undefined;
  }

  const getTokenSymbol = (metadata: MetaDatum[] | undefined) : string | undefined => {
    if (!metadata) {
      return undefined;
    } 
    const symbol = metadata.find((item) => item[0] === "icrc1:symbol");
    if (symbol !== undefined && "Text" in symbol?.[1]) {
      return symbol?.[1].Text;
    }
    return undefined;
  }

  return (
    <div className="flex flex-col space-y-4 w-full items-center">

    {/* Bitcoin Section */}
    <div className="w-full rounded-lg p-3 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800">
      <div className="flex items-center space-x-2 mb-2">
        <img src={getTokenLogo(btcMetadata)} alt="BTC" className="w-6 h-6" />
        <span className="text-gray-700 dark:text-white text-lg">{getTokenName(btcMetadata) ?? "Bitcoin"}</span>
      </div>

      {/* Bitcoin Balance */}
      <div className="flex justify-between w-full">
        <span className="font-medium">Balance:</span>
        {btcBalance !== undefined && (
          <span className="text-md font-semibold">
            {formatSatoshis(btcBalance ?? 0n)}
          </span>
        )}
      </div>

      {/* Bitcoin Allowance */}
      <div className="flex justify-between w-full mt-1">
        <span className="font-medium">Allowance:</span>
        {btcAllowance !== undefined && (
          <span className="text-md font-semibold">
            {formatSatoshis(btcAllowance)}
          </span>
        )}
      </div>

      {/* Allowance Input & Approve Button */}
      <div className="flex justify-end w-full space-x-2 mt-3">
        <div className="flex items-center space-x-2">
          <span>{getTokenSymbol(btcMetadata) ?? ""}</span>
          <input
            ref={inputRef}
            onChange={(e) => setBtcToApprove(currencyToSatoshis(Number(e.target.value)) ?? 0n)}
            type="number"
            className="sm:w-32 w-full h-9 border dark:border-gray-300 border-gray-900 rounded appearance-none focus:outline outline-1 outline-purple-500 bg-gray-100 dark:bg-gray-900"
          />
        </div>
        <button
          className="button-simple text-base"
          onClick={() => triggerBtcApprove()}
          disabled={btcApproving}
        >
          Update allowance
        </button>
      </div>
    </div>

    {/* Dsonance Section */}
    <div className="w-full rounded-lg p-3 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800">
      <div className="flex items-center space-x-2 mb-2">
        <img src={getTokenLogo(usdtMetadata)} alt="USDT" className="w-6 h-6" />
        <span className="text-gray-700 dark:text-white text-lg">{getTokenName(usdtMetadata) ?? "Dsonance"}</span>
      </div>

      {/* Dsonance Balance */}
      <div className="flex justify-between w-full">
        <span className="font-medium">Balance:</span>
        <span className="text-md font-semibold">
          {formatBalanceE8s(usdtBalance ?? 0n, getTokenSymbol(usdtMetadata) ?? "")}
        </span>
      </div>

      {/* USDT Allowance */}
      <div className="flex justify-between w-full mt-1">
        <span className="font-medium">Allowance:</span>
        {usdtAllowance !== undefined && (
          <span className="text-md font-semibold">
            {formatBalanceE8s(usdtAllowance, getTokenSymbol(usdtMetadata) ?? "")}
          </span>
        )}
      </div>

      {/* Allowance Input & Approve Button */}
      <div className="flex justify-end w-full space-x-2 mt-3">
        <div className="flex items-center space-x-2">
          <span>{getTokenSymbol(usdtMetadata) ?? ""}</span>
          <input
            ref={inputRef}
            onChange={(e) => setUsdtToApprove(toE8s(Number(e.target.value)) ?? 0n)}
            type="number"
            className="sm:w-32 w-full h-9 border dark:border-gray-300 border-gray-900 rounded appearance-none focus:outline outline-1 outline-purple-500 bg-gray-100 dark:bg-gray-900"
          />
        </div>
        <button
          className="button-simple text-base"
          onClick={() => triggerUsdtApprove()}
          disabled={usdtApproving}
        >
          Update allowance
        </button>
      </div>
    </div>

    {/* BTC Airdrop Button */}
    {btcAirdropAvailable && (
      <button
        className="px-10 button-simple h-10 justify-center items-center text-lg"
        onClick={triggerBtcAirdrop}
        disabled={!btcAirdropAvailable || btcAirdroping}
      >
        Mint fake Bitcoins
      </button>
    )}

    {/* USDT Airdrop Button */}
    {usdtAirdropAvailable && (
      <button
        className="px-10 button-simple h-10 justify-center items-center text-lg"
        onClick={triggerUsdtAirdrop}
        disabled={!usdtAirdropAvailable || usdtAirdroping}
      >
        Airdrop USDT tokens
      </button>
    )}

  </div>

  );
}

export default Wallet;