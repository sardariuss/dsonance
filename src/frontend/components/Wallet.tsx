import { Account } from '@/declarations/protocol/protocol.did';
import { useEffect, useState } from "react";
import { fromNullable, uint8ArrayToHexString } from "@dfinity/utils";
import { useAuth } from '@ic-reactor/react';
import { ckBtcActor } from '../actors/CkBtcActor';
import { Principal } from '@dfinity/principal';
import { canisterId as protocolCanisterId } from "../../declarations/protocol"
import { dsonanceLedgerActor } from '../actors/DsonanceLedgerActor';
import { formatBalanceE8s } from '../utils/conversions/token';
import { DSONANCE_COIN_SYMBOL } from '../constants';
import { minterActor } from '../actors/MinterActor';
import BitcoinIcon from './icons/BitcoinIcon';
import DsonanceCoinIcon from './icons/DsonanceCoinIcon';
import LogoutIcon from './icons/LogoutIcon';
import { Link } from 'react-router-dom';
import { useCurrencyContext } from './CurrencyContext';
import { useWalletContext } from './WalletContext';

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

  const { authenticated, identity, logout } = useAuth({});
  const { formatSatoshis } = useCurrencyContext();
  const { btcBalance, refreshBtcBalance } = useWalletContext();

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

  const { data: dsonanceBalance } = dsonanceLedgerActor.useQueryCall({
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
          refreshAllowance().then(() => refreshBtcBalance);
        }
      );
    }).catch((error) => {
      console.error(error);
    }).finally(
      () => {
        refreshBtcBalance();
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
    refreshBtcBalance();
    refreshAllowance();
  }, [authenticated, identity]);

  return (
    <div className="flex flex-col space-y-4 p-4 w-full items-center">

      <div className="relative group">
        <div className="flex flex-row items-center space-x-2">
          <span
            className="text-gray-800 hover:text-black dark:text-gray-200 dark:hover:text-white font-medium self-center hover:cursor-pointer"
            onClick={handleCopy}
          >
            {accountToString(account)}
          </span>
          <Link 
            className="self-end fill-gray-800 hover:fill-black dark:fill-gray-200 dark:hover:fill-white p-2.5 rounded-lg hover:cursor-pointer"
            onClick={()=>{logout()}}
            to="/">
            <LogoutIcon />
          </Link>
        </div>
        { copied && (
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
      <div className="flex w-full items-center justify-between rounded-lg p-3 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-100 dark:bg-gray-800">
        <div className="flex items-center space-x-2">
          <div className="h-5 w-5">
            <BitcoinIcon />
          </div>
          <span className="text-gray-700 dark:text-white font-medium">Bitcoin:</span>
        </div>
        { btcBalance !== undefined && 
          <span className="text-md font-semibold">
            {formatSatoshis(btcBalance)}
          </span> }
      </div>

      {/* Dsonance Balance */}
      <div className="flex w-full items-center justify-between rounded-lg p-3 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-100 dark:bg-gray-800">
        <div className="flex items-center space-x-2">
          <div className="h-5 w-5">
            <DsonanceCoinIcon />
          </div>
          <span className="text-gray-700 dark:text-white font-medium">Dsonance:</span>
        </div>
        <span className="text-md font-semibold">
          {formatBalanceE8s(dsonanceBalance ?? 0n, DSONANCE_COIN_SYMBOL)}
        </span>
      </div>

      {/* Airdrop Button */}
      {airdropAvailable && (
        <button
          className="px-10 button-simple h-10 justify-center items-center text-lg"
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