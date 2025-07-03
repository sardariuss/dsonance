import { FungibleLedger } from "./hooks/useFungibleLedger";
import { getTokenLogo } from "../utils/metadata";
import { formatAmountUsd } from "../utils/conversions/token";
import DualLabel from "./common/DualLabel";

interface BalanceProps {
  ledger: FungibleLedger;
};

const Balance: React.FC<BalanceProps> = ({ ledger }) => {

  const { userBalance, metadata, formatAmount, convertToUsd } = ledger;

  if (!metadata || !userBalance) {
    return null; // @todo: or show a loading state?
  }

  return (
    <div className="flex flex-row items-center justify-end space-x-2"> 
      <img src={getTokenLogo(metadata)} alt="Logo" className="size-[24px]" />
      <DualLabel 
        top={formatAmount(userBalance)}
        bottom={formatAmountUsd(convertToUsd(userBalance))}
        mainLabel="top"
      />
    </div> 
  );
}

export default Balance;
