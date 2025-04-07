import { SBallot, SLockInfo } from "@/declarations/protocol/protocol.did";
import { fromNullable } from "@dfinity/utils";

export const unwrapLock = (ballot: SBallot) : SLockInfo => {
    const lock = fromNullable(ballot.lock);
    if (!lock) {
        throw new Error("Lock not found");
    }
    return lock;
}
