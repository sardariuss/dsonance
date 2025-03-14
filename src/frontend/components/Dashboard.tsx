import { useEffect, useMemo, useRef, useState } from "react";
import DurationChart, { CHART_COLORS } from "./charts/DurationChart";
import { map_filter_timeline, to_number_timeline } from "../utils/timeline";
import { formatBalanceE8s, fromE8s } from "../utils/conversions/token";
import { MINING_EMOJI, DSONANCE_COIN_SYMBOL, SIMULATION_EMOJI, VOTE_EMOJI, FORESIGHT_EMOJI } from "../constants";
import { useCurrencyContext } from "./CurrencyContext";
import BitcoinIcon from "./icons/BitcoinIcon";
import { useProtocolContext } from "./ProtocolContext";
import { formatDateTime, timeDifference, timeToDate } from "../utils/conversions/date";
import { formatDuration } from "../utils/conversions/durationUnit";
import { durationToNs } from "../utils/conversions/duration";

export const computeMintingRate = (btc_locked: bigint, contribution_per_ns: number, satoshisToCurrency: (satoshis: bigint) => number | undefined) => {
    if (btc_locked === 0n) {
        return undefined;
    }
    let amount = satoshisToCurrency(btc_locked);
    if (amount === undefined) {
        return undefined;
    }
    return Math.floor(contribution_per_ns * 86_400_000_000_000 / amount);
}

