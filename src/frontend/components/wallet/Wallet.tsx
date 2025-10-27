import { useState, useEffect } from "react";
import { MdClose, MdLogout, MdOutlineAccountBalanceWallet } from "react-icons/md";
import { HiOutlineExclamationTriangle } from "react-icons/hi2";
import { LedgerType } from "../hooks/useFungibleLedger";
import WalletRow from "./WalletRow";
import { useAuth } from "@nfid/identitykit/react";
import { toAccount } from "@/frontend/utils/conversions/account";
import { Account } from "@/declarations/ckbtc_ledger/ckbtc_ledger.did";
import { fromNullable, uint8ArrayToHexString } from "@dfinity/utils";
import { Link } from "react-router-dom";

const accountToString = (account: Account | undefined): string => {
  let str = "";
  if (account !== undefined) {
    str = account.owner.toString();
    let subaccount = fromNullable(account.subaccount);
    if (subaccount !== undefined) {
      str += " " + uint8ArrayToHexString(subaccount);
    }
  }
  return str;
};

const truncateAccount = (accountStr: string) => {
  // Truncate to show first 5 and last 3 characters
  if (accountStr.length > 10) {
    return accountStr.substring(0, 5) + "..." + accountStr.substring(accountStr.length - 3);
  }
  return accountStr;
};

interface WalletProps {
  isOpen: boolean;
  onClose: () => void;
}

const Wallet = ({ isOpen, onClose }: WalletProps) => {
  const [activeCard, setActiveCard] = useState<LedgerType | null>(null);
  const [isVisible, setIsVisible] = useState(false);
  const [shouldRender, setShouldRender] = useState(false);
  const [copied, setCopied] = useState(false);
  const { user, disconnect } = useAuth();

  useEffect(() => {
    if (isOpen) {
      setShouldRender(true);
      // Small delay to trigger transition
      setTimeout(() => setIsVisible(true), 10);
      // Check airdrop availability when wallet opens
    } else {
      setIsVisible(false);
      // Remove from DOM after animation completes
      setTimeout(() => setShouldRender(false), 300);
    }
  }, [isOpen]);

  const handleCardClick = (ledgerType: LedgerType) => {
    // Toggle: if clicking the already active card, hide it; otherwise show the new one
    setActiveCard(activeCard === ledgerType ? null : ledgerType);
  };

  // Close drawer when clicking outside
  const handleBackdropClick = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };

  const handleCopy = () => {
    if (user) {
      navigator.clipboard.writeText(accountToString(toAccount(user)));
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  if (!shouldRender) return null;

  return (
    <div
      className={`fixed inset-0 z-50 flex items-center justify-end transition-all duration-300 ease-in-out ${
        isVisible ? "bg-black/50" : "bg-black/0 pointer-events-none"
      }`}
      onClick={handleBackdropClick}
    >
      <div
        className={`h-full w-full sm:w-96 transform bg-white shadow-lg transition-transform duration-300 ease-out dark:bg-gray-800 ${
          isVisible ? "translate-x-0" : "translate-x-full"
        }`}
      >
        {/* Header */}
        <div className="flex flex-rpw border-b border-gray-200 p-4 dark:border-gray-700 justify-between">
          <div className="flex flex-row items-center gap-2">
            <MdOutlineAccountBalanceWallet size={24} className="text-black dark:text-white" />
            <h2 className="text-xl font-semibold text-black dark:text-white">Wallet</h2>
            {user && (
              <div className="relative">
                <span
                  className="text-gray-800 hover:text-black dark:text-gray-200 dark:hover:text-white bg-gray-200 dark:bg-gray-700 rounded-md px-3 py-1.5 text-sm font-medium hover:cursor-pointer inline-block"
                  onClick={handleCopy}
                >
                  {truncateAccount(accountToString(toAccount(user)))}
                </span>
                {copied && (
                  <div className="absolute top-8 left-1/2 transform -translate-x-1/2 bg-gray-900 text-white text-xs rounded px-2 py-1 whitespace-nowrap">
                    Copied!
                  </div>
                )}
              </div>
            )}
          </div>
          <div className="flex flex-row items-center gap-2">
            <Link
              className="rounded-full h-8 w-8 flex flex-col items-center justify-center text-gray-500 hover:bg-gray-100 hover:text-gray-700 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-200 hover:cursor-pointer"
              onClick={()=>{ disconnect(); onClose(); }}
              to="/">
              <MdLogout />
            </Link>
            <button
              onClick={onClose}
              className="rounded-full h-8 w-8 flex flex-col items-center justify-center text-gray-500 hover:bg-gray-100 hover:text-gray-700 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-200 hover:cursor-pointer"
            >
              <MdClose size={24} />
            </button>
          </div>
        </div>

        {/* Testnet Warning */}
        <div className="bg-amber-50 dark:bg-amber-900/20 border-y border-amber-200 dark:border-amber-800 px-4 py-3">
          <div className="flex items-start gap-2">
            <HiOutlineExclamationTriangle className="w-5 h-5 text-amber-600 dark:text-amber-400 flex-shrink-0 mt-0.5" />
            <div className="flex-1 min-w-0">
              <p className="text-sm text-amber-900 dark:text-amber-100">
                <span className="font-semibold">Testnet tokens only.</span> Do not send real assets. All funds will be lost!
              </p>
            </div>
          </div>
        </div>

        {/* Content */}
        <div className="flex flex-col gap-4 p-4">
          <WalletRow 
            ledgerType={LedgerType.SUPPLY}
            showActions={activeCard === LedgerType.SUPPLY}
            onCardClick={handleCardClick}
            isActive={activeCard === null || activeCard === LedgerType.SUPPLY}
          />
          <WalletRow 
            ledgerType={LedgerType.COLLATERAL}
            showActions={activeCard === LedgerType.COLLATERAL}
            onCardClick={handleCardClick}
            isActive={activeCard === null || activeCard === LedgerType.COLLATERAL}
          />
          <WalletRow 
            ledgerType={LedgerType.PARTICIPATION}
            showActions={activeCard === LedgerType.PARTICIPATION}
            onCardClick={handleCardClick}
            isActive={activeCard === null || activeCard === LedgerType.PARTICIPATION}
          />
        </div>
      </div>
    </div>
  );
};

export default Wallet;