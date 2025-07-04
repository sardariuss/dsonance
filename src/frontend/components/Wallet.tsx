import Faucet from "./Faucet";
import { useFungibleLedgerContext } from "./context/FungibleLedgerContext";

const Wallet = () => {

  const { supplyLedger, collateralLedger } = useFungibleLedgerContext();

  return (
    <div className="flex flex-col space-y-4 w-full items-center">
      <Faucet ledger={supplyLedger} />
      <Faucet ledger={collateralLedger} />
    </div>
  );
}

export default Wallet;