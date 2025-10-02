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
import { SupplyContent, BorrowContent } from "../borrow/BorrowPage";
import { MiningContent } from "./MiningContent";
import { ViewsContent } from "./ViewsContent";
import DualLabel from "../common/DualLabel";
import { formatAmountCompact } from "@/frontend/utils/conversions/token";
import { TabButton } from "../TabButton";
import { useBorrowOperations } from "../hooks/useBorrowOperations";
import { useLendingCalculations } from "../hooks/useLendingCalculations";

const Profile = () => {

  const { principal } = useParams();
  const { user: connectedUser, disconnect } = useAuth();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const { user, updateNickname } = useUser();
  const [isEditingNickname, setIsEditingNickname] = useState(false);
  const [nicknameInput, setNicknameInput] = useState("");
  const [activeTab, setActiveTab] = useState<'supply' | 'borrow' | 'mining'>('supply');
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
    <div className="flex flex-col w-full sm:w-4/5 md:w-11/12 lg:w-5/6 xl:w-4/5 mx-auto px-3 my-4 sm:my-6">
      <div className="flex flex-col sm:flex-row w-full gap-4 mb-4">
        {/* Profile Summary */}
        <div className="flex flex-col w-full lg:w-1/2 space-y-4 justify-between border-0 sm:border border-gray-300 dark:border-gray-700 rounded-lg p-4">
          <div className="flex flex-row w-full items-center space-x-2">
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
                className="fill-gray-800 justify-self-end hover:fill-black dark:fill-gray-200 dark:hover:fill-white p-2.5 rounded-lg hover:cursor-pointer"
                onClick={()=>{ disconnect(); }}
                to="/">
                <LogoutIcon />
              </Link>
            }
          </div>
          <div className="flex flex-row space-x-4">
            <DualLabel top="Net APY" bottom={`${netApy === undefined ? UNDEFINED_SCALAR : (netApy * 100).toFixed(2) + "%"}`} />
            <div className="h-10 border-l border-gray-300 dark:border-gray-700" />
            <DualLabel top="Health factor" bottom={`${mockValues.healthFactor.toFixed(2)}`} />
            <div className="h-10 border-l border-gray-300 dark:border-gray-700" />
            <DualLabel top="Mining rate" bottom={formatAmountCompact(mockValues.miningRate, 2) + " TVW/day"} />
          </div>
        </div>

        {/* Net Worth Breakdown */}
        <div className="w-full lg:w-1/2 rounded-md border-0 sm:border border-gray-300 dark:border-gray-700 rounded-lg p-4">
          {/* Total */}
          <div className="flex justify-between items-center mb-2 pb-2 border-b border-gray-200 dark:border-gray-600">
            <div className="text-gray-500 dark:text-gray-400 text-sm">Net Worth</div>
            <div className="text-gray-700 dark:text-white text-lg font-semibold">
              ${netWorth.toFixed(2)}
            </div>
          </div>

          {/* Supply Section */}
          <div className="mb-2">
            <div className="text-sm text-gray-600 dark:text-gray-400 mb-0.5">Supply</div>
            <div className="space-y-0.5 pl-3">
              {/* Locked Positions */}
              <div className="flex justify-between">
                <div className="text-sm text-gray-600 dark:text-gray-400">Locked positions</div>
                <div className="text-sm text-gray-900 dark:text-white font-medium">
                  ${mockValues.views.worth.toFixed(2)}
                </div>
              </div>
              {/* Withdrawable */}
              <div className="flex justify-between">
                <div className="text-sm text-gray-600 dark:text-gray-400">Withdrawable</div>
                <div className="text-sm text-gray-900 dark:text-white font-medium">
                  ${mockValues.supply.worth.toFixed(2)}
                </div>
              </div>
            </div>
          </div>

          {/* Other Items */}
          <div className="space-y-0.5">
            {/* Borrow */}
            <div className="flex justify-between">
              <div className="text-sm text-gray-600 dark:text-gray-400">Borrow</div>
              <div className="text-sm text-red-600 dark:text-red-400 font-medium">
                ${mockValues.borrow.worth.toFixed(2)}
              </div>
            </div>

            {/* Collateral (sub-item) */}
            <div className="flex justify-between">
              <div className="text-sm text-gray-600 dark:text-gray-400">Collateral</div>
              <div className="text-sm text-gray-900 dark:text-white font-medium">
                ${mockValues.collateral.worth.toFixed(2)}
              </div>
            </div>

            {/* Mining */}
            <div className="flex justify-between">
              <div className="text-sm text-gray-600 dark:text-gray-400">Mining</div>
              <div className="text-sm text-gray-900 dark:text-white font-medium">
                ${mockValues.mining.worth.toFixed(2)}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Tab Navigation */}
      <ul className="flex flex-wrap gap-x-3 sm:gap-x-6 gap-y-2 mb-4 items-center">
        {[
          { key: 'supply', label: 'Supply' },
          { key: 'borrow', label: 'Borrow' },
          { key: 'mining', label: 'Mining' }
        ].map((tab) => (
          <li key={tab.key} className="min-w-max text-center">
            <TabButton
              label={tab.label}
              setIsCurrent={() => setActiveTab(tab.key as 'supply' | 'borrow' | 'mining')}
              isCurrent={activeTab === tab.key}
            />
          </li>
        ))}
      </ul>

    {/* Tab Content */}
      {activeTab === 'supply' && <SupplyTab user={connectedUser} />}
      {activeTab === 'borrow' && <BorrowTab user={connectedUser} />}
      {activeTab === 'mining' && (
        <MiningContent
          tracker={tracker}
          formatAmount={formatAmount}
          onWithdraw={handleWithdraw}
          withdrawLoading={withdrawLoading}
        />
      )}
    </div>
  );
}

// Views Tab Component
const ViewsTab = ({ user }: { user: NonNullable<ReturnType<typeof useAuth>["user"]> }) => {
  const { supplyLedger } = useFungibleLedgerContext();
  const { account } = useBorrowOperations(user);

  const { data: userSupply } = protocolActor.unauthenticated.useQueryCall({
    functionName: "get_user_supply",
    args: [{ account }],
  });

  return <ViewsContent user={user} userSupply={userSupply} supplyLedger={supplyLedger} />;
};

// Supply Tab Component
const SupplyTab = ({ user }: { user: NonNullable<ReturnType<typeof useAuth>["user"]> }) => {
  const { supplyLedger } = useFungibleLedgerContext();
  const { account } = useBorrowOperations(user);

  const { data: userSupply } = protocolActor.unauthenticated.useQueryCall({
    functionName: "get_user_supply",
    args: [{ account }],
  });

  return <SupplyContent user={user} userSupply={userSupply} supplyLedger={supplyLedger} />;
};

// Borrow Tab Component
const BorrowTab = ({ user }: { user: NonNullable<ReturnType<typeof useAuth>["user"]> }) => {
  const {
    loanPosition,
    previewOperation,
    runOperation,
    supplyLedger,
    collateralLedger,
  } = useBorrowOperations(user);

  const { collateral, currentOwed, maxWithdrawable, maxBorrowable } = useLendingCalculations(
    loanPosition,
    collateralLedger,
    supplyLedger
  );

  return (
    <BorrowContent
      collateral={collateral}
      currentOwed={currentOwed}
      maxWithdrawable={maxWithdrawable}
      maxBorrowable={maxBorrowable}
      collateralLedger={collateralLedger}
      supplyLedger={supplyLedger}
      previewOperation={previewOperation}
      runOperation={runOperation}
    />
  );
};

export default Profile;