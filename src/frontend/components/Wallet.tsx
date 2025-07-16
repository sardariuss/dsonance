import { FullBalance } from "./Balance";
import { useFungibleLedgerContext } from "./context/FungibleLedgerContext";

const Wallet = () => {

  const { supplyLedger, collateralLedger } = useFungibleLedgerContext();

  return (
    <div className="flex flex-col space-y-4 w-full items-center">
      <FullBalance ledger={supplyLedger} amount={supplyLedger.userBalance}/>
      <FullBalance ledger={collateralLedger} amount={collateralLedger.userBalance}/>
    </div>
  );
}

export default Wallet;