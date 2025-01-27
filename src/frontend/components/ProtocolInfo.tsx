import { useEffect, useMemo } from "react";
import DurationChart, { CHART_COLORS } from "./charts/DurationChart";
import { map_filter_timeline, to_number_timeline } from "../utils/timeline";
import { formatBalanceE8s, fromE8s } from "../utils/conversions/token";
import { DISCERNMENT_EMOJI, PARTICIPATION_EMOJI, RESONANCE_TOKEN_SYMBOL } from "../constants";
import { useCurrencyContext } from "./CurrencyContext";
import ResonanceCoinIcon from "./icons/ResonanceCoinIcon";
import BitcoinIcon from "./icons/BitcoinIcon";
import { useProtocolInfoContext } from "./ProtocolInfoContext";

export const computeMintingRate = (ck_btc_locked: bigint, participation_per_ns: number, satoshisToCurrency: (satoshis: bigint) => number) => {
    if (ck_btc_locked === 0n) {
        return undefined;
    }
    return Math.floor(participation_per_ns * 86_400_000_000_000 / satoshisToCurrency(ck_btc_locked));
}

const ProtocolInfo = () => {

    const { formatSatoshis, satoshisToCurrency, currencySymbol } = useCurrencyContext();

    const { info: { protocolParameters, totalLocked, amountMinted }, refreshInfo } = useProtocolInfoContext();

    useEffect(() => {
        refreshInfo();
    }
    , []);

    const participationRate = useMemo(() => {
        if (protocolParameters === undefined || totalLocked === undefined) {
            return undefined;
        }
        return map_filter_timeline(
            to_number_timeline(totalLocked), (value: number) => 
                computeMintingRate(BigInt(value), protocolParameters.participation_per_ns, satoshisToCurrency)
        );
    }, [protocolParameters, satoshisToCurrency]);
      
    return (
        <div className="flex flex-col items-center border-t border-x dark:border-gray-700 border-gray-300 w-2/3">
            { participationRate && <div className="flex flex-col items-center border-b dark:border-gray-700 border-gray-300 pt-4 w-full">
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
            { protocolParameters && 
                <div className="flex flex-row items-center border-b dark:border-gray-700 border-gray-300 py-1 w-full space-x-1 justify-center">
                    <span>{DISCERNMENT_EMOJI}</span>
                    <span className="text-gray-700 dark:text-gray-300">Discernment factor:</span>
                    <span className="text-lg">
                        {protocolParameters.discernment_factor.toFixed(2)}
                    </span>
                </div>
            }
            { totalLocked && 
                <div className="flex flex-col items-center border-b dark:border-gray-700 border-gray-300 pt-4 w-full">
                    <div className="flex flex-row items-center space-x-1">
                        <BitcoinIcon />
                        <div className="text-gray-700 dark:text-gray-300">Total locked:</div>
                        <span className="text-lg">
                            {`${formatSatoshis(totalLocked.current.data)} BTC`}
                        </span>
                    </div>
                    <DurationChart
                        duration_timeline={to_number_timeline(totalLocked)} 
                        format_value={ (value: number) => (formatSatoshis(BigInt(value))) } 
                        fillArea={true}
                        color={CHART_COLORS.YELLOW}
                    />
                </div>
            }
            { amountMinted && 
                <div className="flex flex-col items-center border-b dark:border-gray-700 border-gray-300 pt-4 w-full">
                    <div className="flex flex-row items-center space-x-1">
                        <ResonanceCoinIcon />
                        <div className="text-gray-700 dark:text-gray-300">Resonance minted:</div>
                        <span className="text-lg">
                            {formatBalanceE8s(amountMinted.current.data, RESONANCE_TOKEN_SYMBOL, 0)}
                        </span>
                    </div>
                    <DurationChart
                        duration_timeline={to_number_timeline(amountMinted)}
                        format_value={ (value: number) => `${formatBalanceE8s(BigInt(value), RESONANCE_TOKEN_SYMBOL, 0)}` }
                        fillArea={true}
                        color={CHART_COLORS.GREEN}
                    />
                </div>
            }
        </div>
    )
}

export default ProtocolInfo;