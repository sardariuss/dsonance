import { useAuth } from "@nfid/identitykit/react";
import { useFungibleLedgerContext } from "./context/FungibleLedgerContext";
import Faucet from "./Faucet";
import { FullTokenLabel } from "./common/TokenLabel";
import { canisterId as ckUsdtCanisterId } from "@/declarations/ckusdt_ledger";
import { canisterId as ckBtcCanisterId } from "@/declarations/ckbtc_ledger";

const FaucetPage = () => {
  const { user, connect } = useAuth();
  const { supplyLedger, collateralLedger } = useFungibleLedgerContext();

  const isLoggedIn = !!(user && !user.principal.isAnonymous());

  return (
    <div className="flex flex-col justify-center my-4 p-4 md:p-6 space-y-6">

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-4xl mx-auto">
        {/* ckUSDT Faucet */}
        <div className="bg-white dark:bg-slate-800 shadow-md rounded-lg p-6 border border-slate-300 dark:border-slate-700">
          <div className="flex items-center justify-center mb-4">
            <FullTokenLabel
              metadata={supplyLedger.metadata}
              canisterId={ckUsdtCanisterId}
            />
          </div>
          <div className="mb-4">
            <div className="text-center text-sm text-gray-600 dark:text-gray-400">
              <p>Balance: {isLoggedIn ? supplyLedger.formatAmount(supplyLedger.userBalance) : '—'}</p>
              <p>USD Value: {isLoggedIn ? supplyLedger.formatAmountUsd(supplyLedger.userBalance) : '—'}</p>
            </div>
          </div>
          <Faucet ledger={supplyLedger} onLogin={connect} isLoggedIn={isLoggedIn} />
        </div>

        {/* ckBTC Faucet */}
        <div className="bg-white dark:bg-slate-800 shadow-md rounded-lg p-6 border border-slate-300 dark:border-slate-700">
          <div className="flex items-center justify-center mb-4">
            <FullTokenLabel
              metadata={collateralLedger.metadata}
              canisterId={ckBtcCanisterId}
            />
          </div>
          <div className="mb-4">
            <div className="text-center text-sm text-gray-600 dark:text-gray-400">
              <p>Balance: {isLoggedIn ? collateralLedger.formatAmount(collateralLedger.userBalance) : '—'}</p>
              <p>USD Value: {isLoggedIn ? collateralLedger.formatAmountUsd(collateralLedger.userBalance) : '—'}</p>
            </div>
          </div>
          <Faucet ledger={collateralLedger} onLogin={connect} isLoggedIn={isLoggedIn} />
        </div>
      </div>
    </div>
  );
};

export default FaucetPage;