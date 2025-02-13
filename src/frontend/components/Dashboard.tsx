import { useEffect, useMemo, useRef, useState } from "react";
import DurationChart, { CHART_COLORS } from "./charts/DurationChart";
import { map_filter_timeline, to_number_timeline } from "../utils/timeline";
import { formatBalanceE8s, fromE8s } from "../utils/conversions/token";
import { MINTING_EMOJI, PARTICIPATION_EMOJI, PRESENCE_COIN_SYMBOL, SIMULATION_EMOJI } from "../constants";
import { useCurrencyContext } from "./CurrencyContext";
import DsonanceCoinIcon from "./icons/DsonanceCoinIcon";
import BitcoinIcon from "./icons/BitcoinIcon";
import { useProtocolContext } from "./ProtocolContext";
import { formatDateTime, timeDifference, timeToDate } from "../utils/conversions/date";
import { formatDuration } from "../utils/conversions/durationUnit";

export const computeMintingRate = (btc_locked: bigint, participation_per_ns: number, satoshisToCurrency: (satoshis: bigint) => number | undefined) => {
    if (btc_locked === 0n) {
        return undefined;
    }
    let amount = satoshisToCurrency(btc_locked);
    if (amount === undefined) {
        return undefined;
    }
    return Math.floor(participation_per_ns * 86_400_000_000_000 / amount);
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
            const participationRate = map_filter_timeline(
                to_number_timeline(info.btc_locked), (value: number) => 
                    computeMintingRate(BigInt(value), parameters.participation_per_ns, satoshisToCurrency));
    
            const dilationFactor = ('SIMULATED' in parameters.clock) ? parameters.clock.SIMULATED.dilation_factor : 1.0;
    
            const intervalNs = BigInt(Math.trunc(Number(parameters.timer.interval_s) * dilationFactor * 1_000_000_000));
    
            const nextRun = timeToDate(info.last_run + intervalNs);

            return {
                participationRate,
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
        if (memo !== undefined && currentTime !== undefined) {
            if (memo.nextRun.getTime() <= currentTime.getTime()) {
                refreshInfo();
            };
        }
    }, [currentTime]);

    useEffect(() => {
    
        const interval = setInterval(() => {
          const now = Date.now();
          const elapsedRealTime = now - lastRealTimeRef.current; // Real-time elapsed in ms
          const simulatedElapsedTime = elapsedRealTime * (memo !== undefined ? memo.dilationFactor : 1.0); // Simulated time elapsed
          lastRealTimeRef.current = now; // Update the last real-time reference
          
          // Update the current time
          setCurrentTime(prevTime =>
            prevTime ? new Date(prevTime.getTime() + simulatedElapsedTime) : undefined
          );
        }, 1000); // Update every 500ms
        
        return () => clearInterval(interval); // Cleanup the timer on unmount
      }, [memo]);
      
    return (
        <div className="flex flex-col items-center border-t border-x dark:border-gray-700 border-gray-300 w-full sm:w-4/5 md:w-3/4 lg:w-2/3">
            {/* TODO: adapt if the protocol is not in simulation */}
            { currentTime && 
                <div className="flex flex-row items-center border-b dark:border-gray-700 border-gray-300 py-2 w-full space-x-1 justify-center">
                    <span>{SIMULATION_EMOJI}</span>
                    <span className="text-gray-700 dark:text-gray-300">Simulation time:</span>
                    <span className="text-lg">
                        {formatDateTime(currentTime)}
                    </span>
                </div>
            }
            { memo && info && currentTime && 
                <div className="flex flex-col items-center border-b dark:border-gray-700 border-gray-300 py-2 w-full space-x-1 justify-center">
                    <div className="flex flex-row items-center space-x-1 justify-center w-full">
                        <span>{MINTING_EMOJI}</span>
                        <span className="text-gray-700 dark:text-gray-300">Minting</span>
                    </div>
                    <div className="flex flex-col sm:grid sm:grid-cols-3 gap-2 w-full">
                        <div className="flex flex-row items-center sm:py-1 w-full space-x-1 justify-center">
                            <span className="text-gray-700 dark:text-gray-300">Every:</span>
                            <span className="text-lg">
                                {formatDuration(memo.intervalNs)}
                            </span>
                        </div>
                        <div className="flex flex-row items-center sm:py-1 w-full space-x-1 justify-center">
                            <span className="text-gray-700 dark:text-gray-300">Last:</span>
                            <span className="text-lg">
                                {formatDateTime(timeToDate(info.last_run))}
                            </span>
                        </div>
                        <div className="flex flex-row items-center sm:py-1 w-full space-x-1 justify-center">
                            <span className="text-gray-700 dark:text-gray-300">Next:</span>
                            <span className="text-lg">
                                { formatDateTime(memo.nextRun) }
                            </span>
                            <span className="text-base">
                                { memo.nextRun.getTime() > currentTime.getTime() ? "(in " + timeDifference(memo.nextRun, currentTime) + ")" : "(now)" }
                            </span>
                        </div>
                    </div>
                </div> 
            }
            { parameters && 
                <div className="flex flex-row items-center border-b dark:border-gray-700 border-gray-300 py-2 w-full space-x-1 justify-center">
                    <span className="text-gray-700 dark:text-gray-300">Age coefficient:</span>
                    <span className="text-lg">
                        {parameters.age_coefficient.toFixed(2)}
                    </span>
                </div>
            }
            { parameters && 
                <div className="flex flex-row items-center border-b dark:border-gray-700 border-gray-300 py-2 w-full space-x-1 justify-center">
                    <span className="text-gray-700 dark:text-gray-300">Max age:</span>
                    <span className="text-lg">
                        {formatDuration(parameters.max_age)}
                    </span>
                </div>
            }
            { memo && memo.participationRate && 
                <div className="flex flex-col items-center border-b dark:border-gray-700 border-gray-300 pt-2 w-full">
                    <div className="flex flex-row items-center space-x-1">
                        <span>{PARTICIPATION_EMOJI}</span>
                        <span className="text-gray-700 dark:text-gray-300">Participation rate:</span>
                        <span className="text-lg">
                            {`${fromE8s(BigInt(memo.participationRate.current.data))} ${PRESENCE_COIN_SYMBOL}/${currencySymbol}/day`}
                        </span>
                    </div>
                    <DurationChart
                        duration_timeline={memo.participationRate}
                        format_value={ (value: number) => `${fromE8s(BigInt(value)).toString()} ${PRESENCE_COIN_SYMBOL}/${currencySymbol}/day` }
                        fillArea={true}
                        color={CHART_COLORS.PURPLE}
                    />
                </div>
            }
            { info && 
                <div className="flex flex-col items-center border-b dark:border-gray-700 border-gray-300 pt-2 w-full">
                    <div className="flex flex-row items-center space-x-1">
                        <BitcoinIcon />
                        <div className="text-gray-700 dark:text-gray-300">Total locked:</div>
                        <span className="text-lg">
                            {`${formatSatoshis(info.btc_locked.current.data)} ckBTC`}
                        </span>
                    </div>
                    <DurationChart
                        duration_timeline={to_number_timeline(info.btc_locked)} 
                        format_value={ (value: number) => (formatSatoshis(BigInt(value)) ?? "") } 
                        fillArea={true}
                        color={CHART_COLORS.YELLOW}
                    />
                </div>
            }
            { info && 
                <div className="flex flex-col items-center border-b dark:border-gray-700 border-gray-300 pt-2 w-full">
                    <div className="flex flex-row items-center space-x-1">
                        <DsonanceCoinIcon />
                        <div className="text-gray-700 dark:text-gray-300">Dsonance minted:</div>
                        <span className="text-lg">
                            {formatBalanceE8s(info.dsn_minted.current.data, PRESENCE_COIN_SYMBOL, 0)}
                        </span>
                    </div>
                    <DurationChart
                        duration_timeline={to_number_timeline(info.dsn_minted)}
                        format_value={ (value: number) => `${formatBalanceE8s(BigInt(value), PRESENCE_COIN_SYMBOL, 0)}` }
                        fillArea={true}
                        color={CHART_COLORS.GREEN}
                    />
                </div>
            }
        </div>
    )
}

export default Dashboard;