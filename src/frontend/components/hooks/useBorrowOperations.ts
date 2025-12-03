import { useMemo } from "react";
import { useAuth } from "@nfid/identitykit/react";
import { Account } from "@/declarations/ckbtc_ledger/ckbtc_ledger.did";
import { OperationKind, Result_1 } from "@/declarations/protocol/protocol.did";
import { protocolActor } from "../actors/ProtocolActor";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";
import { useProtocolContext } from "../context/ProtocolContext";
import { showErrorToast, extractErrorMessage } from "../../utils/toasts";

export const useBorrowOperations = (user: NonNullable<ReturnType<typeof useAuth>["user"]>) => {
  const account: Account = useMemo(() => ({
    owner: user.principal,
    subaccount: []
  }), [user]);

  const { supplyLedger, collateralLedger } = useFungibleLedgerContext();
  const { lendingIndexTimeline, refreshLendingIndex: refreshIndexerState } = useProtocolContext();

  const indexerState = lendingIndexTimeline?.current.data;

  const { data: loanPosition, call: refreshLoanPosition } = protocolActor.unauthenticated.useQueryCall({
    functionName: 'get_loan_position',
    args: [account]
  });

  const { call: previewBorrowOperation } = protocolActor.authenticated.useUpdateCall({
    functionName: 'preview_borrow_operation',
  });

  const { call: runBorrowOperation } = protocolActor.authenticated.useUpdateCall({
    functionName: 'run_borrow_operation',
  });

  const previewOperation = (amount: bigint, kind: OperationKind): Promise<Result_1 | undefined> => {
    try {
      return previewBorrowOperation([{ subaccount: [], amount, kind }]) as Promise<Result_1 | undefined>;
    } catch (error) {
      console.error("Error previewing borrow operation:", error);
      showErrorToast(extractErrorMessage(error), "Preview operation");
      return Promise.resolve(undefined);
    }
  };

  const runOperation = (amount: bigint, kind: OperationKind): Promise<Result_1 | undefined> => {
    try {
      const prerequisite = (() => {
        if ("PROVIDE_COLLATERAL" in kind && amount > 0n) {
          return collateralLedger.approveIfNeeded(amount);
        } else if ("REPAY_SUPPLY" in kind && amount > 0n) {
          return supplyLedger.approveIfNeeded(amount + kind.REPAY_SUPPLY.max_slippage_amount);
        } else {
          return Promise.resolve({ tokenFee: 0n, approveCalled: false });
        }
      })();

      return prerequisite.then(({ tokenFee, approveCalled }) => {
        const finalAmount = amount - tokenFee * (approveCalled ? 2n : 1n);
        return runBorrowOperation([{ subaccount: [], kind, amount: finalAmount }]).then((result) => {
          if (result !== undefined && "ok" in result) {
            refreshLoanPosition();
            refreshIndexerState();
            supplyLedger.refreshUserBalance();
            collateralLedger.refreshUserBalance();
          }
          return result as Result_1 | undefined;
        });
      });
    } catch (error) {
      console.error("Error running borrow operation:", error);
      showErrorToast(extractErrorMessage(error), "Run operation");
      return Promise.resolve(undefined);
    }
  };

  return {
    account,
    indexerState,
    loanPosition,
    refreshIndexerState,
    refreshLoanPosition,
    previewOperation,
    runOperation,
    supplyLedger,
    collateralLedger,
  };
};
