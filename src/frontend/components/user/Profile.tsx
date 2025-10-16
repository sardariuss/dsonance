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
import DualLabel from "../common/DualLabel";
import { TabButton } from "../TabButton";
import { useBorrowOperations } from "../hooks/useBorrowOperations";
import { useLendingCalculations } from "../hooks/useLendingCalculations";
import { useProtocolContext } from "../context/ProtocolContext";
import HealthFactor from "../borrow/HealthFactor";
import { useMiningRatesContext } from "../context/MiningRatesContext";
import { aprToApy } from "@/frontend/utils/lending";

const Profile = () => {

  const { principal } = useParams();
  const { user: connectedUser, disconnect } = useAuth();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const { user, updateNickname } = useUser();
  const [isEditingNickname, setIsEditingNickname] = useState(false);
  const [nicknameInput, setNicknameInput] = useState("");
  const [activeTab, setActiveTab] = useState<'supply' | 'borrow' | 'mining'>('supply');
  
  const { participationLedger, supplyLedger, collateralLedger } = useFungibleLedgerContext();
  const { lendingIndexTimeline, info } = useProtocolContext();
  const { miningRates } = useMiningRatesContext();

  // Fetch loan position data
  const { data: loanPosition } = protocolActor.unauthenticated.useQueryCall({
    functionName: 'get_loan_position',
    args: connectedUser ? [{ owner: connectedUser.principal, subaccount: [] }] : undefined,
  });

  // TODO: create query in backend to get whole supply worth
  // Fetch user's active ballots to calculate locked supply
  const { data: userBallots } = protocolActor.unauthenticated.useQueryCall({
    functionName: 'get_ballots',
    args: connectedUser ? [{
      account: { owner: connectedUser.principal, subaccount: [] },
      previous: [],
      limit: 100n,
      filter_active: true
    }] : undefined,
  });

  // Fetch mining tracker data
  const { data: miningTracker, call: refetchTracker } = protocolActor.authenticated.useQueryCall({
    functionName: 'get_mining_tracker',
    args: [[]],
  });

  // Withdraw functionality
  const { call: withdrawMined, loading: withdrawLoading } = protocolActor.authenticated.useUpdateCall({
    functionName: 'claim_mining_rewards',
    onSuccess: () => {
      refetchTracker(); // Refresh data after successful withdrawal
      participationLedger.refreshUserBalance(); // Refresh user balance after successful withdrawal
    },
  });

  const tracker = useMemo(() => {
    return fromNullableExt(miningTracker);
  }, [miningTracker]);

  // Calculate locked supply from user's active ballots and weighted average APR
  const { lockedSupplyWorth, lockedSupplyAmount } = useMemo(() => {
    if (!userBallots || !lendingIndexTimeline || !info) {
      return { lockedSupplyWorth: 0, lockedSupplyAmount: 0 };
    }

    const currentSupplyIndex = lendingIndexTimeline.current.data.supply_index.value;
    let totalWorth = 0;
    let totalAmount = 0;

    // Sum up the worth and weighted APR of all active ballots
    userBallots.forEach(ballot => {
      // Extract ballot data based on type (YES_NO)
      if ('YES_NO' in ballot) {
        const yesNoBallot = ballot.YES_NO;
        const amount = Number(yesNoBallot.amount);

        totalAmount += amount;

        const ballotSupplyIndex = yesNoBallot.supply_index;
        totalWorth += amount * (currentSupplyIndex / ballotSupplyIndex);
      }
    });

    return {
      lockedSupplyWorth: totalWorth,
      lockedSupplyAmount: totalAmount
    };
  }, [userBallots, lendingIndexTimeline]);

  const { netWorth, instantNetApy } = useMemo(() => {

    let netWorth = undefined;
    let instantNetApy = undefined;

    if (!lendingIndexTimeline) {
      return { netWorth, instantNetApy };
    }

    // Get current APYs
    const supplyApy = aprToApy(lendingIndexTimeline.current.data.supply_rate);
    const borrowApy = aprToApy(lendingIndexTimeline.current.data.borrow_rate);
    
    // Calculate net worth components in USD
    const supplyWorth = supplyLedger.convertToUsd(lockedSupplyWorth) || 0;
    const borrowWorth = supplyLedger.convertToUsd(loanPosition?.loan[0]?.current_owed || 0n) || 0;
    const collateralWorth = collateralLedger.convertToUsd(loanPosition?.collateral || 0n) || 0;
    const miningWorth = participationLedger.convertToUsd(tracker?.allocated || 0n) || 0;

    // Sum up for total net worth
    // TODO: it is confusing if the mining worth is included in net worth,
    // the user might think the net APY applies to the mining worth as well
    netWorth = supplyWorth + collateralWorth - borrowWorth + miningWorth;

    // Calculate instant net APY
    const equity = supplyWorth + collateralWorth - borrowWorth;
    if (equity > 0) {
      instantNetApy = (supplyWorth * supplyApy - borrowWorth * borrowApy) / equity;
    }

    return { netWorth, instantNetApy };
  }, [lendingIndexTimeline, loanPosition, lockedSupplyWorth, supplyLedger, collateralLedger, participationLedger, tracker]);

  const netMiningRate = useMemo(() => {
    if (!miningRates) {
      return undefined;
    }

    let { currentSupplyRatePerToken, currentBorrowRatePerToken } = miningRates;

    return (lockedSupplyAmount * currentSupplyRatePerToken + Number(loanPosition?.loan[0]?.raw_borrowed || 0n) * currentBorrowRatePerToken);
  }, [miningRates, lockedSupplyAmount, loanPosition]);

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
            <DualLabel top="Net APY" bottom={`${instantNetApy === undefined ? UNDEFINED_SCALAR : (instantNetApy * 100).toFixed(2) + "%"}`} />
            <div className="h-10 border-l border-gray-300 dark:border-gray-700" />
            <div className={`grid grid-rows-[2fr_3fr] place-items-start`}>
              <span className={`text-gray-500 dark:text-gray-400 text-sm`}>Health factor</span>
              <HealthFactor loanPosition={loanPosition} />
            </div>
            <div className="h-10 border-l border-gray-300 dark:border-gray-700" />
            <DualLabel top="Mining rate" bottom={participationLedger.formatAmount(netMiningRate) + " TWV/day"} />
          </div>
        </div>

        {/* Net Worth Breakdown */}
        <div className="w-full lg:w-1/2 rounded-md border-0 sm:border border-gray-300 dark:border-gray-700 rounded-lg sm:p-4">
          {/* Total */}
          <div className="flex justify-between items-center mb-2 pb-2 border-b border-gray-200 dark:border-gray-600">
            <div className="text-gray-500 dark:text-gray-400 text-sm">Net Worth</div>
            <div className="text-gray-700 dark:text-white text-lg font-semibold">
              ${netWorth?.toFixed(2)}
            </div>
          </div>

          {/* Supply Section */}
          <div className="mb-2">
            <div className="text-sm text-gray-600 dark:text-gray-400 mb-0.5">Supply</div>
            <div className="space-y-0.5 pl-3">
              {/* Withdrawable */}
              <div className="flex justify-between">
                <div className="text-sm text-gray-600 dark:text-gray-400">Withdrawable</div>
                <div className="text-sm text-gray-900 dark:text-white font-medium">
                  {supplyLedger.formatAmountUsd(0n)} { /* TODO: use real value when implemented */ }
                </div>
              </div>
              {/* Locked Positions */}
              <div className="flex justify-between">
                <div className="text-sm text-gray-600 dark:text-gray-400">Locked</div>
                <div className="text-sm text-gray-900 dark:text-white font-medium">
                  {supplyLedger.formatAmountUsd(lockedSupplyWorth)}
                </div>
              </div>
            </div>
          </div>

          <div className="mb-2">
            <div className="text-sm text-gray-600 dark:text-gray-400 mb-0.5">Borrow</div>
            <div className="space-y-0.5 pl-3">
              {/* Borrowed */}
              <div className="flex justify-between">
                <div className="text-sm text-gray-600 dark:text-gray-400">Borrowed</div>
                <div className="text-sm text-red-600 dark:text-red-400 font-medium">
                  -{supplyLedger.formatAmountUsd(loanPosition?.loan[0]?.current_owed || 0n)}
                </div>
              </div>
              {/* Collateral */}
              <div className="flex justify-between">
                <div className="text-sm text-gray-600 dark:text-gray-400">Collateral</div>
                <div className="text-sm text-gray-900 dark:text-white font-medium">
                  {collateralLedger.formatAmountUsd(loanPosition?.collateral || 0n)}
                </div>
              </div>
            </div>
          </div>

          <div className="mb-2 flex flex-row justify-between">
            <div className="text-sm text-gray-600 dark:text-gray-400 mb-0.5">Mining</div>
            <div className="text-sm text-gray-900 dark:text-white font-medium">
              {participationLedger.formatAmountUsd(tracker?.allocated || 0n)}
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
          onWithdraw={handleWithdraw}
          withdrawLoading={withdrawLoading}
        />
      )}
    </div>
  );
}

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