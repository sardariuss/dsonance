import { Link, useParams } from "react-router-dom";
import { useMemo, useState } from "react";

import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY, UNDEFINED_SCALAR } from "../../../frontend/constants";
import LogoutIcon from "../icons/LogoutIcon";
import Avatar from "boring-avatars";
import { useUser } from "../hooks/useUser";
import { useAuth } from "@nfid/identitykit/react";
import { protocolActor } from "../actors/ProtocolActor";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";
import { fromNullableExt } from "@/frontend/utils/conversions/nullable";
import { LendingContent } from "../borrow/BorrowPage";
import { MiningContent } from "./MiningContent";
import DualLabel from "../common/DualLabel";
import { formatAmountCompact } from "@/frontend/utils/conversions/token";
import { TabButton } from "../TabButton";

const Profile = () => {

  const { principal } = useParams();
  const { user: connectedUser, disconnect } = useAuth();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const { user, updateNickname } = useUser();
  const [isEditingNickname, setIsEditingNickname] = useState(false);
  const [nicknameInput, setNicknameInput] = useState("");
  const [activeTab, setActiveTab] = useState<'lending' | 'mining'>('lending');
  const { participationLedger: { formatAmount, refreshUserBalance } } = useFungibleLedgerContext();

  // Fetch participation tracker data
  const { data: participationTracker, call: refetchTracker } = protocolActor.authenticated.useQueryCall({
    functionName: 'get_participation_tracker',
    args: [[]],
  });

  // Withdraw functionality
  const { call: withdrawMined, loading: withdrawLoading } = protocolActor.authenticated.useUpdateCall({
    functionName: 'withdraw_mined',
    onSuccess: () => {
      refetchTracker(); // Refresh data after successful withdrawal
      refreshUserBalance(); // Refresh user balance after successful withdrawal
    },
  });

  const tracker = useMemo(() => {
    return fromNullableExt(participationTracker);
  }, [participationTracker]);

  // Mock values for net worth components (replace with actual data later)
  const mockValues = useMemo(() => ({
    views: { worth: 125.50, apy: 0.0 },
    supply: { worth: 2000.75, apy: 0.0425 }, // 4.25%
    borrow: { worth: -1500.00, apy: -0.0625 }, // -6.25% (negative because it's a cost)
    collateral: { worth: 2200.00, apy: undefined }, // from collateral, no APY
    mining: { worth: 450.25, apy: undefined }, // no APY, just mining rate
    healthFactor: 1.85,
    miningRate: 12.34, // TVW/day
  }), []);

  const netWorth = useMemo(() => {
    return mockValues.views.worth + mockValues.supply.worth + mockValues.borrow.worth + mockValues.collateral.worth + mockValues.mining.worth;
  }, [mockValues]);

  const netApy = useMemo(() => {
    // Weighted average APY (only for supply and borrow)
    const supplyContribution = mockValues.supply.worth * mockValues.supply.apy;
    const borrowContribution = mockValues.borrow.worth * mockValues.borrow.apy;
    const totalContributing = mockValues.supply.worth + Math.abs(mockValues.borrow.worth);
    return totalContributing > 0 ? (supplyContribution + borrowContribution) / totalContributing : 0;
  }, [mockValues]);

  // Early return after all hooks are called
  if (connectedUser === undefined || connectedUser.principal.isAnonymous()) {
    return <div>Invalid principal</div>;
  }

  const handleEditNickname = () => {
    setNicknameInput(user?.nickname || "");
    setIsEditingNickname(true);
  };

  const handleSaveNickname = async () => {
    if (nicknameInput.trim()) {
      const success = await updateNickname(nicknameInput.trim());
      if (success) {
        setIsEditingNickname(false);
      }
    }
  };

  const handleCancelEdit = () => {
    setIsEditingNickname(false);
    setNicknameInput("");
  };

  const handleWithdraw = async () => {
    try {
      await withdrawMined([[]]); // null subaccount
    } catch (error) {
      console.error("Failed to withdraw TWV:", error);
    }
  };

  if (principal !== connectedUser.principal.toString()) {
    return <div>Unauthorized</div>;
  }

  return (
    <div className="flex flex-col w-full sm:w-4/5 md:w-11/12 lg:w-5/6 xl:w-4/5 mx-auto px-3 space-y-4 my-4 sm:my-6">
      <div className="flex flex-col w-full items-center space-y-4 border-0 sm:border border-gray-300 dark:border-gray-700 rounded-lg p-4">
        <div className="flex flex-row items-center space-x-2">
          <Avatar
            size={isMobile ? 40 : 60}
            name={connectedUser.principal.toString()}
            variant="marble"
          />
          <div className="flex flex-col space-y-1">
            {isEditingNickname ? (
              <div className="flex flex-row items-center space-x-2">
                <input
                  type="text"
                  value={nicknameInput}
                  onChange={(e) => setNicknameInput(e.target.value)}
                  className="px-2 py-1 border rounded-md text-sm bg-white dark:bg-gray-700 border-gray-300 dark:border-gray-600 text-gray-900 dark:text-white"
                  placeholder="Enter nickname"
                  autoFocus
                  onKeyDown={(e) => e.key === 'Enter' && handleSaveNickname()}
                />
                <button
                  onClick={handleSaveNickname}
                  className="px-2 py-1 bg-blue-500 text-white rounded-md text-xs hover:bg-blue-600"
                >
                  Save
                </button>
                <button
                  onClick={handleCancelEdit}
                  className="px-2 py-1 bg-gray-500 text-white rounded-md text-xs hover:bg-gray-600"
                >
                  Cancel
                </button>
              </div>
            ) : (
              <span
                className="hover:cursor-pointer hover:text-blue-500 dark:hover:text-blue-400"
                onClick={handleEditNickname}
              >
                {user?.nickname}
              </span>
            )}
            {user?.joinedDate && (
              <span className="text-xs text-gray-600 dark:text-gray-400 self-center">
                Joined {new Date(Number(user.joinedDate) / 1_000_000).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}
              </span>
            )}
          </div>
          { connectedUser.principal.toString() === principal && 
            <Link 
              className="fill-gray-800 hover:fill-black dark:fill-gray-200 dark:hover:fill-white p-2.5 rounded-lg hover:cursor-pointer"
              onClick={()=>{ disconnect(); }}
              to="/">
              <LogoutIcon />
            </Link>
          }
        </div>
        <div className="flex flex-row items-start items-center space-x-4">
          <DualLabel top="Net worth" bottom={`$${formatAmountCompact(netWorth, 2)}`} />
          <div className="h-10 border-l border-gray-300 dark:border-gray-700" />
          <DualLabel top="Net APY" bottom={`${netApy === undefined ? UNDEFINED_SCALAR : (netApy * 100).toFixed(2) + "%"}`} />
          <div className="h-10 border-l border-gray-300 dark:border-gray-700" />
          <DualLabel top="Health factor" bottom={`${mockValues.healthFactor.toFixed(2)}`} />
          <div className="h-10 border-l border-gray-300 dark:border-gray-700" />
          <DualLabel top="Mining rate" bottom={formatAmountCompact(mockValues.miningRate, 2) + " TVW/day"} />
        </div>
      </div>

      {/* Net Worth Breakdown Summary */}
      <div className="w-full">
        <h3 className="text-base font-semibold mb-3 text-gray-900 dark:text-white">Net Worth Breakdown</h3>

        <div className="bg-white dark:bg-slate-800 shadow-md rounded-md p-2 sm:p-4 md:p-6 border border-slate-300 dark:border-slate-700">
          {/* Header */}
          <div className="grid grid-cols-[1fr_auto_auto] gap-8 mb-3 pb-2 border-b border-gray-200 dark:border-gray-600">
            <div className="text-sm font-semibold text-gray-600 dark:text-gray-400"></div>
            <div className="text-sm font-semibold text-gray-600 dark:text-gray-400 text-right">Worth</div>
            <div className="text-sm font-semibold text-gray-600 dark:text-gray-400 text-right min-w-[80px]">APY</div>
          </div>

          {/* Locked Section */}
          <div className="mb-3">
            <div className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Locked</div>
            <div className="grid grid-cols-[1fr_auto_auto] gap-8 pl-4">
              <div className="text-sm text-gray-600 dark:text-gray-400">Views</div>
              <div className="text-sm text-gray-900 dark:text-white text-right font-medium">
                ${mockValues.views.worth.toFixed(2)}
              </div>
              <div className="text-sm text-gray-900 dark:text-white text-right font-medium min-w-[80px]">
                {mockValues.views.apy !== undefined ? `${(mockValues.views.apy * 100).toFixed(2)}%` : UNDEFINED_SCALAR}
              </div>
            </div>
          </div>

          {/* Unlocked Section */}
          <div>
            <div className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Unlocked</div>
            <div className="space-y-1 pl-4">
              {/* Supply */}
              <div className="grid grid-cols-[1fr_auto_auto] gap-8">
                <div className="text-sm text-gray-600 dark:text-gray-400">Supply</div>
                <div className="text-sm text-gray-900 dark:text-white text-right font-medium">
                  ${mockValues.supply.worth.toFixed(2)}
                </div>
                <div className="text-sm text-gray-900 dark:text-white text-right font-medium min-w-[80px]">
                  {mockValues.supply.apy !== undefined ? `${(mockValues.supply.apy * 100).toFixed(2)}%` : UNDEFINED_SCALAR}
                </div>
              </div>

              {/* Borrow */}
              <div className="grid grid-cols-[1fr_auto_auto] gap-8">
                <div className="text-sm text-gray-600 dark:text-gray-400">Borrow</div>
                <div className="text-sm text-red-600 dark:text-red-400 text-right font-medium">
                  ${mockValues.borrow.worth.toFixed(2)}
                </div>
                <div className="text-sm text-red-600 dark:text-red-400 text-right font-medium min-w-[80px]">
                  {mockValues.borrow.apy !== undefined ? `${(mockValues.borrow.apy * 100).toFixed(2)}%` : UNDEFINED_SCALAR}
                </div>
              </div>

              {/* From Collateral (sub-item) */}
              <div className="grid grid-cols-[1fr_auto_auto] gap-8 pl-4">
                <div className="text-sm text-gray-600 dark:text-gray-400 italic">(from collateral)</div>
                <div className="text-sm text-gray-900 dark:text-white text-right font-medium">
                  ${mockValues.collateral.worth.toFixed(2)}
                </div>
                <div className="text-sm text-gray-900 dark:text-white text-right font-medium min-w-[80px]">
                  {UNDEFINED_SCALAR}
                </div>
              </div>

              {/* Mining */}
              <div className="grid grid-cols-[1fr_auto_auto] gap-8">
                <div className="text-sm text-gray-600 dark:text-gray-400">Mining</div>
                <div className="text-sm text-gray-900 dark:text-white text-right font-medium">
                  ${mockValues.mining.worth.toFixed(2)}
                </div>
                <div className="text-sm text-gray-900 dark:text-white text-right font-medium min-w-[80px]">
                  {UNDEFINED_SCALAR}
                </div>
              </div>
            </div>
          </div>

          {/* Total */}
          <div className="grid grid-cols-[1fr_auto_auto] gap-8 mt-3 pt-3 border-t border-gray-200 dark:border-gray-600">
            <div className="text-sm font-semibold text-gray-900 dark:text-white">Total</div>
            <div className="text-sm font-bold text-gray-900 dark:text-white text-right">
              ${netWorth.toFixed(2)}
            </div>
            <div className="text-sm font-bold text-gray-900 dark:text-white text-right min-w-[80px]">
              {(netApy * 100).toFixed(2)}%
            </div>
          </div>
        </div>
      </div>

      {/* Tab Navigation */}
      <ul className="flex flex-wrap gap-x-3 sm:gap-x-6 gap-y-2 mb-4 items-center">
        {[
          { key: 'lending', label: 'Lending' },
          { key: 'mining', label: 'Mining' }
        ].map((tab) => (
          <li key={tab.key} className="min-w-max text-center">
            <TabButton
              label={tab.label}
              setIsCurrent={() => setActiveTab(tab.key as 'lending' | 'mining')}
              isCurrent={activeTab === tab.key}
            />
          </li>
        ))}
      </ul>

      {/* Tab Content */}
      <div className="bg-white dark:bg-slate-800 shadow-md rounded-md p-2 sm:p-4 md:p-6 border border-slate-300 dark:border-slate-700">
        {activeTab === 'lending' && <LendingContent user={connectedUser} />}
        {activeTab === 'mining' && (
          <MiningContent
            tracker={tracker}
            formatAmount={formatAmount}
            onWithdraw={handleWithdraw}
            withdrawLoading={withdrawLoading}
          />
        )}
      </div>
    </div>
  );
}

export default Profile;