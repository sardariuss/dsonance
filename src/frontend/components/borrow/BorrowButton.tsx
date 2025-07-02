import React, { useMemo, useState } from "react";
import Modal from "../common/Modal";
import { TokenLabel } from "../common/TokenLabel";
import { formatAmountUsd, fromFixedPoint, toFixedPoint } from "../../utils/conversions/token";
import { getTokenName } from "../../utils/metadata";
import { Result_1 } from "@/declarations/protocol/protocol.did";
import Spinner from "../Spinner";
import { getHealthColor } from "../../utils/lending";
import { fromNullable } from "@dfinity/utils";
import useBorrowOperationPreview from "../hooks/useBorrowOperationPreview";
import { FungibleLedger } from "../hooks/useFungibleLedger";

export  enum MaxChoiceType {
  WalletBalance = 0,
  Available = 1,
}

type MaxChoice =
  | { type: MaxChoiceType.WalletBalance; value: bigint; }
  | { type: MaxChoiceType.Available;     value: bigint; };

interface BorrowButtonProps {
  ledger: FungibleLedger;
  title: string;
  previewOperation: (amount: bigint) => Promise<Result_1 | undefined>;
  runOperation: (amount: bigint) => Promise<Result_1 | undefined>;
  health: number;
  maxChoice: MaxChoice;
}

const BorrowButton: React.FC<BorrowButtonProps> = ({
  ledger,
  title,
  previewOperation,
  runOperation,
  health,
  maxChoice,
}) => {

  const [isVisible, setIsVisible] = useState(false);
  const [loading, setLoading] = useState(false);
  // @todo: quite dangerous to have two states (input value and amount) for the same input
  const [inputValue, setInputValue] = useState<string>("");
  const [amount, setAmount] = useState<bigint>(0n);

  const fullTitle = useMemo(
    () => `${title} ${getTokenName(ledger.metadata) ?? ""}`,
  [title, ledger.metadata]);

  const onClick = () => {
    
    if (amount === 0n) {
      throw new Error("Amount must be greater than zero");
    };

    setLoading(true);

    runOperation(amount).then((result) => {
      if (result !== undefined && "ok" in result) {
        setIsVisible(false);
      } else {
        console.error("Borrow failed:", result?.err || "Unknown error");
      }
    }).catch((error) => {
      console.error("Error during borrow:", error);
    }).finally(() => {
      setLoading(false);
    });
  };

  const { preview, loading: loadingPreview } = useBorrowOperationPreview({
    amount,
    previewOperation,
  });

  const healthPreview = useMemo(() => {
    if (preview === undefined) {
      return health;
    }
    if ("ok" in preview) {
      let loan = fromNullable(preview.ok.position.loan);
      return loan?.health;
    }
    return undefined;
  }, [preview]);

  return (
    <>
      <button className="button-blue text-base" onClick={() => setIsVisible(true)}>
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
                      setAmount(toFixedPoint(Number(value), ledger.tokenDecimals) ?? 0n);
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
                  { formatAmountUsd(ledger.convertToUsd(amount)) }
                </span>
              </div>
              <div className="grid grid-rows-[5fr_3fr] justify-items-end">
                <TokenLabel metadata={ledger.metadata}/>
                <div className="flex flex-row items-center justify-center space-x-1 text-xs text-gray-600 dark:text-gray-400">
                  <span>{ maxChoice.type === MaxChoiceType.WalletBalance ? "Wallet balance" : "Available" }</span>
                  <span>{ ledger.formatAmount(maxChoice.value) }</span>
                  <button 
                    className="font-semibold hover:bg-gray-300 dark:hover:bg-gray-700 hover:text-black hover:dark:text-white rounded p-1"
                    onClick={() => {
                      if (ledger.tokenDecimals === undefined) {
                        console.error("Ledger token decimals not defined");
                        return;
                      }
                      let inputEquivalent = fromFixedPoint(maxChoice.value, ledger.tokenDecimals);
                      console.log("Setting max amount: ", inputEquivalent.toString());
                      setInputValue(inputEquivalent.toString());
                      setAmount(maxChoice.value);
                    }}
                    disabled={loading || maxChoice.value === 0n} // Disable if loading or no balance
                  >
                    MAX
                  </button>
                </div>
              </div>
            </div>
          </div>
          <div className="flex flex-col w-full space-y-1">
            <span className="text-gray-600 dark:text-gray-400 text-sm">Transaction overview</span>
            <div className="grid grid-cols-[auto_auto] border border-gray-300 dark:border-gray-700 rounded-md p-2">
              <span className="text-base">Health factor</span>
              <span className="justify-self-end">
                { 
                  loadingPreview ? <Spinner size={"25px"}/> : 
                  healthPreview === undefined ? "N/A" :
                    <span className={`text-base justify-self-end font-semibold ${getHealthColor(healthPreview)}`}>
                      { healthPreview.toFixed(2) }
                    </span>
                }
              </span>
            </div>
          </div>
          <button 
            className={`button-blue text-base w-full`}
            onClick={() => onClick()}
            disabled={loading || amount === 0n} // Disable if loading or no amount
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