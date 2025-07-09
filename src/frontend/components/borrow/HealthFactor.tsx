import { LoanPosition } from "../../../declarations/protocol/protocol.did";
import { UNDEFINED_SCALAR } from "../../constants";
import { getHealthColor } from "../../utils/lending";
import { fromNullableExt } from "../../utils/conversions/nullable";
import { useMemo } from "react";

interface HealthFactorProps {
  loanPosition: LoanPosition | undefined;
}

const HealthFactor = ({ loanPosition}: HealthFactorProps) => {
  
  const current = useMemo(() => {
    const collateral = loanPosition?.collateral;
    const loan = fromNullableExt(loanPosition?.loan);
    return { collateral, loan };
  }, [loanPosition]);

  return (
    (current.collateral === undefined || current.collateral === 0n) ? 
        <span className="text-gray-700 dark:text-white text-lg font-semibold">
          {UNDEFINED_SCALAR}
        </span>
    : (current.loan === undefined) ?
      <span className="text-green-500 text-lg font-semibold">
        ∞
      </span> 
    :
      <span className={`${getHealthColor(current.loan.health)}`}>
        {current.loan.health.toFixed(2)}
      </span>
  );

};

export default HealthFactor;
