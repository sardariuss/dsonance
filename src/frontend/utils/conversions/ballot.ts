import { SBallotType, SLockInfo } from "@/declarations/protocol/protocol.did";
import { fromNullable } from "@dfinity/utils";

const NS_IN_YEAR = 31_557_600_000_000_000; // 365.25 * 24 * 60 * 60 * 1_000_000_000

export const unwrapLock = (ballot: SBallotType) : SLockInfo => {
    const lock = fromNullable(ballot.YES_NO.lock);
    if (!lock) {
        throw new Error("Lock not found");
    }
    return lock;
}

export const computeResonance = (ballot: SBallotType) : bigint => {
    const { timestamp, amount, dissent, consent } = ballot.YES_NO;
    const lock = unwrapLock(ballot);
    const age = Number(lock.release_date - timestamp) / NS_IN_YEAR;
    return BigInt(Math.floor(Number(amount) * age * dissent * consent.current.data));
}
