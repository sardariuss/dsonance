import { Account } from '@/declarations/protocol/protocol.did';
import { useEffect, useMemo, useRef, useState } from "react";
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
import { useAllowanceContext } from './AllowanceContext';

const Wallet = () => {

  const { authenticated, identity } = useAuth({});
  const { formatSatoshis, currencySymbol, currencyToSatoshis } = useCurrencyContext();
  const { btcAllowance, refreshBtcAllowance } = useAllowanceContext();
  const [toApprove, setToApprove] = useState<bigint>(0n);
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

  const { data: dsonanceBalance } = dsonanceLedgerActor.useQueryCall({
    functionName: 'icrc1_balance_of',
    args: [account]
  });

  const { data: btcBalance, call: refreshBtcBalance } = ckBtcActor.useQueryCall({
    functionName: 'icrc1_balance_of',
    args: [account]
  });

  const { call: getAirdrop, loading: airdroping } = minterActor.useUpdateCall({
    functionName: 'airdrop_user',
  });

  const { call: refreshAirdropAvailable, data: airdropAvailable } = minterActor.useQueryCall({
    functionName: 'is_airdrop_available',
  });

  const triggerAirdrop = () => {
    getAirdrop().catch((error) => {
      console.error(error);
    }).finally(() => {
        refreshBtcBalance();
        refreshAirdropAvailable();
      }
    );
  }

  const { call: approve, loading: approving } = ckBtcActor.useUpdateCall({
    functionName: 'icrc2_approve',
    args: [{
      fee: [],
      memo: [],
      from_subaccount: [],
      created_at_time: [],
      amount: toApprove,
      expected_allowance: btcAllowance ? [btcAllowance] : [],
      expires_at: [],
      spender: {
        owner: Principal.fromText(protocolCanisterId),
        subaccount: []
      },
    }],
    onSuccess: (data) => {
      console.log(data)
    },
    onError: (error) => {
      console.error(error);
    }
  });

  const triggerApprove = () => {
    approve().catch((error) => {
      console.error(error);
    }).finally(() => {
        refreshBtcAllowance()
      }
    );
  }

  // Hook to refresh balance and allowance when account changes
  useEffect(() => {
    refreshBtcBalance();
    refreshBtcAllowance();
  }, [authenticated, identity]);

  return (
    <div className="flex flex-col space-y-4 p-4 w-full items-center">

    {/* Bitcoin Section */}
    <div className="w-full rounded-lg p-3 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800">
      <div className="flex items-center space-x-2 mb-2">
        <BitcoinIcon/>
        <span className="text-gray-700 dark:text-white text-lg">Bitcoin</span>
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
        <div className="flex items-center space-x-1">
          <span>{currencySymbol}</span>
          <input
            ref={inputRef}
            onChange={(e) => setToApprove(currencyToSatoshis(Number(e.target.value)) ?? 0n)}
            type="number"
            className="w-32 h-9 border dark:border-gray-300 border-gray-900 rounded px-2 appearance-none focus:outline outline-1 outline-purple-500 bg-gray-100 dark:bg-gray-900"
          />
        </div>
        <button
          className="button-simple text-base"
          onClick={() => triggerApprove()}
          disabled={approving}
        >
          Update allowance
        </button>
      </div>
    </div>

    {/* Dsonance Section */}
    <div className="w-full rounded-lg p-3 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800">
      <div className="flex items-center space-x-2 mb-2">
        <DsonanceCoinIcon/>
        <span className="text-gray-700 dark:text-white text-lg">Dsonance</span>
      </div>

      {/* Dsonance Balance */}
      <div className="flex justify-between w-full">
        <span className="font-medium">Balance:</span>
        <span className="text-md font-semibold">
          {formatBalanceE8s(dsonanceBalance ?? 0n, DSONANCE_COIN_SYMBOL)}
        </span>
      </div>
    </div>

    {/* Airdrop Button */}
    {airdropAvailable && (
      <button
        className="px-10 button-simple h-10 justify-center items-center text-lg"
        onClick={triggerAirdrop}
        disabled={!airdropAvailable || airdroping}
      >
        Mint fake Bitcoins
      </button>
    )}

  </div>

  );
}

export default Wallet;