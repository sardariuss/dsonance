import { useState } from "react";
import { TabButton } from "../TabButton";
import NewVote from "../NewVote";
import { MdConstruction } from "react-icons/md";
import TokenDistributionChart from "../charts/TokenDistributionChart";

const DaoPage = () => {
  const [activeTab, setActiveTab] = useState<'suggest-pool' | 'submit-proposals' | 'vote-proposals' | 'tokenomics'>('tokenomics');

  return (
    <div className="flex flex-col w-full sm:w-4/5 md:w-11/12 lg:w-5/6 xl:w-4/5 mx-auto px-3 my-4 sm:my-6">

      {/* Tab Navigation */}
      <ul className="flex flex-wrap gap-x-3 sm:gap-x-6 gap-y-2 mb-4 items-center">
        {[
          { key: 'tokenomics', label: 'Tokenomics' },
          { key: 'suggest-pool', label: 'Suggest Pool' },
          { key: 'submit-proposals', label: 'Submit Proposals' },
          { key: 'vote-proposals', label: 'Vote on Proposals' }
        ].map((tab) => (
          <li key={tab.key} className="min-w-max text-center">
            <TabButton
              label={tab.label}
              setIsCurrent={() => setActiveTab(tab.key as 'suggest-pool' | 'submit-proposals' | 'vote-proposals' | 'tokenomics')}
              isCurrent={activeTab === tab.key}
            />
          </li>
        ))}
      </ul>

      {/* Tab Content */}
      <div className="bg-white dark:bg-slate-800 shadow-md rounded-md p-2 sm:p-4 md:p-6 border border-slate-300 dark:border-slate-700">
        {activeTab === 'tokenomics' && (
          <div className="flex flex-col space-y-6">
            <div>
              <h3 className="text-xl font-semibold mb-2 text-gray-800 dark:text-gray-200">
                TWV Token Distribution
              </h3>
              <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
                The TWV token serves as the governance token for Towerview. The total supply is 10 million tokens, distributed across five categories.
                TWV holders can lock their tokens in neurons to participate in DAO governance and shape the future of the platform.
              </p>
            </div>
            <TokenDistributionChart />
            <div className="mt-6">
              <a
                href="https://docs.towerview.xyz/tokenomics"
                target="_blank"
                rel="noopener noreferrer"
                className="text-blue-600 dark:text-blue-400 hover:underline text-sm"
              >
                Learn more about TWV tokenomics →
              </a>
            </div>
          </div>
        )}
        {activeTab === 'suggest-pool' && <NewVote />}
        {activeTab === 'submit-proposals' && (
          <div className="flex flex-col items-center justify-center min-h-[40vh] space-y-4">
            <MdConstruction size={64} className="text-gray-400 dark:text-gray-500" />
            <p className="text-lg text-gray-600 dark:text-gray-400">Coming soon!</p>
          </div>
        )}
        {activeTab === 'vote-proposals' && (
          <div className="flex flex-col items-center justify-center min-h-[40vh] space-y-4">
            <MdConstruction size={64} className="text-gray-400 dark:text-gray-500" />
            <p className="text-lg text-gray-600 dark:text-gray-400">Coming soon!</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default DaoPage;
