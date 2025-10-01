import { useMemo } from "react";
import { fromNullableExt } from "../../utils/conversions/nullable";
import { useProtocolContext } from "../context/ProtocolContext";

export const useLendingCalculations = (
  loanPosition: any,
  collateralLedger: any,
  supplyLedger: any
) => {
  const { parameters } = useProtocolContext();

  const computeMaxWithdrawableUsd = (
    collateralUsd: number | undefined,
    borrowedUsd: number | undefined,
    maxLtv: number | undefined
  ): number => {
    if (
      collateralUsd === undefined ||
      borrowedUsd === undefined ||
      maxLtv === undefined ||
      maxLtv <= 0
    ) {
      return 0;
    }
    const maxWithdrawUsd = Math.max(0, collateralUsd - borrowedUsd / maxLtv);
    return maxWithdrawUsd;
  };

  const computeMaxBorrowableUsd = (
    collateralUsd: number | undefined,
    borrowedUsd: number | undefined,
    maxLtv: number | undefined
  ): number => {
    if (
      collateralUsd === undefined ||
      borrowedUsd === undefined ||
      maxLtv === undefined ||
      maxLtv <= 0
    ) {
      return 0;
    }

    const maxTotalBorrowUsd = collateralUsd * maxLtv;
    const remainingBorrowCapacity = maxTotalBorrowUsd - borrowedUsd;

    return Math.max(0, remainingBorrowCapacity);
  };

  return useMemo(() => {
    const collateral = loanPosition?.collateral ?? 0n;
    const loan = fromNullableExt(loanPosition?.loan);
    const currentOwed = BigInt(Math.ceil((loan as any)?.current_owed ?? 0));

    const collateralUsd = collateralLedger.convertToUsd(collateral);
    const borrowedUsd = supplyLedger.convertToUsd(currentOwed);

    const maxWithdrawableUsd = computeMaxWithdrawableUsd(collateralUsd, borrowedUsd, parameters?.lending.max_ltv);
    const maxWithdrawable = collateralLedger.convertFromUsd(maxWithdrawableUsd) || 0n;

    const maxBorrowableUsd = computeMaxBorrowableUsd(collateralUsd, borrowedUsd, parameters?.lending.max_ltv);
    const maxBorrowable = supplyLedger.convertFromUsd(maxBorrowableUsd) || 0n;

    return {
      collateral,
      currentOwed,
      maxWithdrawable,
      maxBorrowable,
    };
  }, [loanPosition, parameters, collateralLedger, supplyLedger]);
};
