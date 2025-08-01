import { createActorContext }                       from "@ic-reactor/react"
import { ckusdt_ledger, canisterId, idlFactory }  from "../../declarations/ckusdt_ledger"

export type CkUsdt = typeof ckusdt_ledger

export const { ActorProvider: CkUsdtActorProvider, ...ckUsdtActor } = createActorContext<CkUsdt>({
  canisterId,
  idlFactory,
})
