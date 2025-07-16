import { useState } from "react";
import { FungibleLedger } from "./hooks/useFungibleLedger";
import { getTokenName } from "../utils/metadata";

interface FaucetProps {
  ledger: FungibleLedger;
}

const Faucet = ({ ledger }: FaucetProps) => {
  const [mintAmount, setMintAmount] = useState<string>("");

  const triggerMint = () => {
    const amount = Number(mintAmount);
    if (isNaN(amount) || amount <= 0) {
      alert("Please enter a valid amount to mint.");
      return;
    }
    ledger.mint(amount).then(() => {
      setMintAmount("");
    });
  };

  return (
    
    <div className="w-full flex flex-col rounded-lg p-3 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800">
      { /* Mint Input & Button */}
      <div className="flex flex-row items-center space-x-2 mt-3 justify-end">
        <input
          type="number"
          min="0"
          value={mintAmount}
          onChange={e => setMintAmount(e.target.value)}
          className="w-32 h-9 border dark:border-gray-300 border-gray-900 rounded px-2 appearance-none focus:outline outline-1 outline-purple-500 bg-gray-100 dark:bg-gray-900 text-right"
        />
        <button
          className="px-10 button-simple h-10 justify-center items-center text-lg"
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