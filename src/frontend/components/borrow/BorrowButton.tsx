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
  const [amount, setAmount] = useState<bigint>(0n);

  const fullTitle = useMemo(
    () => `${title} ${getTokenName(tokenMetadata) ?? ""}`,
  [title, tokenMetadata]);

  const { satoshisToCurrency } = useCurrencyContext(); // @todo: not gonna work for usdt

  const onClick = () => {
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
                  type="number"
                  placeholder="0.00"
                  className="w-full h-9 appearance-none bg-transparent text-lg"
                  onChange={(e) => {
                    const value = e.target.value;
                    setAmount(value ? BigInt(Math.floor(Number(value) * 1e6)) : 0n);
                  }}
                  value={amount > 0n ? (Number(amount) / 1e6).toFixed(6) : ""}
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
            className="button-blue text-base w-full"
            onClick={() => onClick()}
            disabled={loading}
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