import { useAuth } from "@ic-reactor/react";
import { useFungibleLedgerContext } from "./context/FungibleLedgerContext";
import Faucet from "./Faucet";
import { FullTokenLabel } from "./common/TokenLabel";
import { canisterId as ckUsdtCanisterId } from "@/declarations/ck_usdt";
import { canisterId as ckBtcCanisterId } from "@/declarations/ck_btc";

const FaucetPage = () => {
  const { authenticated } = useAuth();
  const { supplyLedger, collateralLedger } = useFungibleLedgerContext();

  if (!authenticated) {
    return (
      <div className="flex flex-col items-center justify-center h-64">
        <div className="text-center text-gray-500 dark:text-gray-400">
          <p className="text-lg mb-2">Please log in to access the faucet</p>
          <p className="text-sm">You need to be authenticated to mint tokens</p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col justify-center my-4 p-4 md:p-6 space-y-6">
      <div className="text-center">
        <h1 className="text-2xl font-bold text-gray-800 dark:text-gray-200 mb-2">
          Token Faucet
        </h1>
        <p className="text-gray-600 dark:text-gray-400">
          Mint ckUSDT and ckBTC tokens for testing purposes
        </p>
      </div>
      
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-4xl mx-auto">
        {/* ckUSDT Faucet */}
        <div className="bg-slate-50 dark:bg-slate-850 rounded-lg p-6">
          <div className="flex items-center justify-center mb-4">
            <FullTokenLabel
              metadata={supplyLedger.metadata}
              canisterId={ckUsdtCanisterId}
            />
          </div>
          <div className="mb-4">
            <div className="text-center text-sm text-gray-600 dark:text-gray-400">
              <p>Balance: {supplyLedger.formatAmount(supplyLedger.userBalance)}</p>
              <p>USD Value: {supplyLedger.formatAmountUsd(supplyLedger.userBalance)}</p>
            </div>
          </div>
          <Faucet ledger={supplyLedger} />
        </div>

        {/* ckBTC Faucet */}
        <div className="bg-slate-50 dark:bg-slate-850 rounded-lg p-6">
          <div className="flex items-center justify-center mb-4">
            <FullTokenLabel
              metadata={collateralLedger.metadata}
              canisterId={ckBtcCanisterId}
            />
          </div>
          <div className="mb-4">
            <div className="text-center text-sm text-gray-600 dark:text-gray-400">
              <p>Balance: {collateralLedger.formatAmount(collateralLedger.userBalance)}</p>
              <p>USD Value: {collateralLedger.formatAmountUsd(collateralLedger.userBalance)}</p>
            </div>
          </div>
          <Faucet ledger={collateralLedger} />
        </div>
      </div>
    </div>
  );
};

export default FaucetPage;