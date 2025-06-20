import { ckUsdtActor } from "../../actors/CkUsdtActor";
import { protocolActor } from "../../actors/ProtocolActor";
import { ckBtcActor } from "../../actors/CkBtcActor";
import { formatCurrency, fromFixedPoint } from "../../utils/conversions/token";
import { useCurrencyContext } from "../CurrencyContext";
import { fromNullableExt } from "../../utils/conversions/nullable";
import Modal from "../common/Modal";
import { useState } from "react";
import TokenLabel from "../common/TokenLabel";

const BorrowTab = () => {

  const [ showModal, setShowModal ] = useState(false);

  const { data: usdtMetadata } = ckUsdtActor.useQueryCall({
    functionName: 'icrc1_metadata'
  });
  
  const { data: btcMetadata } = ckBtcActor.useQueryCall({
    functionName: 'icrc1_metadata'
  });

  const { data: loan } = protocolActor.useQueryCall({
    functionName: 'get_loan'
  });

  const { satoshisToCurrency } = useCurrencyContext(); // @todo: not gonna work for usdt

  const loanData = fromNullableExt(loan);

  const test = {
    collateral: loanData?.collateral ?? 0n,
    raw_borrowed: loanData?.raw_borrowed ?? 0,
    loan: loanData?.loan ?? 0,
    ltv: loanData?.ltv,
    health: loanData?.health,
    required_repayment: loanData?.required_repayment,
    collateral_to_liquidate: loanData?.collateral_to_liquidate,
  };

  // @todo: if loan data is undefined, use 0 as amountCollateral and amountBorrowed; do not display LTV nor health factor.

  return (
    <div className="flex flex-col justify-center bg-slate-200 dark:bg-gray-800 rounded mt-4 p-6 space-y-6">
      <div className="flex flex-col justify-center w-full">
        <span className="text-xl font-semibold">Your collateral</span>
        <div className="grid grid-cols-[1fr_1fr_1fr_1fr_1fr] items-center gap-6 w-full max-w-5xl mt-4">
          <TokenLabel metadata={usdtMetadata}/>
          <div className="relative flex flex-col">
            <span className="text-lg font-bold"> { formatCurrency(fromFixedPoint(test.collateral, 6), "")} </span>
            <span className="absolute top-6 text-xs text-gray-400"> { formatCurrency(satoshisToCurrency(test.collateral), "$")} </span>
          </div>
          <span>{/*spacer*/}</span>
          <button className="button-blue text-base">
            Supply
          </button>
          <button className="button-blue text-base">
            Withdraw
          </button>
        </div>
      </div>
      <div className="border-b border-gray-300 dark:border-gray-700 w-full"></div>
      <div className="flex flex-col justify-center w-full">
        <span className="text-xl font-semibold">Your borrow</span>
        <div className="grid grid-cols-[1fr_1fr_1fr_1fr_1fr] items-center gap-6 w-full max-w-5xl mt-4">
          <TokenLabel metadata={btcMetadata}/>
          <div className="relative flex flex-col">
            <span className="text-lg font-bold"> { formatCurrency(fromFixedPoint(test.raw_borrowed, 8), "")} </span>
            <span className="absolute top-6 text-xs text-gray-400"> { formatCurrency(satoshisToCurrency(test.raw_borrowed), "$")} </span>
          </div>
          <span>{/*spacer*/}</span>
          <button className="button-blue text-base" onClick={() => setShowModal(true)}>
            Borrow
          </button>
          <button className="button-blue text-base">
            Repay
          </button>
        </div>
      </div>
      <Modal
        isVisible={showModal} // Replace with actual state to control modal visibility
        onClose={() => setShowModal(false) } // Replace with actual close handler
        title="Borrow BTC"
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
                <TokenLabel metadata={btcMetadata}/>
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
    </div>
  );
}

export default BorrowTab;