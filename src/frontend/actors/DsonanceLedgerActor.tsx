import { createActorContext }                       from "@ic-reactor/react"
import { dsn_ledger, canisterId, idlFactory }  from "../../declarations/dsn_ledger"

export type DsonanceLedger = typeof dsn_ledger

export const { ActorProvider: DsonanceLedgerActorProvider, ...dsonanceLedgerActor } = createActorContext<DsonanceLedger>({
  canisterId,
  idlFactory,
})
