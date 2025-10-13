import { useState } from "react";
import { FungibleLedger } from "./hooks/useFungibleLedger";
import { getTokenName } from "../utils/metadata";
import { showErrorToast, showSuccessToast } from "../utils/toasts";

interface FaucetProps {
  ledger: FungibleLedger;
  onLogin: () => void;
  isLoggedIn: boolean;
}

const Faucet = ({ ledger, onLogin, isLoggedIn }: FaucetProps) => {
  const [mintAmount, setMintAmount] = useState<string>("");

  const triggerMint = () => {
    // If not logged in, redirect to login
    if (!isLoggedIn) {
      onLogin();
      return;
    }

    const amount = Number(mintAmount);
    if (isNaN(amount) || amount <= 0) {
      showErrorToast("Please enter a valid amount to mint.", "Mint");
      return;
    }
    ledger.mint(amount).then(() => {
      setMintAmount("");
      showSuccessToast(`Successfully minted ${amount} ${getTokenName(ledger.metadata)}`, "Mint");
    }).catch((error) => {
      showErrorToast(`Failed to mint tokens: ${error.message || error}`, "Mint");
    });
  };

  return (
    
    <div className="w-full flex flex-col rounded-lg p-3 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800">
      { /* Mint Input & Button */}
      <div className="flex flex-row items-center gap-2 mt-3 justify-end">
        <input
          type="number"
          min="0"
          value={mintAmount}
          onChange={e => setMintAmount(e.target.value)}
          className="flex-1 min-w-0 sm:w-32 sm:flex-initial h-9 border dark:border-gray-300 border-gray-900 rounded px-2 appearance-none focus:outline outline-1 outline-blue-500 bg-gray-100 dark:bg-gray-900 text-right"
        />
        <button
          className="px-4 sm:px-10 button-simple h-10 justify-center items-center text-base sm:text-lg whitespace-nowrap"
          onClick={triggerMint}
          disabled={ledger.mintLoading}
        >
          {`Mint ${getTokenName(ledger.metadata)}`}
        </button>
      </div>
    </div>
  );
}

export default Faucet;