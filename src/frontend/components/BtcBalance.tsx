import { Principal } from "@dfinity/principal";
import { ckBtcActor } from "../actors/CkBtcActor";
import { useEffect } from "react";
import BitcoinIcon from "./icons/BitcoinIcon";
import { formatBalanceE8s } from "../utils/conversions/token";
import { useCurrencyContext } from "./CurrencyContext";

interface BtcBalanceProps {
  principal: Principal;
}

const BtcBalance = ({ principal }: BtcBalanceProps) => {

  const { formatSatoshis } = useCurrencyContext();

  const { call: refreshBalance, data: btcBalance } = ckBtcActor.useQueryCall({
    functionName: 'icrc1_balance_of',
    args: [{
      owner: principal,
      subaccount: []
    }]
  });

  useEffect(() => {
    refreshBalance();
  }, []);

  useEffect(() => {
    console.log("Hello")
  }, [btcBalance]);

  return (
    <div className="flex flex-row items-center space-x-1">
      <span className="text-gray-300">Balance:</span>
      <BitcoinIcon />
      <span className="text-lg">
        {btcBalance !== undefined ? formatSatoshis(btcBalance) : ""}
      </span>
    </div>
  );
}

export default BtcBalance;
