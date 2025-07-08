import { LoanPosition } from "../../../declarations/protocol/protocol.did";
import { UNDEFINED_SCALAR } from "../../constants";
import { getHealthColor } from "../../utils/lending";
import { fromNullableExt } from "../../utils/conversions/nullable";

interface HealthFactorProps {
    loan_position: LoanPosition | undefined;
}

const HealthFactor = ({ loan_position }: HealthFactorProps) => {
    const collateral = loan_position?.collateral;
    const loan = fromNullableExt(loan_position?.loan);
    const health = loan?.health;

    let content;

    if (collateral === undefined) {
        content = (
            <span className="text-gray-700 dark:text-white text-lg font-semibold">
                {UNDEFINED_SCALAR}
            </span>
        );
    } else if (collateral > 0n && loan === undefined) {
        content = (
            <span className="text-gray-700 dark:text-white text-lg font-semibold">
                ∞
            </span>
        );
    } else if (health === undefined) {
        content = (
            <span className="text-gray-700 dark:text-white text-lg font-semibold">
                {UNDEFINED_SCALAR}
            </span>
        );
    } else {
        content = (
            <span className={`${getHealthColor(health)}`}>
                {health.toFixed(2)}
            </span>
        );
    }

    return (
        <div className="grid grid-rows-[2fr_3fr] place-items-start">
            <span className="text-gray-500 dark:text-gray-400 text-sm">Health factor</span>
            {content}
        </div>
    );
};

export default HealthFactor;
