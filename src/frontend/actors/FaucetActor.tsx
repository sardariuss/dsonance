import { createActorContext }              from "@ic-reactor/react"
import { faucet, canisterId, idlFactory } from "../../declarations/faucet"

export type Faucet = typeof faucet

export const { ActorProvider: FaucetActorProvider, ...faucetActor } = createActorContext<Faucet>({
  canisterId,
  idlFactory,
})
