import { ResponsivePie } from '@nivo/pie';
import { useContext } from "react";
import { ThemeContext } from "../App";

const TokenDistributionChart = () => {
  const { theme } = useContext(ThemeContext);

  // Initial token distribution from tokenomics.md
  const distributionData = [
    {
      id: 'mining',
      label: 'User Mining Rewards',
      value: 6700000,
      percentage: 67,
      description: 'Distributed to users over time for opening positions and borrowing'
    },
    {
      id: 'community',
      label: 'Community Treasury',
      value: 900000,
      percentage: 9,
      description: 'Reserved for grants, partnerships, and strategic growth'
    },
    {
      id: 'sns',
      label: 'Governance Bootstrap (SNS)',
      value: 900000,
      percentage: 9,
      description: 'SNS decentralization swap for community participation'
    },
    {
      id: 'vesting',
      label: 'Core Builder Vesting',
      value: 900000,
      percentage: 9,
      description: 'Vesting pool for core builder, unlocked via governance'
    },
    {
      id: 'seed',
      label: 'Core Builder Seed',
      value: 600000,
      percentage: 6,
      description: 'Initial allocation to founding developer'
    }
  ];

  const colors = [
    '#60a5fa', // blue-400 - Mining
    '#34d399', // emerald-400 - Community
    '#a78bfa', // violet-400 - SNS
    '#fbbf24', // amber-400 - Vesting
    '#f87171', // red-400 - Seed
  ];

  return (
    <div className="h-96">
      <ResponsivePie
        data={distributionData}
        margin={{ top: 40, right: 200, bottom: 40, left: 40 }}
        innerRadius={0.5}
        padAngle={0.7}
        cornerRadius={3}
        activeOuterRadiusOffset={8}
        colors={colors}
        borderWidth={1}
        borderColor={{
          from: 'color',
          modifiers: [['darker', 0.2]]
        }}
        enableArcLinkLabels={false}
        arcLabelsSkipAngle={10}
        arcLabel={d => `${d.data.percentage}%`}
        arcLabelsTextColor={{
          from: 'color',
          modifiers: [['darker', 2]]
        }}
        legends={[
          {
            anchor: 'right',
            direction: 'column',
            justify: false,
            translateX: 140,
            translateY: 0,
            itemsSpacing: 8,
            itemWidth: 120,
            itemHeight: 20,
            itemTextColor: theme === 'dark' ? '#e5e7eb' : '#374151',
            itemDirection: 'left-to-right',
            itemOpacity: 1,
            symbolSize: 16,
            symbolShape: 'circle',
            effects: [
              {
                on: 'hover',
                style: {
                  itemTextColor: theme === 'dark' ? '#ffffff' : '#000000'
                }
              }
            ]
          }
        ]}
        tooltip={({ datum }) => (
          <div className="bg-white dark:bg-gray-800 p-3 rounded shadow-lg border border-gray-200 dark:border-gray-700 max-w-xs">
            <div className="text-sm font-semibold text-gray-900 dark:text-white mb-1">
              {datum.data.label}
            </div>
            <div className="text-lg font-bold text-gray-900 dark:text-white mb-1">
              {datum.value.toLocaleString()} TWV ({datum.data.percentage}%)
            </div>
            <div className="text-xs text-gray-600 dark:text-gray-400">
              {datum.data.description}
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
    </div>
  );
};

export default TokenDistributionChart;