const Dashboard = () => {

    const { formatSatoshis, satoshisToCurrency, currencySymbol } = useCurrencyContext();

    const { info, parameters, refreshInfo, refreshParameters } = useProtocolContext();

    const [currentTime, setCurrentTime] = useState<Date | undefined>(undefined);
    const lastRealTimeRef = useRef<number>(Date.now()); // Store the last real timestamp

    
    const memo = useMemo(() => {

        if (parameters === undefined || info === undefined) {
            return undefined;
        } else {
            const contributionRate = map_filter_timeline(
                to_number_timeline(info.btc_locked), (value: number) => 
                    computeMintingRate(BigInt(value), parameters.contribution_per_ns, satoshisToCurrency));
    
            const dilationFactor = ('SIMULATED' in parameters.clock) ? parameters.clock.SIMULATED.dilation_factor : 1.0;
    
            const intervalNs = BigInt(Math.trunc(Number(parameters.timer.interval_s) * dilationFactor * 1_000_000_000));
    
            const nextRun = timeToDate(info.last_run + intervalNs);

            return {
                contributionRate,
                dilationFactor,
                intervalNs,
                nextRun
            };
        };

    }, [info, parameters, satoshisToCurrency]);

    useEffect(() => {
        refreshInfo();
        refreshParameters();
    }
    , []);

    useEffect(() => {
        setCurrentTime(info !== undefined ? timeToDate(info.current_time) : undefined);
    },
    [info]);

    useEffect(() => {
    
        const interval = setInterval(() => {
            const now = Date.now();
            const elapsedRealTime = now - lastRealTimeRef.current; // Real-time elapsed in ms
            const simulatedElapsedTime = elapsedRealTime * (memo !== undefined ? memo.dilationFactor : 1.0); // Simulated time elapsed
            lastRealTimeRef.current = now; // Update the last real-time reference
            
            // Update the current time
            setCurrentTime(prevTime => {
                let newTime = prevTime ? new Date(prevTime.getTime() + simulatedElapsedTime) : undefined;
                if (newTime && memo && memo.nextRun.getTime() <= newTime.getTime()) {
                    refreshInfo();
                }
                return newTime;
            });
        }, 1000); // Update every 1 second
        
        return () => clearInterval(interval); // Cleanup the timer on unmount
      }, [memo]);
      
    return (
        <div className="flex flex-col items-center w-full sm:w-4/5 md:w-3/4 lg:w-2/3 p-4 space-y-4">
            {/* TODO: adapt if the protocol is not in simulation */}
            { currentTime && 
                <div className="flex flex-row items-center py-4 w-full space-x-1 justify-center bg-slate-50 dark:bg-slate-850 rounded-lg shadow-md border dark:border-gray-700 border-gray-300">
                    <span>{SIMULATION_EMOJI}</span>
                    <span className="text-gray-700 dark:text-gray-300 text-lg">Simulation time:</span>
                    <span className="text-lg font-semibold">
                        {formatDateTime(currentTime)}
                    </span>
                </div>
            }
            { info && 
                <div className="flex flex-col items-center py-4 w-full bg-slate-50 dark:bg-slate-850 rounded-lg shadow-md border dark:border-gray-700 border-gray-300">
                    <div className="flex flex-row items-center space-x-1">
                        <BitcoinIcon />
                        <div className="text-gray-700 dark:text-gray-300 text-lg">Total locked:</div>
                        <span className="text-lg font-semibold">
                            {`${formatSatoshis(info.btc_locked.current.data)} ckBTC`}
                        </span>
                    </div>
                    <div className="w-full sm:w-2/3">
                        <DurationChart
                            duration_timelines={ new Map([["total_locked", { timeline: to_number_timeline(info.btc_locked), color: CHART_COLORS.YELLOW }]]) }
                            format_value={ (value: number) => (formatSatoshis(BigInt(value)) ?? "") } 
                            fillArea={true}
                        />
                    </div>
                </div>
            }
            { memo && info && currentTime && memo.contributionRate && 
                <div className="flex flex-col items-center py-4 w-full space-x-1 justify-center bg-slate-50 dark:bg-slate-850 rounded-lg shadow-md border dark:border-gray-700 border-gray-300">
                    <div className="flex flex-col items-center w-full sm:w-2/3">
                        <div className="flex flex-row items-center space-x-1">
                            <span>{MINING_EMOJI}</span>
                            <span className="text-gray-700 dark:text-gray-300 text-lg">Mining rate:</span>
                            <span className="text-lg font-semibold">
                                {`${fromE8s(BigInt(memo.contributionRate.current.data))} ${DSONANCE_COIN_SYMBOL}/${currencySymbol}/day`}
                            </span>
                        </div>
                        <DurationChart
                            duration_timelines={ new Map([["mining_rate", { timeline: memo.contributionRate, color: CHART_COLORS.PURPLE }]]) }
                            format_value={ (value: number) => `${fromE8s(BigInt(value)).toString()} ${DSONANCE_COIN_SYMBOL}/${currencySymbol}/day` }
                            fillArea={true}
                        />
                    </div>
                    <div className="flex flex-col w-full sm:w-2/3 px-4">
                        {[
                            { label: "Every:", value: formatDuration(memo.intervalNs) },
                            { label: "Last:", value: formatDateTime(timeToDate(info.last_run)) },
                            { 
                                label: "Next:", 
                                value: `${formatDateTime(memo.nextRun)} ${
                                    memo.nextRun.getTime() > currentTime.getTime() 
                                        ? `(in ${timeDifference(memo.nextRun, currentTime)})` 
                                        : "(now)"
                                }`
                            },
                        ].map(({ label, value }, index) => (
                            <div 
                                key={label} 
                                className={`flex flex-row items-center justify-between pt-2 border-b border-gray-300 dark:border-gray-700`}
                            >
                                <span className="text-gray-700 dark:text-gray-300 font-medium">{label}</span>
                                <span className="text-lg font-semibold">{value}</span>
                            </div>
                        ))}
                    </div>
                </div> 
            }
            { parameters && 
                <div className="flex flex-col items-center p-4 w-full bg-slate-50 dark:bg-slate-850 rounded-lg shadow-md border dark:border-gray-700 border-gray-300">
                    <div className="flex flex-row items-center gap-2 text-lg text-gray-700 dark:text-gray-300">
                        <span>{VOTE_EMOJI}</span>
                        <span>Vote Parameters</span>
                    </div>
                
                    <div className="flex flex-col w-full sm:w-2/3 mt-2">
                        {[
                            { label: "Opening vote fee:", value: formatBalanceE8s(parameters.author_fee, DSONANCE_COIN_SYMBOL, 0) },
                            { label: "Minimum ballot amount:", value: formatSatoshis(parameters.minimum_ballot_amount) },
                            { label: "Ballot half-life:", value: formatDuration(durationToNs(parameters.decay.half_life)) },
                            { label: "Nominal lock duration:", value: formatDuration(durationToNs(parameters.nominal_lock_duration)) },
                        ].map(({ label, value }, index) => (
                            <div 
                                key={label} 
                                className={`flex flex-row items-center justify-between pt-2 border-b border-gray-300 dark:border-gray-700`}
                            >
                                <span className="text-gray-700 dark:text-gray-300 font-medium">{label}</span>
                                <span className="text-lg font-semibold">{value}</span>
                            </div>
                        ))}
                    </div>
                </div>
            }
            {parameters && 
                <div className="flex flex-col items-center p-4 w-full bg-slate-50 dark:bg-slate-850 rounded-lg shadow-md border dark:border-gray-700 border-gray-300">
                    <div className="flex flex-row items-center gap-2 text-lg text-gray-700 dark:text-gray-300">
                        <span>{FORESIGHT_EMOJI}</span>
                        <span>Foresight Parameters</span>
                    </div>

                    <div className="flex flex-col w-full sm:w-2/3 mt-2">
                        {[
                            { label: "Age coefficient:", value: parameters.age_coefficient.toFixed(2) },
                            { label: "Maximum age:", value: formatDuration(parameters.max_age) },
                            { label: "Dissent steepness:", value: parameters.dissent_steepness.toFixed(2) },
                            { label: "Consent steepness:", value: parameters.consent_steepness.toFixed(2) },
                        ].map(({ label, value }, index) => (
                            <div 
                                key={label} 
                                className={`flex flex-row items-center justify-between pt-2 border-b border-gray-300 dark:border-gray-700`}
                            >
                                <span className="text-gray-700 dark:text-gray-300 font-medium">{label}</span>
                                <span className="text-lg font-semibold">{value}</span>
                            </div>
                        ))}
                    </div>
                </div>
            }
        </div>
    )
}

export default Dashboard;