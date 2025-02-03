import { useEffect, useMemo } from "react";
import DurationChart, { CHART_COLORS } from "./charts/DurationChart";
import { map_filter_timeline, to_number_timeline } from "../utils/timeline";
import { formatBalanceE8s, fromE8s } from "../utils/conversions/token";
import { DISCERNMENT_EMOJI, PARTICIPATION_EMOJI, RESONANCE_TOKEN_SYMBOL } from "../constants";
import { useCurrencyContext } from "./CurrencyContext";
import ResonanceCoinIcon from "./icons/ResonanceCoinIcon";
import BitcoinIcon from "./icons/BitcoinIcon";
import { useProtocolContext } from "./ProtocolContext";
import SimulatedClock from "./SimulatedClock";
import { timeDifference, timeToDate } from "../utils/conversions/date";

export const computeMintingRate = (ck_btc_locked: bigint, participation_per_ns: number, satoshisToCurrency: (satoshis: bigint) => number | undefined) => {
    if (ck_btc_locked === 0n) {
        return undefined;
    }
    let amount = satoshisToCurrency(ck_btc_locked);
    if (amount === undefined) {
        return undefined;
    }
    return Math.floor(participation_per_ns * 86_400_000_000_000 / amount);
}

const Dashboard = () => {

    const { formatSatoshis, satoshisToCurrency, currencySymbol } = useCurrencyContext();

    const { info, parameters, refreshInfo, refreshParameters } = useProtocolContext();

    useEffect(() => {
        refreshInfo();
        refreshParameters();
    }
    , []);

    const participationRate = useMemo(() => {
        if (parameters === undefined || info === undefined) {
            return undefined;
        }
        return map_filter_timeline(
            to_number_timeline(info.ck_btc_locked), (value: number) => 
                computeMintingRate(BigInt(value), parameters.participation_per_ns, satoshisToCurrency)
        );
    }, [parameters, satoshisToCurrency]);
      
    return (
        <div className="flex flex-col items-center border-t border-x dark:border-gray-700 border-gray-300 w-full sm:w-4/5 md:w-3/4 lg:w-2/3">
            <div className="flex flex-col items-center border-b dark:border-gray-700 border-gray-300 py-2 w-full">
                <SimulatedClock />
            </div>
            { parameters && 
                <div className="flex flex-row items-center border-b dark:border-gray-700 border-gray-300 py-2 w-full space-x-1 justify-center">
                    <span>{DISCERNMENT_EMOJI}</span>
                    <span className="text-gray-700 dark:text-gray-300">Dispense interval:</span>
                    <span className="text-lg">
                        {parameters.timer.interval_s.toString()}s
                    </span>
                </div>
            }
            { info && parameters && 
                <div className="flex flex-row items-center border-b dark:border-gray-700 border-gray-300 py-2 w-full space-x-1 justify-center">
                    <span>{DISCERNMENT_EMOJI}</span>
                    <span className="text-gray-700 dark:text-gray-300">Next dispense in:</span>
                    <span className="text-lg">
                        { /* TODO: fix the time difference */ }
                        { timeDifference(timeToDate(info.current_time), timeToDate(info.last_run + parameters.timer.interval_s * 1_000_000_000n) ) }
                    </span>
                </div>
            }
            { parameters && 
                <div className="flex flex-row items-center border-b dark:border-gray-700 border-gray-300 py-2 w-full space-x-1 justify-center">
                    <span>{DISCERNMENT_EMOJI}</span>
                    <span className="text-gray-700 dark:text-gray-300">Discernment factor:</span>
                    <span className="text-lg">
                        {parameters.discernment_factor.toFixed(2)}
                    </span>
                </div>
            }
            { participationRate && <div className="flex flex-col items-center border-b dark:border-gray-700 border-gray-300 pt-2 w-full">
                    <div className="flex flex-row items-center space-x-1">
                        <span>{PARTICIPATION_EMOJI}</span>
                        <span className="text-gray-700 dark:text-gray-300">Participation rate:</span>
                        <span className="text-lg">
                            {`${fromE8s(BigInt(participationRate.current.data))} ${RESONANCE_TOKEN_SYMBOL}/${currencySymbol}/day`}
                        </span>
                    </div>
                    <DurationChart
                        duration_timeline={participationRate}
                        format_value={ (value: number) => `${fromE8s(BigInt(value)).toString()} ${RESONANCE_TOKEN_SYMBOL}/${currencySymbol}/day` }
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
                            {`${formatSatoshis(info.ck_btc_locked.current.data)} BTC`}
                        </span>
                    </div>
                    <DurationChart
                        duration_timeline={to_number_timeline(info.ck_btc_locked)} 
                        format_value={ (value: number) => (formatSatoshis(BigInt(value)) ?? "") } 
                        fillArea={true}
                        color={CHART_COLORS.YELLOW}
                    />
                </div>
            }
            { info && 
                <div className="flex flex-col items-center border-b dark:border-gray-700 border-gray-300 pt-2 w-full">
                    <div className="flex flex-row items-center space-x-1">
                        <ResonanceCoinIcon />
                        <div className="text-gray-700 dark:text-gray-300">Resonance minted:</div>
                        <span className="text-lg">
                            {formatBalanceE8s(info.resonance_minted.current.data, RESONANCE_TOKEN_SYMBOL, 0)}
                        </span>
                    </div>
                    <DurationChart
                        duration_timeline={to_number_timeline(info.resonance_minted)}
                        format_value={ (value: number) => `${formatBalanceE8s(BigInt(value), RESONANCE_TOKEN_SYMBOL, 0)}` }
                        fillArea={true}
                        color={CHART_COLORS.GREEN}
                    />
                </div>
            }
        </div>
    )
}

export default Dashboard;