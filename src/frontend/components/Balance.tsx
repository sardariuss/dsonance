import { FungibleLedger } from "./hooks/useFungibleLedger";
import { getTokenLogo } from "../utils/metadata";
import DualLabel from "./common/DualLabel";

interface BalanceProps {
  ledger: FungibleLedger;
  amount: bigint | number | undefined;
};

const Balance: React.FC<BalanceProps> = ({ ledger, amount }) => {

  const { metadata, formatAmount, formatAmountUsd } = ledger;

  if (!metadata || amount === undefined) {
    return null; // @todo: or show a loading state?
  }

  return (
    <div className="flex flex-row items-center justify-end space-x-2"> 
      <img src={getTokenLogo(metadata)} alt="Logo" className="size-[24px]" />
      <DualLabel 
        top={formatAmount(amount)}
        bottom={formatAmountUsd(amount)}
        mainLabel="top"
      />
    </div> 
  );
}

export default Balance;


