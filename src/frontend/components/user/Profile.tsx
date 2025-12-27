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
import { LendingTab } from "../borrow/LendingTab";
import { MiningContent } from "./MiningContent";
import DualLabel from "../common/DualLabel";
import { TabButton } from "../TabButton";
import { useProtocolContext } from "../context/ProtocolContext";
import HealthFactor from "../borrow/HealthFactor";
import { useMiningRatesContext } from "../context/MiningRatesContext";
import { aprToApy } from "@/frontend/utils/lending";
import PositionsTab from "./PositionsTab";
import { unwrapLock } from "@/frontend/utils/conversions/position";
import { useBorrowOperations } from "../hooks/useBorrowOperations";
import { useSupplyOperations } from "../hooks/useSupplyOperations";
import { useLendingCalculations } from "../hooks/useLendingCalculations";
import OrdersTab from "./OrdersTab";

const Profile = () => {
  const { principal } = useParams();
  const { user: connectedUser } = useAuth();

  // Early return before hooks if user is not authenticated
  if (connectedUser === undefined || connectedUser.principal.isAnonymous()) {
    return <div>Invalid principal</div>;
  }

  // Ensure the principal in the URL matches the connected user's principal
  if (principal !== connectedUser.principal.toString()) {
    return <div>Unauthorized</div>;
  }

  return <InnerProfile user={connectedUser} />;
}

