import { FungibleLedger } from "./hooks/useFungibleLedger";
import { getTokenLogo } from "../utils/metadata";
import DualLabel from "./common/DualLabel";
import { TokenLabel } from "./common/TokenLabel";

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

export const FullBalance: React.FC<BalanceProps> = ({ ledger, amount }) => {

  const { metadata, formatAmount, formatAmountUsd } = ledger;

  if (!metadata || amount === undefined) {
    return null;
  }

  return (
    <div className="flex justify-between w-full items-start">
      <TokenLabel metadata={ledger.metadata} />
      <DualLabel 
        top={formatAmount(ledger.userBalance)}
        bottom={formatAmountUsd(ledger.userBalance)}
        mainLabel="top"
      />
    </div>
  );
}

export default Balance;


