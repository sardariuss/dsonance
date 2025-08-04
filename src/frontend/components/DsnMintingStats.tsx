import { useMemo, useContext } from "react";
import { ResponsivePie } from '@nivo/pie';
import { protocolActor } from "../actors/ProtocolActor";
import { formatAmountCompact } from "../utils/conversions/token";
import DualLabel from "./common/DualLabel";
import { ThemeContext } from "./App";

interface DsnAccount {
  owner: { toText(): string } | string;
  subaccount?: number[];
}

interface ParticipationTracker {
  received: bigint;
  owed: bigint;
}

type ParticipationData = [DsnAccount, ParticipationTracker];

const DsnMintingStats = () => {
  const { theme } = useContext(ThemeContext);
  const { data: participationTrackers } = protocolActor.useQueryCall({
    functionName: 'get_participation_trackers',
  });

  const miningStats = useMemo(() => {
    if (!participationTrackers) {
      return {
        totalMinted: 0n,
        totalDistributed: 0n,
        totalPending: 0n,
        distributionData: [],
      };
    }

    const data = participationTrackers as ParticipationData[];
    let totalMinted = 0n;
    let totalDistributed = 0n;
    let totalPending = 0n;
    
    const distributionData = data.map(([account, tracker]) => {
      const received = tracker.received;
      const owed = tracker.owed;
      const total = received + owed;
      
      totalMinted += total;
      totalDistributed += received;
      totalPending += owed;
      
      const ownerText = typeof account.owner === 'string' 
        ? account.owner 
        : account.owner.toText();
        
      return {
        id: ownerText,
        label: `${ownerText.slice(0, 8)}...${ownerText.slice(-4)}`,
        value: Number(total),
        received: Number(received),
        owed: Number(owed),
      };
    }).filter(item => item.value > 0); // Only show accounts with DSN

    return {
      totalMinted,
      totalDistributed,
      totalPending,
      distributionData,
    };
  }, [participationTrackers]);

  if (!participationTrackers) {
    return <div className="text-center text-gray-500">Loading DSN stats...</div>;
  }

  return (
    <div className="space-y-4">
      {/* Stats Overview */}
      <div className="flex flex-col md:flex-row text-center text-gray-800 dark:text-gray-200 space-y-4 md:space-y-0 md:space-x-8 items-center">
        <DualLabel
          top="Total DSN Minted"
          bottom={formatAmountCompact(Number(miningStats.totalMinted), 2)}
        />
        <DualLabel
          top="DSN Distributed"
          bottom={formatAmountCompact(Number(miningStats.totalDistributed), 2)}
        />
        <DualLabel
          top="DSN Pending"
          bottom={formatAmountCompact(Number(miningStats.totalPending), 2)}
        />
        <DualLabel
          top="Active Accounts"
          bottom={miningStats.distributionData.length.toString()}
        />
      </div>

      {/* Distribution Chart */}
      {miningStats.distributionData.length > 0 && miningStats.totalMinted > 0n && (
        <div className="bg-slate-200 dark:bg-gray-800 rounded p-4 md:p-6">
          <h3 className="text-lg font-semibold mb-4 text-gray-800 dark:text-gray-200">
            DSN Distribution by Account
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
                      <div className="text-sm font-semibold">{formatAmountCompact(datum.value || 0, 2)} DSN</div>
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
                    <th className="text-right p-2">Total DSN</th>
                    <th className="text-right p-2">Distributed</th>
                    <th className="text-right p-2">Pending</th>
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
                          <td className="text-right p-2">{formatAmountCompact(item.value, 2)}</td>
                          <td className="text-right p-2">{formatAmountCompact(item.received, 2)}</td>
                          <td className="text-right p-2">{formatAmountCompact(item.owed, 2)}</td>
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

export default DsnMintingStats;