const InnerProfile = ({ user: connectedUser }: { user: NonNullable<ReturnType<typeof useAuth>["user"]> }) => {

  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const { disconnect } = useAuth();
  const { user, updateNickname } = useUser();
  const [isEditingNickname, setIsEditingNickname] = useState(false);
  const [nicknameInput, setNicknameInput] = useState("");
  const [activeTab, setActiveTab] = useState<'positions' | 'lending' | 'mining' | 'orders'>('positions');

  const { participationLedger, supplyLedger, collateralLedger } = useFungibleLedgerContext();
  const { lendingIndexTimeline, info } = useProtocolContext();
  const { miningRates } = useMiningRatesContext();

  // Borrow operations hook - provides loan position data and operation handlers
  const borrowOps = useBorrowOperations(connectedUser);
  const { loanPosition } = borrowOps;

  // Supply operations hook - provides supply position data and operation handlers
  const supplyOps = useSupplyOperations(connectedUser);
  const { supplyInfo } = supplyOps;

  // Lending calculations hook - provides calculated values based on loan position
  const lendingCalcs = useLendingCalculations(loanPosition, collateralLedger, supplyLedger);

  // TODO: create query in backend to get whole supply worth
  // Fetch user's active positions to calculate locked supply
  const { data: userPositions, call: refetchUserPositions } = protocolActor.unauthenticated.useQueryCall({
    functionName: 'get_positions',
    args: [{
      account: { owner: connectedUser.principal, subaccount: [] },
      previous: [],
      limit: 100n,
      direction: { backward: null },
      filter_active: true
    }],
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

  // Calculate locked supply from user's active positions and weighted average APR
  const { lockedSupplyWorth, lockedSupplyAmount, positionsInfo } = useMemo(() => {
    if (!userPositions || !lendingIndexTimeline || !info) {
      return { lockedSupplyWorth: 0, lockedSupplyAmount: 0, positionsInfo: [] };
    }

    const currentSupplyIndex = lendingIndexTimeline.current.data.supply_index.value;
    let totalWorth = 0;
    let totalAmount = 0;

    let positionsInfo = userPositions.map(position => {
      if ('YES_NO' in position) {
        let worth = 0;
        let apy = 0;
        // Extract position data based on type (YES_NO)
        const yesNoPosition = position.YES_NO;
        const lock = unwrapLock(yesNoPosition);
        if (lock.release_date > BigInt(info.current_time)) {
          const foresight = yesNoPosition.foresight;
          worth = supplyLedger.convertToUsd(yesNoPosition.amount + foresight.reward) || 0;
          apy = aprToApy(foresight.apr.current);
        }
        return { worth, apy };
      }
    });

    // Sum up the worth and weighted APR of all active positions
    userPositions.forEach(position => {
      // Extract position data based on type (YES_NO)
      if ('YES_NO' in position) {
        const yesNoPosition = position.YES_NO;
        const amount = Number(yesNoPosition.amount);

        totalAmount += amount;

        const positionSupplyIndex = yesNoPosition.supply_index;
        totalWorth += amount * (currentSupplyIndex / positionSupplyIndex);
      }
    });

    return {
      lockedSupplyWorth: totalWorth,
      lockedSupplyAmount: totalAmount,
      positionsInfo
    };
  }, [userPositions, lendingIndexTimeline]);

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
    const positionsWorth = positionsInfo.reduce((acc, pos) => acc + Number(pos?.worth), 0);
    const supplyAccruedAmount = supplyInfo?.accrued_amount ? BigInt(Math.floor(supplyInfo.accrued_amount)) : 0n;
    const supplyWorth = supplyLedger.convertToUsd(supplyAccruedAmount) || 0;
    const borrowWorth = supplyLedger.convertToUsd(loanPosition?.loan[0]?.current_owed || 0n) || 0;
    const collateralWorth = collateralLedger.convertToUsd(loanPosition?.collateral || 0n) || 0;
    const miningWorth = participationLedger.convertToUsd(tracker?.allocated || 0n) || 0;

    // Sum up for total net worth
    // TODO: it is confusing if the mining worth is included in net worth,
    // the user might think the net APY applies to the mining worth as well
    netWorth = positionsWorth + supplyWorth + collateralWorth - borrowWorth + miningWorth;

    // Calculate instant net APY (exclude collateral as it doesn't generate yield)
    const equity = positionsWorth + supplyWorth - borrowWorth;
    const supplyApyWeight = positionsInfo.reduce((acc, pos) => {
      if (pos) {
        return acc + (Number(pos.worth) * pos.apy);
      }
      return acc;
    }, 0);
    // Add supply APY contribution
    const totalSupplyApyWeight = supplyApyWeight + (supplyWorth * supplyApy);
    if (equity > 0) {
      instantNetApy = (totalSupplyApyWeight - borrowWorth * borrowApy) / equity;
    }

    return { netWorth, instantNetApy };
  }, [lendingIndexTimeline, loanPosition, supplyInfo, lockedSupplyWorth, supplyLedger, collateralLedger, participationLedger, tracker]);

  const netMiningRate = useMemo(() => {
    if (!miningRates) {
      return undefined;
    }

    let { currentSupplyRatePerToken, currentBorrowRatePerToken } = miningRates;

    return (lockedSupplyAmount * currentSupplyRatePerToken + Number(loanPosition?.loan[0]?.raw_borrowed || 0n) * currentBorrowRatePerToken);
  }, [miningRates, lockedSupplyAmount, loanPosition]);

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
            <Link
              className="fill-gray-800 justify-self-end hover:fill-black dark:fill-gray-200 dark:hover:fill-white p-2.5 rounded-lg hover:cursor-pointer"
              onClick={()=>{ disconnect(); }}
              to="/">
              <LogoutIcon />
            </Link>
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
        <div className="w-full lg:w-1/2 rounded-md border border-gray-300 dark:border-gray-700 rounded-lg p-2 sm:p-4">
          {/* Total */}
          <div className="flex justify-between items-center mb-2 pb-2 border-b border-gray-200 dark:border-gray-600">
            <div className="text-gray-500 dark:text-gray-400 text-sm">Net Worth</div>
            <div className="text-gray-700 dark:text-white text-lg font-semibold">
              ${netWorth?.toFixed(2)}
            </div>
          </div>

          {/* Positions Section */}
          <div className="mb-2 flex flex-row justify-between">
            <div className="text-sm text-gray-600 dark:text-gray-400 mb-0.5">Positions</div>
            <div className="text-sm text-gray-900 dark:text-white font-medium">
              {supplyLedger.formatAmountUsd(lockedSupplyWorth)}
            </div>
          </div>

          <div className="mb-2">
            <div className="text-sm text-gray-600 dark:text-gray-400 mb-0.5">Lending</div>
            <div className="space-y-0.5 pl-3">
              {/* Supply */}
              <div className="flex justify-between">
                <div className="text-sm text-gray-600 dark:text-gray-400">Supply</div>
                <div className="text-sm text-gray-900 dark:text-white font-medium">
                  {supplyLedger.formatAmountUsd(supplyInfo?.accrued_amount ? BigInt(Math.floor(supplyInfo.accrued_amount)) : 0n)}
                </div>
              </div>
              {/* Collateral */}
              <div className="flex justify-between">
                <div className="text-sm text-gray-600 dark:text-gray-400">Collateral</div>
                <div className="text-sm text-gray-900 dark:text-white font-medium">
                  {collateralLedger.formatAmountUsd(loanPosition?.collateral || 0n)}
                </div>
              </div>
              {/* Borrowed */}
              <div className="flex justify-between">
                <div className="text-sm text-gray-600 dark:text-gray-400">Borrowed</div>
                <div className="text-sm text-red-600 dark:text-red-400 font-medium">
                  -{supplyLedger.formatAmountUsd(loanPosition?.loan[0]?.current_owed || 0n)}
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
          { key: 'positions', label: 'Positions' },
          { key: 'lending', label: 'Lending' },
          { key: 'mining', label: 'Mining' },
          { key: 'orders', label: 'Orders' }
        ].map((tab) => (
          <li key={tab.key} className="min-w-max text-center">
            <TabButton
              label={tab.label}
              setIsCurrent={() => setActiveTab(tab.key as 'positions' | 'lending' | 'mining' | 'orders')}
              isCurrent={activeTab === tab.key}
            />
          </li>
        ))}
      </ul>

    {/* Tab Content */}
      {activeTab === 'positions' && <PositionsTab user={connectedUser} />}
      {activeTab === 'lending' && (
        <LendingTab
          borrowOps={borrowOps}
          supplyOps={supplyOps}
          lendingCalcs={lendingCalcs}
          refetchUserPositions={refetchUserPositions}
        />
      )}
      {activeTab === 'mining' && (
        <MiningContent
          tracker={tracker}
          onWithdraw={handleWithdraw}
          withdrawLoading={withdrawLoading}
        />
      )}
      {activeTab === 'orders' && <OrdersTab user={connectedUser} />}
    </div>
  );
}

export default Profile;