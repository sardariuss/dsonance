import { useEffect } from "react";
import BitcoinIcon from "./icons/BitcoinIcon";
import { useCurrencyContext } from "./CurrencyContext";
import { useAllowanceContext } from "./AllowanceContext";

const BtcBalance = () => {

  const { formatSatoshis } = useCurrencyContext();
  const { btcAllowance, refreshBtcAllowance } = useAllowanceContext();

  useEffect(() => {
    refreshBtcAllowance();
  }, []);

  return (
    <div className="flex flex-row items-center space-x-1">
      <span className="text-lg">
        {btcAllowance !== undefined ? formatSatoshis(btcAllowance) : ""}
      </span>
      <BitcoinIcon />
    </div>
  );
}

export default BtcBalance;
