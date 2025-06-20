import { fromNullable } from "@dfinity/utils";

export const fromNullableExt = <T>(value: [T] | [] | undefined) : T | undefined => {
  if (value === undefined)
    return undefined;
  else 
    return fromNullable(value);
};