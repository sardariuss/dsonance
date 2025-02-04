import { useEffect } from "react";
import BitcoinIcon from "./icons/BitcoinIcon";
import { useCurrencyContext } from "./CurrencyContext";
import { useWalletContext } from "./WalletContext";

const BtcBalance = () => {

  const { formatSatoshis } = useCurrencyContext();
  const { btcBalance, refreshBtcBalance } = useWalletContext();

  useEffect(() => {
    refreshBtcBalance();
  }, []);

  return (
    <div className="flex flex-row items-center space-x-1">
      <span className="text-lg">
        {btcBalance !== undefined ? formatSatoshis(btcBalance) : ""}
      </span>
      <BitcoinIcon />
    </div>
  );
}

export default BtcBalance;
