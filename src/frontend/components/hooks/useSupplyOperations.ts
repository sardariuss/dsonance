import { useMemo } from "react";
import { useAuth } from "@nfid/identitykit/react";
import { Account } from "@/declarations/ckbtc_ledger/ckbtc_ledger.did";
import { SupplyOperationKind, Result_2 } from "@/declarations/protocol/protocol.did";
import { protocolActor } from "../actors/ProtocolActor";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";
import { useProtocolContext } from "../context/ProtocolContext";
import { showErrorToast, extractErrorMessage } from "../../utils/toasts";

const WITHDRAW_SLIPPAGE_RATIO = 0.01; // 1% slippage for withdrawals

export const useSupplyOperations = (user: NonNullable<ReturnType<typeof useAuth>["user"]>) => {
  const account: Account = useMemo(() => ({
    owner: user.principal,
    subaccount: []
  }), [user]);

  const { supplyLedger } = useFungibleLedgerContext();
  const { lendingIndexTimeline, refreshLendingIndex: refreshIndexerState } = useProtocolContext();

  const indexerState = lendingIndexTimeline?.current.data;

  const { data: supplyInfo, call: refreshSupplyInfo } = protocolActor.unauthenticated.useQueryCall({
    functionName: 'get_supply_info',
    args: [account]
  });

  const { call: previewSupplyOperation } = protocolActor.authenticated.useUpdateCall({
    functionName: 'preview_supply_operation',
  });

  const { call: runSupplyOperation } = protocolActor.authenticated.useUpdateCall({
    functionName: 'run_supply_operation',
  });

  const previewOperation = (amount: bigint, kind: SupplyOperationKind): Promise<Result_2 | undefined> => {
    try {
      return previewSupplyOperation([{ subaccount: [], amount, kind }]) as Promise<Result_2 | undefined>;
    } catch (error) {
      console.error("Error previewing supply operation:", error);
      showErrorToast(extractErrorMessage(error), "Preview operation");
      return Promise.resolve(undefined);
    }
  };

  const runOperation = (amount: bigint, kind: SupplyOperationKind): Promise<Result_2 | undefined> => {
    try {
      const prerequisite = (() => {
        if ("SUPPLY" in kind && amount > 0n) {
          return supplyLedger.approveIfNeeded(amount);
        } else {
          return Promise.resolve({ tokenFee: 0n, approveCalled: false });
        }
      })();

      return prerequisite.then(({ tokenFee, approveCalled }) => {
        const finalAmount = amount - tokenFee * (approveCalled ? 2n : 1n);
        return runSupplyOperation([{ subaccount: [], kind, amount: finalAmount }]).then((result) => {
          if (result !== undefined && "ok" in result) {
            refreshSupplyInfo();
            refreshIndexerState();
            supplyLedger.refreshUserBalance();
          }
          return result as Result_2 | undefined;
        });
      });
    } catch (error) {
      console.error("Error running supply operation:", error);
      showErrorToast(extractErrorMessage(error), "Run operation");
      return Promise.resolve(undefined);
    }
  };

  return {
    account,
    indexerState,
    supplyInfo,
    refreshIndexerState,
    refreshSupplyInfo,
    previewOperation,
    runOperation,
    supplyLedger,
    WITHDRAW_SLIPPAGE_RATIO,
  };
};
