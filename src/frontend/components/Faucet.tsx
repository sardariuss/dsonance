import { FungibleLedger } from "./hooks/useFungibleLedger";
import { getTokenName } from "../utils/metadata";
import { showErrorToast, showSuccessToast } from "../utils/toasts";

interface FaucetProps {
  ledger: FungibleLedger;
  onLogin: () => void;
  isLoggedIn: boolean;
}

const Faucet = ({ ledger, onLogin, isLoggedIn }: FaucetProps) => {

  const triggerMint = () => {
    // If not logged in, redirect to login
    if (!isLoggedIn) {
      onLogin();
      return;
    }

    if (ledger.hasMinted) {
      showErrorToast(`You have already minted ${getTokenName(ledger.metadata)}`, "Mint");
      return;
    }

    ledger.mint().then(() => {
      showSuccessToast(`Successfully minted ${getTokenName(ledger.metadata)}`, "Mint");
    }).catch((error) => {
      showErrorToast(`Failed to mint tokens: ${error.message || error}`, "Mint");
    });
  };

  return (
    <button
      className="px-4 sm:px-10 button-simple h-10 justify-center items-center text-base sm:text-lg whitespace-nowrap disabled:opacity-50 disabled:cursor-not-allowed"
      onClick={triggerMint}
      disabled={ledger.mintLoading || ledger.hasMinted}
    >
      Mint ${getTokenName(ledger.metadata)}
    </button>
  );
}

export default Faucet;