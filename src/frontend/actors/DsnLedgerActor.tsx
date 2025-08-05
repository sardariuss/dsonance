import { createActorContext }             from "@ic-reactor/react"
import { dsn_ledger, canisterId, idlFactory } from "../../declarations/dsn_ledger"

export type DsnLedger = typeof dsn_ledger

export const { ActorProvider: DsnLedgerActorProvider, ...dsnLedgerActor } = createActorContext<DsnLedger>({
  canisterId,
  idlFactory,
})
