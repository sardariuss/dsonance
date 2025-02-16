import { Account } from '@/declarations/protocol/protocol.did';
import { useEffect, useMemo, useState } from "react";
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
import { useCurrencyContext } from './CurrencyContext';
import { useWalletContext } from './WalletContext';

const Wallet = () => {

  const { authenticated, identity, logout } = useAuth({});
  const { formatSatoshis } = useCurrencyContext();
  const { btcBalance, refreshBtcBalance } = useWalletContext();

  if (!authenticated || identity === null) {
    return (
      <></>
    );
  }

  const account : Account = useMemo(() => ({
    owner: identity?.getPrincipal(),
    subaccount: []
  }), [identity]);

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

      {/* Bitcoin Balance */}
      <div className="flex w-full items-center justify-between rounded-lg p-3 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800">
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
      <div className="flex w-full items-center justify-between rounded-lg p-3 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800">
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