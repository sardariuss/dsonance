import { SPool } from "@/declarations/protocol/protocol.did";
import { EYesNoChoice } from "./yesnochoice";
import { PositionInfo } from "@/frontend/components/types";

export type PoolDetails = {
  yes: number;
  no: number;
  total: number;
  cursor: number | undefined;
};

export const compute_pool_details = (pool: SPool, decay: number): PoolDetails => {
  const aggregate = pool.aggregate.current.data;
  const yes = aggregate.current_yes.DECAYED / decay;
  const no = aggregate.current_no.DECAYED / decay;
  const total = yes + no;
  const cursor = total === 0 ? undefined : yes / total;
  return { total, yes, no, cursor };
}

export const add_position = (details: PoolDetails, position: PositionInfo) : PoolDetails => {
  const total = details.total + Number(position.amount);
  const cursor = total === 0 ? undefined : (details.yes + (position.choice === EYesNoChoice.Yes ? Number(position.amount) : 0)) / total;
  return { ...details, total, cursor };
}

export const deduce_position = (details: PoolDetails, live_cursor: number) : PositionInfo => {
  const { total, yes, cursor } = details;

  const choice = (cursor === undefined || live_cursor > cursor) ? EYesNoChoice.Yes : EYesNoChoice.No;
  const amount = BigInt(Math.floor(choice === EYesNoChoice.No ? (yes / live_cursor - total) : ((live_cursor * total - yes) / (1 - live_cursor))));

  return { choice, amount };
}
