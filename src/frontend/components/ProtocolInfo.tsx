import { useEffect, useMemo } from "react";
import { protocolActor } from "../actors/ProtocolActor";
import DurationChart from "./charts/DurationChart";
import { map_filter_timeline, to_number_timeline } from "../utils/timeline";
import { fromE8s } from "../utils/conversions/token";
import { RESONANCE_TOKEN_SYMBOL } from "../constants";
import { useCurrencyContext } from "./CurrencyContext";

export const computeMintingRate = (ck_btc_locked: bigint, minting_per_ns: number, satoshisToCurrency: (satoshis: bigint) => number) => {
    if (ck_btc_locked === 0n) {
        return undefined;
    }
    return Math.floor(minting_per_ns * 86_400_000_000_000 / satoshisToCurrency(ck_btc_locked));
}

const ProtocolInfo = () => {

    const { formatSatoshis, satoshisToCurrency, currencySymbol } = useCurrencyContext();

    const { data: protocolInfo, call: refreshProtocolInfo } = protocolActor.useQueryCall({
        functionName: "get_protocol_info",
        args: [],
    });

    useEffect(() => {
        refreshProtocolInfo();
    }
    , []);

    const mintingRate = useMemo(() => {
        if (protocolInfo === undefined) {
            return undefined;
        }
        return map_filter_timeline(
            to_number_timeline(protocolInfo.ck_btc_locked), (value: number) => 
                computeMintingRate(BigInt(value), protocolInfo.minting_per_ns, satoshisToCurrency)
        );
    }, [protocolInfo, satoshisToCurrency]);
      
    return (
        protocolInfo ? (
            <div className="flex flex-col items-center border-t border-x dark:border-gray-700 border-gray-200">
                { mintingRate && <div className="flex flex-col items-center border-b dark:border-gray-700 border-gray-200 pt-4">
                        <div>Minting rate</div>
                        <DurationChart
                            duration_timeline={mintingRate}
                            format_value={ (value: number) => `${fromE8s(BigInt(value)).toString()} ${RESONANCE_TOKEN_SYMBOL}/${currencySymbol}/day` }
                            fillArea={false}
                        />
                    </div>
                }
                <div className="flex flex-col items-center border-b dark:border-gray-700 border-gray-200 pt-4">
                    <div>Amount locked</div>
                    <DurationChart
                        duration_timeline={to_number_timeline(protocolInfo.ck_btc_locked)} 
                        format_value={ (value: number) => (formatSatoshis(BigInt(value))) } 
                        fillArea={true}
                    />
                </div>
            </div>
        ) : <div>Participation Info not found</div>
    )
}

export default ProtocolInfo;