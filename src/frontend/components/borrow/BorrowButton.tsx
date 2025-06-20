import { useState } from "react";
import Modal from "../common/Modal";
import { MetaDatum } from "../../../declarations/ck_btc/ck_btc.did";
import TokenLabel from "../common/TokenLabel";
import { formatCurrency } from "../../utils/conversions/token";
import { useCurrencyContext } from "../CurrencyContext";

interface BorrowButtonProps {
  title: string;
  tokenMetadata: MetaDatum[] | undefined;
}

const BorrowButton: React.FC<BorrowButtonProps> = ({ title, tokenMetadata }) => {

  const [isVisible, setIsVisible] = useState(false);

  const { satoshisToCurrency } = useCurrencyContext(); // @todo: not gonna work for usdt

  return (
    <>
      <button className="button-blue text-base" onClick={() => setIsVisible(true)}>
        {title}
      </button>
      <Modal
        isVisible={isVisible} // Replace with actual state to control modal visibility
        onClose={() => setIsVisible(false) } // Replace with actual close handler
        title={title}
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
          >
            Confirm Borrow
          </button>
        </div>
      </Modal>
    </>
  );
}

export default BorrowButton;