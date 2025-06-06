import { createActorContext }                       from "@ic-reactor/react"
import { ck_usdt, canisterId, idlFactory }  from "../../declarations/ck_usdt"

export type CkUsdt = typeof ck_usdt

export const { ActorProvider: CkUsdtActorProvider, ...ckUsdtActor } = createActorContext<CkUsdt>({
  canisterId,
  idlFactory,
})
