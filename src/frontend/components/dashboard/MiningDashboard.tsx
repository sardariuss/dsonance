import { useMemo, useContext } from "react";
import { ResponsivePie } from '@nivo/pie';
import { protocolActor } from "../actors/ProtocolActor";
import DualLabel from "../common/DualLabel";
import { ThemeContext } from "../App";
import { FullTokenLabel } from "../common/TokenLabel";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";
import { useProtocolContext } from "../context/ProtocolContext";
import { DASHBOARD_CONTAINER, STATS_OVERVIEW_CONTAINER, VERTICAL_DIVIDER, METRICS_WRAPPER, CONTENT_PANEL } from "../../utils/styles";
import EmissionCurveChart from "../charts/EmissionCurveChart";

interface TwvAccount {
  owner: { toText(): string } | string;
  subaccount?: number[];
}

interface MiningTracker {
  claimed: bigint;
  allocated: bigint;
}

type MiningData = [TwvAccount, MiningTracker];

interface TimedData<T> {
  timestamp: bigint;
  data: T;
}

interface RollingTimeline<T> {
  current: TimedData<T>;
  history: TimedData<T>[];
  maxSize: bigint;
  minInterval: bigint;
}

const MiningDashboard = () => {
  const { theme } = useContext(ThemeContext);
  const { participationLedger : { formatAmount, totalSupply, metadata } } = useFungibleLedgerContext();
  const { parameters, info } = useProtocolContext();
  const { data: miningTrackers } = protocolActor.unauthenticated.useQueryCall({
    functionName: 'get_mining_trackers',
    args: [],
  });
  const { data: totalAllocatedTimeline } = protocolActor.unauthenticated.useQueryCall({
    functionName: 'get_mining_total_allocated',
    args: [],
  });
  const { data: totalClaimedTimeline } = protocolActor.unauthenticated.useQueryCall({
    functionName: 'get_mining_total_claimed',
    args: [],
  });

  const miningStats = useMemo(() => {
    if (!miningTrackers) {
      return {
        totalMinted: 0n,
        mintRemaining: undefined,
        distributionData: [],
      };
    }

    const data = miningTrackers as MiningData[];
    let totalMinted = 0n;

    const distributionData = data.map(([account, tracker]) => {
      const claimed = tracker.claimed;
      const allocated = tracker.allocated;
      const total = claimed + allocated;

      totalMinted += total;

      const ownerText = typeof account.owner === 'string'
        ? account.owner
        : account.owner.toText();

      return {
        id: ownerText,
        label: `${ownerText.slice(0, 8)}...${ownerText.slice(-4)}`,
        value: Number(total),
        claimed: Number(claimed),
        allocated: Number(allocated),
      };
    }).filter(item => item.value > 0); // Only show accounts with TWV

    let mintRemaining = undefined;
    if (parameters?.mining.emission_total_amount) {
      mintRemaining = parameters.mining.emission_total_amount - totalMinted;
    }

    return {
      totalMinted,
      mintRemaining,
      distributionData,
    };
  }, [miningTrackers, parameters]);

  if (!miningTrackers) {
    return <div className="text-center text-gray-500">Loading TWV stats...</div>;
  }

  return (
    <div className={DASHBOARD_CONTAINER}>
      <div className={STATS_OVERVIEW_CONTAINER}>
        <FullTokenLabel
          metadata={metadata}
          canisterId={process.env.TWV_LEDGER_CANISTER_ID || ""} // @todo: should come from participationLedger
        />
        <div className={VERTICAL_DIVIDER}></div>
        <div className={METRICS_WRAPPER}>
          <DualLabel
            top="Total supply"
            bottom={formatAmount(totalSupply)}
          />
          <DualLabel
            top="Total minted"
            bottom={formatAmount(miningStats.totalMinted)}
          />
          <DualLabel
            top="Mint remaining"
            bottom={formatAmount(miningStats.mintRemaining)}
          />
        </div>
      </div>

      {/* Emission Curve */}
      {parameters && info && totalAllocatedTimeline && totalClaimedTimeline && (
        <div className={CONTENT_PANEL}>
          <h3 className="text-lg font-semibold mb-2 text-gray-800 dark:text-gray-200">
            Mining Overview
          </h3>
          <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
            Historical total mined TWV (left axis) and theoretical emission rate curve (right axis)
          </p>
          <EmissionCurveChart
            genesisTime={info.genesis_time}
            currentTime={info.current_time}
            emissionTotalAmount={parameters.mining.emission_total_amount}
            emissionHalfLifeS={parameters.mining.emission_half_life_s}
            totalAllocatedTimeline={totalAllocatedTimeline as RollingTimeline<bigint>}
            totalClaimedTimeline={totalClaimedTimeline as RollingTimeline<bigint>}
            formatAmount={(amount) => formatAmount(amount) || '0'}
          />
        </div>
      )}

      {/* Distribution Chart */}
      {miningStats.distributionData.length > 0 && miningStats.totalMinted > 0n && (
        <div className={CONTENT_PANEL}>
          <h3 className="text-lg font-semibold mb-4 text-gray-800 dark:text-gray-200">
            Distribution by Account
          </h3>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Pie Chart */}
            <div className="h-64 md:h-80">
              {miningStats.distributionData.length >= 1 ? (
                <ResponsivePie
                  data={miningStats.distributionData.slice(0, 10).filter(d => d.value > 0).map(d => ({
                    ...d,
                    value: Math.max(d.value, 1) // Ensure minimum value of 1 to prevent animation issues
                  }))}
                  margin={{ top: 40, right: 80, bottom: 80, left: 80 }}
                  innerRadius={0.5}
                  padAngle={0.7}
                  cornerRadius={3}
                  activeOuterRadiusOffset={8}
                  colors={{ scheme: 'nivo' }}
                  borderWidth={1}
                  borderColor={{
                    from: 'color',
                    modifiers: [['darker', 0.2]]
                  }}
                  arcLinkLabelsSkipAngle={10}
                  arcLinkLabelsTextColor={theme === 'dark' ? '#e5e7eb' : '#374151'}
                  arcLinkLabelsThickness={2}
                  arcLinkLabelsColor={{ from: 'color' }}
                  arcLabelsSkipAngle={10}
                  arcLabelsTextColor={{
                    from: 'color',
                    modifiers: [['darker', 2]]
                  }}
                  animate={false} // Disable animations to prevent useArcsTransition errors
                  tooltip={({ datum }) => (
                    <div className="bg-white dark:bg-gray-800 p-2 rounded shadow-lg border border-gray-200 dark:border-gray-700">
                      <div className="font-mono text-xs">{datum.data?.label || 'Unknown'}</div>
                      <div className="text-sm font-semibold">{formatAmount(datum.value)} TWV</div>
                      <div className="text-xs text-gray-600 dark:text-gray-400">
                        {miningStats.totalMinted > 0n ? ((datum.value / Number(miningStats.totalMinted)) * 100).toFixed(2) : '0.00'}% of total
                      </div>
                    </div>
                  )}
                  theme={{
                    background: 'transparent',
                    text: {
                      fill: theme === 'dark' ? '#e5e7eb' : '#374151',
                    },
                    tooltip: {
                      container: {
                        background: theme === 'dark' ? '#1f2937' : '#ffffff',
                        color: theme === 'dark' ? '#e5e7eb' : '#374151',
                      }
                    }
                  }}
                />
              ) : (
                <div className="h-64 md:h-80 flex items-center justify-center text-gray-500">
                  No data to display
                </div>
              )}
            </div>
            
            {/* Table */}
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-300 dark:border-gray-700">
                    <th className="text-left p-2">Account</th>
                    <th className="text-right p-2">Mined TWV</th>
                    <th className="text-right p-2">% of Total</th>
                  </tr>
                </thead>
                <tbody>
                  {miningStats.distributionData
                    .sort((a, b) => b.value - a.value)
                    .slice(0, 10) // Show top 10 accounts
                    .map((item) => {
                      const percentage = miningStats.totalMinted > 0n
                        ? (item.value / Number(miningStats.totalMinted) * 100).toFixed(2)
                        : "0.00";

                      return (
                        <tr key={item.id} className="border-b border-gray-200 dark:border-gray-700">
                          <td className="p-2 font-mono text-xs">{item.label}</td>
                          <td className="text-right p-2">{formatAmount(item.value)}</td>
                          <td className="text-right p-2">{percentage}%</td>
                        </tr>
                      );
                    })}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default MiningDashboard;