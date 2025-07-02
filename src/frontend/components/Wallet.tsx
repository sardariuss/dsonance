import { Account } from '@/declarations/protocol/protocol.did';
import { useEffect, useMemo } from "react";
import { useAuth } from '@ic-reactor/react';
import { ckBtcActor } from '../actors/CkBtcActor';
import { ckUsdtActor } from '../actors/CkUsdtActor';
import { formatCurrency, fromFixedPoint, toE8s } from '../utils/conversions/token';
import { minterActor } from '../actors/MinterActor';
import { useCurrencyContext } from './CurrencyContext';
import { TokenLabel } from './common/TokenLabel';

const Wallet = () => {

  const { authenticated, identity } = useAuth({});
  const { formatSatoshis  } = useCurrencyContext();

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

  useEffect(() => {
    refreshBtcBalance();
    refreshUsdtBalance();
  }, [authenticated, identity]);

  return (
    <div className="flex flex-col space-y-4 w-full items-center">

    {/* Bitcoin Section */}
    <div className="w-full rounded-lg p-3 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800">
      <div className="flex items-center space-x-2 mb-2">
        <TokenLabel metadata={btcMetadata} />
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
    </div>

    {/* USDT Section */}
    <div className="w-full rounded-lg p-3 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800">
      <div className="flex items-center space-x-2 mb-2">
        <TokenLabel metadata={usdtMetadata} />
      </div>

      {/* USDT Balance */}
      <div className="flex justify-between w-full">
        <span className="font-medium">Balance:</span>
        <span className="text-md font-semibold">
          {formatCurrency(fromFixedPoint(usdtBalance ?? 0n, 6), "")}
        </span>
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