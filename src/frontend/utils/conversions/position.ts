import { SPosition, SLockInfo } from "@/declarations/protocol/protocol.did";
import { fromNullable } from "@dfinity/utils";

export const unwrapLock = (position: SPosition) : SLockInfo => {
    const lock = fromNullable(position.lock);
    if (!lock) {
        throw new Error("Lock not found");
    }
    return lock;
}
