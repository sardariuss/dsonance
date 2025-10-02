import { useState } from "react";
import { TabButton } from "../TabButton";
import NewVote from "../NewVote";
import { MdConstruction } from "react-icons/md";

const DaoPage = () => {
  const [activeTab, setActiveTab] = useState<'suggest-pool' | 'submit-proposals' | 'vote-proposals'>('suggest-pool');

  return (
    <div className="flex flex-col w-full sm:w-4/5 md:w-11/12 lg:w-5/6 xl:w-4/5 mx-auto px-3 my-4 sm:my-6">

      {/* Tab Navigation */}
      <ul className="flex flex-wrap gap-x-3 sm:gap-x-6 gap-y-2 mb-4 items-center">
        {[
          { key: 'suggest-pool', label: 'Suggest Pool' },
          { key: 'submit-proposals', label: 'Submit Proposals' },
          { key: 'vote-proposals', label: 'Vote on Proposals' }
        ].map((tab) => (
          <li key={tab.key} className="min-w-max text-center">
            <TabButton
              label={tab.label}
              setIsCurrent={() => setActiveTab(tab.key as 'suggest-pool' | 'submit-proposals' | 'vote-proposals')}
              isCurrent={activeTab === tab.key}
            />
          </li>
        ))}
      </ul>

      {/* Tab Content */}
      <div className="bg-white dark:bg-slate-800 shadow-md rounded-md p-2 sm:p-4 md:p-6 border border-slate-300 dark:border-slate-700">
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
