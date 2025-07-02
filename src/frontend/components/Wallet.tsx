import { LedgerType } from "./hooks/useFungibleLedger";
import Faucet from "./Faucet";

const Wallet = () => {

  return (
    <div className="flex flex-col space-y-4 w-full items-center">
      <Faucet ledgerType={LedgerType.SUPPLY} />
      <Faucet ledgerType={LedgerType.COLLATERAL} />
    </div>
  );
}

export default Wallet;