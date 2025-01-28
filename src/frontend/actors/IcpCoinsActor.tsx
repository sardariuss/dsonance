import { createActorContext }                from "@ic-reactor/react"
import { icp_coins, canisterId, idlFactory } from "../../declarations/icp_coins"

export type IcpCoins = typeof icp_coins

export const { ActorProvider: IcpCoinsActorProvider, ...icpCoinsActor } = createActorContext<IcpCoins>({
  canisterId,
  idlFactory,
})
