import { createActorContext }                       from "@ic-reactor/react"
import { dsonance_ledger, canisterId, idlFactory } from "../../declarations/dsonance_ledger"

export type DsonanceLedger = typeof dsonance_ledger

export const { ActorProvider: DsonanceLedgerActorProvider, ...dsonanceLedgerActor } = createActorContext<DsonanceLedger>({
  canisterId,
  idlFactory,
})
