
export const compute_decay = (time_init: bigint, half_life: bigint, time: bigint) => {
    const lambda = Math.log(2) / Number(half_life);
    const shift = Number(time_init) * lambda;
    return Math.exp(lambda * Number(time) - shift);
};

