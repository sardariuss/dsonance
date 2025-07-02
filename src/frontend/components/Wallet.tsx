import { Account } from '@/declarations/protocol/protocol.did';
import { useEffect, useMemo, useState } from "react";
import { useAuth } from '@ic-reactor/react';
import { ckBtcActor } from '../actors/CkBtcActor';
import { ckUsdtActor } from '../actors/CkUsdtActor';
import { fromFixedPoint, toFixedPoint } from '../utils/conversions/token';
import { minterActor } from '../actors/MinterActor';
import { TokenLabel } from './common/TokenLabel';

const Wallet = () => {

  const { authenticated, identity } = useAuth({});
  const [btcMintAmount, setBtcMintAmount] = useState<string>("");
  const [usdtMintAmount, setUsdtMintAmount] = useState<string>("");

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

  const { call: mintBtc, loading: mintBtcLoading } = minterActor.useUpdateCall({
    functionName: 'mint_btc',
  });

  const { call: mintUsdt, loading: mintUsdtLoading } = minterActor.useUpdateCall({
    functionName: 'mint_usdt',
  });

  const triggerBtcMint = () => {
    const amount = Number(btcMintAmount);
    if (isNaN(amount) || amount <= 0) {
      alert("Please enter a valid BTC amount to mint.");
      return;
    }
    mintBtc([{
      amount: toFixedPoint(amount, 8) ?? 0n,
      to: account,
    }]).catch((error) => {
      console.error(error);
    }).finally(() => {
      refreshBtcBalance();
    });
  };

  const triggerUsdtMint = () => {
    const amount = Number(usdtMintAmount);
    if (isNaN(amount) || amount <= 0) {
      alert("Please enter a valid USDT amount to mint.");
      return;
    }
    mintUsdt([{
      amount: toFixedPoint(amount, 6) ?? 0n,
      to: account,
    }]).catch((error) => {
      console.error(error);
    }).finally(() => {
      refreshUsdtBalance();
    });
  };

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
            { fromFixedPoint(btcBalance, 8) ?? 0 }
          </span>
        )}
      </div>
      {/* BTC Mint Input & Button */}
      <div className="flex flex-row items-center space-x-2 mt-3">
        <input
          type="number"
          min="0"
          value={btcMintAmount}
          onChange={e => setBtcMintAmount(e.target.value)}
          className="w-32 h-9 border dark:border-gray-300 border-gray-900 rounded px-2 appearance-none focus:outline outline-1 outline-purple-500 bg-gray-100 dark:bg-gray-900 text-right"
        />
        <button
          className="px-10 button-simple h-10 justify-center items-center text-lg"
          onClick={triggerBtcMint}
          disabled={mintBtcLoading}
        >
          Mint BTC
        </button>
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
          { fromFixedPoint(usdtBalance ?? 0n, 6) }
        </span>
      </div>
      {/* USDT Mint Input & Button */}
      <div className="flex flex-row items-center space-x-2 mt-3">
        <input
          type="number"
          min="0"
          value={usdtMintAmount}
          onChange={e => setUsdtMintAmount(e.target.value)}
          className="w-32 h-9 border dark:border-gray-300 border-gray-900 rounded px-2 appearance-none focus:outline outline-1 outline-purple-500 bg-gray-100 dark:bg-gray-900 text-right"
        />
        <button
          className="px-10 button-simple h-10 justify-center items-center text-lg"
          onClick={triggerUsdtMint}
          disabled={mintUsdtLoading}
        >
          Mint USDT
        </button>
      </div>
    </div>
    </div>
  );
}

export default Wallet;