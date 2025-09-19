import { Account } from "@/declarations/backend/backend.did";
import { Principal } from "@dfinity/principal";

export const toAccount = ({principal, subaccount}: {principal: Principal; subaccount?: any}): Account => {
  return {
    owner: principal,
    subaccount: subaccount ? [subaccount.toUint8Array()] : [],
  };
};