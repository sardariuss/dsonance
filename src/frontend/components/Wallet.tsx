import walletIcon from '../assets/wallet.svg';
import SvgButton from "./SvgButton";
import { Account } from '@/declarations/protocol/protocol.did';
import { useEffect, useState } from "react";
import { fromNullable, uint8ArrayToHexString } from "@dfinity/utils";
import { useAuth } from '@ic-reactor/react';
import { ckBtcActor } from '../actors/CkBtcActor';
import { Principal } from '@dfinity/principal';
import { canisterId as protocolCanisterId } from "../../declarations/protocol"
import { resonanceLedgerActor } from '../actors/ResonanceLedgerActor';
import { formatBalanceE8s } from '../utils/conversions/token';
import { BITCOIN_TOKEN_SYMBOL, RESONANCE_TOKEN_SYMBOL } from '../constants';
import { minterActor } from '../actors/MinterActor';
import BitcoinIcon from './icons/BitcoinIcon';
import ResonanceCoinIcon from './icons/ResonanceCoinIcon';

const accountToString = (account: Account | undefined) : string =>  {
  let str = "";
  if (account !== undefined) {
    str = account.owner.toString();
    let subaccount = fromNullable(account.subaccount);
    if (subaccount !== undefined) {
      str += " " + uint8ArrayToHexString(subaccount); 
    }
  }
  return str;
}

const Wallet = () => {

  const { authenticated, identity } = useAuth({});

  if (!authenticated || identity === null) {
    return (
      <></>
    );
  }

  const account : Account = {
    owner: identity?.getPrincipal(),
    subaccount: []
  };

  const [copied, setCopied] = useState(false);
  const handleCopy = () => {
    navigator.clipboard.writeText(accountToString(account));
    setCopied(true);
    setTimeout(() => setCopied(false), 2000); // Hide tooltip after 2 seconds
  };

  const { data: resonanceBalance } = resonanceLedgerActor.useQueryCall({
    functionName: 'icrc1_balance_of',
    args: [account]
  });

  const { call: refreshBalance, data: btcBalance } = ckBtcActor.useQueryCall({
    functionName: 'icrc1_balance_of',
    args: [account]
  });

  const { call: refreshAllowance, data: btcAllowance } = ckBtcActor.useQueryCall({
    functionName: 'icrc2_allowance',
    args: [{
      account,
      spender: {
        owner: Principal.fromText(protocolCanisterId),
        subaccount: []
      }
    }]
  });

  const { call: getAirdrop, loading: airdroping } = minterActor.useUpdateCall({
    functionName: 'airdrop_user',
  });

  const { call: refreshAirdropAvailable, data: airdropAvailable } = minterActor.useQueryCall({
    functionName: 'is_airdrop_available',
  });

  const { data: airdropInfo } = minterActor.useQueryCall({
    functionName: 'get_airdrop_info',
  });

  const triggerAirdrop = () => {
    getAirdrop().then(() => {
      approve([{
        fee: [],
        memo: [],
        from_subaccount: [],
        created_at_time: [],
        amount: airdropInfo?.allowed_per_user ?? BigInt(1_000_000),
        expected_allowance: [],
        expires_at: [],
        spender: {
          owner: Principal.fromText(protocolCanisterId),
          subaccount: []
        },
      }]).catch((error) => {
        console.error(error);
      }).finally(
        () => {
          refreshAllowance().then(() => refreshBalance);
        }
      );
    }).catch((error) => {
      console.error(error);
    }).finally(
      () => {
        refreshBalance();
        refreshAirdropAvailable();
      }
    );
  }

  const { call: approve, loading: approving } = ckBtcActor.useUpdateCall({
    functionName: 'icrc2_approve',
    onSuccess: (data) => {
      console.log(data)
    },
    onError: (error) => {
      console.error(error);
    }
  });

  // Hook to refresh balance and allowance when account changes
  useEffect(() => {
    refreshBalance();
    refreshAllowance();
  }, [authenticated, identity]);

  return (
    <div className="flex flex-col space-y-4 p-4 w-full shadow-md items-center">

      <div className="relative group">
        <span
          className="text-gray-700 dark:text-white font-medium self-center hover:cursor-pointer hover:scale-110"
          onClick={handleCopy}
        >
          {accountToString(account)}
        </span>
        {copied && (
          <div
            className={`absolute -top-6 left-1/2 z-50 transform -translate-x-1/2 bg-white text-black text-xs rounded px-2 py-1 transition-opacity duration-500 ${
              copied ? "opacity-100" : "opacity-0"
            }`}
          >
            Copied!
          </div>
        )}
      </div>

      {/* Bitcoin Balance */}
      <div className="flex w-full items-center justify-between rounded-lg p-3 shadow-sm border dark:border-gray-700 border-gray-200 bg-slate-100 dark:bg-gray-800">
        <div className="flex items-center space-x-2">
          <div className="h-5 w-5">
            <BitcoinIcon />
          </div>
          <span className="text-gray-700 dark:text-white font-medium">Bitcoins:</span>
        </div>
        <span className="text-md font-semibold">
          {formatBalanceE8s(btcBalance ?? 0n, BITCOIN_TOKEN_SYMBOL)}
        </span>
      </div>


      {/* Resonance Balance */}
      <div className="flex w-full items-center justify-between rounded-lg p-3 shadow-sm border dark:border-gray-700 border-gray-200 bg-slate-100 dark:bg-gray-800">
        <div className="flex items-center space-x-2">
          <div className="h-5 w-5">
            <ResonanceCoinIcon />
          </div>
          <span className="text-gray-700 dark:text-white font-medium">Resonance:</span>
        </div>
        <span className="text-md font-semibold">
          {formatBalanceE8s(resonanceBalance ?? 0n, RESONANCE_TOKEN_SYMBOL)}
        </span>
      </div>

      {/* Airdrop Button */}
      {airdropAvailable && (
        <button
          className="w-full bg-blue-500 hover:bg-blue-600 text-white font-medium py-2 rounded-lg shadow-sm transition-all duration-150 disabled:bg-gray-300 disabled:cursor-not-allowed"
          onClick={triggerAirdrop}
          disabled={!airdropAvailable || airdroping || approving}
        >
          Mint fake Bitcoins
        </button>
      )}

    </div>
  );
}

export default Wallet;