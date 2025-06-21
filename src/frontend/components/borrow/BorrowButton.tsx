import { useMemo, useState } from "react";
import Modal from "../common/Modal";
import { MetaDatum } from "../../../declarations/ck_btc/ck_btc.did";
import TokenLabel from "../common/TokenLabel";
import { formatCurrency } from "../../utils/conversions/token";
import { useCurrencyContext } from "../CurrencyContext";
import { getTokenName } from "../../utils/metadata";
import { Result } from "@/declarations/protocol/protocol.did";
import Spinner from "../Spinner";

interface BorrowButtonProps {
  title: string;
  tokenMetadata: MetaDatum[] | undefined;
  onConfirm: (amount: bigint) => Promise<Result | undefined>;
}

const BorrowButton: React.FC<BorrowButtonProps> = ({ title, tokenMetadata, onConfirm }) => {

  const [isVisible, setIsVisible] = useState(false);
  const [loading, setLoading] = useState(false);
  const [inputValue, setInputValue] = useState<string>("");
  const [amount, setAmount] = useState<bigint>(0n);

  const fullTitle = useMemo(
    () => `${title} ${getTokenName(tokenMetadata) ?? ""}`,
  [title, tokenMetadata]);

  const { satoshisToCurrency } = useCurrencyContext(); // @todo: not gonna work for usdt

  const onClick = () => {
    
    if (amount === 0n) {
      throw new Error("Amount must be greater than zero");
    };

    setLoading(true);

    onConfirm(amount).then((result) => {
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

  return (
    <>
      <button className="button-blue text-base" onClick={() => setIsVisible(true)}>
        {title}
      </button>
      <Modal
        isVisible={isVisible} // Replace with actual state to control modal visibility
        onClose={() => setIsVisible(false) } // Replace with actual close handler
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
                    const value = e.target.value;
                    // Only allow numbers and at most one decimal point
                    if (/^\d*\.?\d*$/.test(value)) {
                      setInputValue(value);

                      const parsed = Number(value);
                      if (!isNaN(parsed)) {
                        const test = BigInt(Math.floor(parsed * 1e6));
                        console.log("Parsed amount:", test);
                        setAmount(BigInt(Math.floor(parsed * 1e6)));
                      } else {
                        setAmount(0n);
                      }
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
                  {formatCurrency(satoshisToCurrency(0), "$")}
                </span>
              </div>
              <div className="grid grid-rows-[5fr_3fr]">
                <TokenLabel metadata={tokenMetadata}/>
                <span className="text-xs text-gray-600 dark:text-gray-400 justify-self-end">
                  test
                </span>
              </div>
            </div>
          </div>
          <div className="flex flex-col w-full space-y-1">
            <span className="text-gray-600 dark:text-gray-400 text-sm">Transaction overview</span>
            <div className="grid grid-cols-[auto_auto] border border-gray-300 dark:border-gray-700 rounded-md p-2">
              <span className="text-base">Health factor</span>
              <span className="text-base justify-self-end">1.54</span>
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