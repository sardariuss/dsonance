import React, { useMemo, useState } from "react";
import Modal from "../common/Modal";
import { TokenLabel } from "../common/TokenLabel";
import { fromFixedPoint, toFixedPoint } from "../../utils/conversions/token";
import { getTokenName, getTokenLogo } from "../../utils/metadata";
import { Result_1, Result_2 } from "@/declarations/protocol/protocol.did";
import Spinner from "../Spinner";
import useBorrowOperationPreview from "../hooks/useBorrowOperationPreview";
import { FungibleLedger } from "../hooks/useFungibleLedger";
import HealthFactor from "./HealthFactor";
import { showErrorToast, showSuccessToast, extractErrorMessage } from "../../utils/toasts";
import { useMiningRatesContext } from "../context/MiningRatesContext";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";
import { HiMiniTrophy } from "react-icons/hi2";

type OperationResult = Result_1 | Result_2;

interface BorrowButtonProps {
  ledger: FungibleLedger;
  title: string;
  previewOperation: (amount: bigint) => Promise<OperationResult | undefined>;
  runOperation: (amount: bigint) => Promise<OperationResult | undefined>;
  maxLabel: string;
  maxAmount: bigint;
  disabled?: boolean;
}

const BorrowButton: React.FC<BorrowButtonProps> = ({
  ledger,
  title,
  previewOperation,
  runOperation,
  maxLabel,
  maxAmount,
  disabled = false,
}) => {

  const [isVisible, setIsVisible] = useState(false);
  const [loading, setLoading] = useState(false);
  // @todo: quite dangerous to have two states (input value and amount) for the same input
  const [inputValue, setInputValue] = useState<string>("");
  const [amount, setAmount] = useState<bigint>(0n);

  const fullTitle = useMemo(
    () => `${title} ${getTokenName(ledger.metadata) ?? ""}`,
  [title, ledger.metadata]);

  // Mining rates calculation (only for borrow operations)
  const { participationLedger } = useFungibleLedgerContext();
  const { miningRates } = useMiningRatesContext();

  const twvLogo = useMemo(() => {
    return getTokenLogo(participationLedger.metadata);
  }, [participationLedger.metadata]);

  // Calculate mining rewards per day if this is a borrow operation
  const isBorrowOperation = title === "Borrow";
  const miningRewardsPerDay = useMemo(() => {
    if (!isBorrowOperation || !miningRates || amount === 0n) {
      return 0;
    }

    return miningRates.calculatePreviewRates({
      additionalBorrow: amount
    }).previewBorrowRatePerToken * Number(amount);
  }, [isBorrowOperation, miningRates, amount]);

  const onClick = () => {
    
    if (amount === 0n) {
      throw new Error("Amount must be greater than zero");
    };

    setLoading(true);

    runOperation(amount).then((result) => {
      if (result !== undefined && "ok" in result) {
        setIsVisible(false);
        showSuccessToast("Operation completed successfully", title);
        // Refresh user balance after successful operation
        ledger.refreshUserBalance();
      } else {
        const errorMsg = result?.err || "Unknown error";
        console.error("Borrow failed:", errorMsg);
        showErrorToast(extractErrorMessage(errorMsg), title);
      }
    }).catch((error) => {
      console.error("Error during borrow:", error);
      showErrorToast(extractErrorMessage(error), title);
    }).finally(() => {
      setLoading(false);
    });
  };

  const { preview, loading: loadingPreview } = useBorrowOperationPreview({
    amount,
    previewOperation,
  });

  const loanPositionPreview = useMemo(() => {
    if (preview !== undefined && "ok" in preview) {
      // Check if this is a borrow operation result (has 'position' field)
      if ("position" in preview.ok) {
        return preview.ok.position;
      }
    }
    return undefined;
  }, [preview]);

  return (
    <>
      <button
        className="px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white font-medium rounded-md transition-colors shadow-sm disabled:bg-gray-400 disabled:cursor-not-allowed disabled:hover:bg-gray-400"
        onClick={() => { setInputValue(""); setAmount(0n); setIsVisible(true) }}
        disabled={disabled}
      >
        {title}
      </button>
      <Modal
        isVisible={isVisible}
        onClose={() => setIsVisible(false) }
        title={fullTitle}
      >
        <div className="flex flex-col w-full text-black dark:text-white space-y-4">
          <div className="flex flex-col w-full space-y-1">
            <span className="text-gray-600 dark:text-gray-400 text-sm">Amount</span>
            <div className="grid grid-cols-[auto_auto] border border-gray-300 dark:border-gray-700 rounded-md px-2 py-1">
              <div className="grid grid-rows-[5fr_3fr]">
                <input
                  type="text"
                  placeholder="0.00"
                  className="w-full h-9 appearance-none outline-none focus:ring-0 focus:outline-none bg-transparent text-lg"
                  value={inputValue}
                  onChange={(e) => {
                    if (ledger.tokenDecimals === undefined) {
                      console.error("Ledger token decimals not defined");
                      return;
                    }

                    const value = e.target.value;
                    // Only allow numbers and at most one decimal point
                    if (/^\d*\.?\d*$/.test(value)) {
                      setInputValue(value);
                      let newAmount = toFixedPoint(Number(value), ledger.tokenDecimals) ?? 0n;

                      if (newAmount > maxAmount) {
                        newAmount = maxAmount;
                        setInputValue(fromFixedPoint(maxAmount, ledger.tokenDecimals).toString());
                      }
                      setAmount(newAmount);
                    }
                  }}
                  onKeyDown={(e) => {
                    const allowedKeys = [
                      "Backspace", "Delete", "ArrowLeft", "ArrowRight",
                      "Home", "End", "Tab", ".", // dot for decimal
                    ];

                    // Allow numbers (0–9), or listed keys
                    if (
                      (e.key.length === 1 && e.key >= "0" && e.key <= "9") ||
                      allowedKeys.includes(e.key)
                    ) {
                      // allow
                      return;
                    }

                    e.preventDefault(); // block everything else
                  }}
                />
                <span className="text-xs text-gray-600 dark:text-gray-400">
                  { ledger.formatAmountUsd(amount) }
                </span>
              </div>
              <div className="grid grid-rows-[5fr_3fr] justify-items-end">
                <TokenLabel metadata={ledger.metadata}/>
                <div className="flex flex-row items-center justify-center space-x-1 text-xs text-gray-600 dark:text-gray-400">
                  <span>{ maxLabel }</span>
                  <span>{ ledger.formatAmount(maxAmount) }</span>
                  <button 
                    className="font-semibold hover:bg-gray-300 dark:hover:bg-gray-700 hover:text-black hover:dark:text-white rounded p-1"
                    onClick={() => {
                      if (ledger.tokenDecimals === undefined) {
                        console.error("Ledger token decimals not defined");
                        return;
                      }
                      let inputEquivalent = fromFixedPoint(maxAmount, ledger.tokenDecimals);
                      setInputValue(inputEquivalent.toString());
                      setAmount(maxAmount);
                    }}
                    disabled={loading || maxAmount === 0n} // Disable if loading or no balance
                  >
                    MAX
                  </button>
                </div>
              </div>
            </div>
          </div>
          {(loanPositionPreview !== undefined || (isBorrowOperation && miningRates && amount > 0n)) && (
            <div className="flex flex-col w-full space-y-1">
              <span className="text-gray-600 dark:text-gray-400 text-sm">Transaction overview</span>
              <div className="flex flex-col border border-gray-300 dark:border-gray-700 rounded-md p-2 gap-2">
                {loanPositionPreview !== undefined && (
                  <div className="grid grid-cols-[auto_auto]">
                    <span className="text-base">Health factor</span>
                    <div className="flex flex-col items-end justify-self-end">
                      { loadingPreview ? <Spinner size={"25px"}/> : <HealthFactor loanPosition={loanPositionPreview}/> }
                      <span className="text-xs text-gray-400 dark:text-gray-500">Liquidation at &lt;1.0</span>
                    </div>
                  </div>
                )}
                {isBorrowOperation && miningRates && amount > 0n && (
                  <>
                    <div className="grid grid-cols-[auto_auto]">
                      <div className="flex items-center gap-2">
                        {twvLogo ? (
                          <img src={twvLogo} alt="TWV" className="w-5 h-5" />
                        ) : (
                          <HiMiniTrophy className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                        )}
                        <span className="text-base">Mining rewards</span>
                      </div>
                      <div className="flex flex-col items-end justify-self-end">
                        <span className="text-base font-semibold">
                          {participationLedger.formatAmount(miningRewardsPerDay)} TWV/day
                        </span>
                      </div>
                    </div>
                  </>
                )}
              </div>
            </div>
          )}
          <button
            className={`button-blue text-base w-full`}
            onClick={() => onClick()}
            disabled={loading || amount === 0n || amount > maxAmount || maxAmount === 0n}
          >
            <div className="flex items-center justify-center space-x-2">
              { loading ? <Spinner size={"25px"}/> : <span>{fullTitle}</span> }
            </div>
          </button>
        </div>
      </Modal>
    </>
  );
}

export default BorrowButton;