import { createActorContext }             from "@ic-reactor/react"
import { ckbtc_ledger, canisterId, idlFactory } from "../../declarations/ckbtc_ledger"

export type CkBtc = typeof ckbtc_ledger

export const { ActorProvider: CkBtcActorProvider, ...ckBtcActor } = createActorContext<CkBtc>({
  canisterId,
  idlFactory,
})
