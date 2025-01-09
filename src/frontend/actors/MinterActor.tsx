import { createActorContext }              from "@ic-reactor/react"
import { minter, canisterId, idlFactory } from "../../declarations/minter"

export type Minter = typeof minter

export const { ActorProvider: MinterActorProvider, ...minterActor } = createActorContext<Minter>({
  canisterId,
  idlFactory,
})
