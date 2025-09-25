import { Link, useParams } from "react-router-dom";
import { useMemo, useState } from "react";

import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../../../frontend/constants";
import ThemeToggle from "../ThemeToggle";
import { Account } from "@/declarations/ckbtc_ledger/ckbtc_ledger.did";
import { fromNullable, uint8ArrayToHexString } from "@dfinity/utils";
import LogoutIcon from "../icons/LogoutIcon";
import Avatar from "boring-avatars";
import { useUser } from "../hooks/useUser";
import { useAuth } from "@nfid/identitykit/react";
import { toAccount } from "@/frontend/utils/conversions/account";
import { protocolActor } from "../actors/ProtocolActor";
import { useFungibleLedgerContext } from "../context/FungibleLedgerContext";
import { fromNullableExt } from "@/frontend/utils/conversions/nullable";

const accountToString = (account: Account | undefined) : string =>  {
  let str = "";
  if (account !== undefined) {
    str = account.owner.toString();
    let subaccount = fromNullable(account.subaccount);
    if (subaccount !== undefined) {
      str += " " + uint8ArrayToHexString(subaccount); 
    }
  }
  return str;
}

const truncateAccount = (accountStr: string) => {
  // Truncate to show first 5 and last 3 characters
  if (accountStr.length > 10) {
    return accountStr.substring(0, 5) + "..." + accountStr.substring(accountStr.length - 3);
  }
  return accountStr;
}

const Profile = () => {

  const { principal } = useParams();
  const { user: connectedUser, connect, disconnect } = useAuth();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const { user, updateNickname, loading } = useUser();
  const [isEditingNickname, setIsEditingNickname] = useState(false);
  const [nicknameInput, setNicknameInput] = useState("");
  const [copied, setCopied] = useState(false);
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

  // Early return after all hooks are called
  if (connectedUser === undefined || connectedUser.principal.isAnonymous()) {
    return <div>Invalid principal</div>;
  }
  const handleCopy = () => {
    navigator.clipboard.writeText(accountToString(toAccount(connectedUser)));
    setCopied(true);
    setTimeout(() => setCopied(false), 2000); // Hide tooltip after 2 seconds
  };

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
    <div className="flex flex-col gap-y-4 items-center bg-slate-50 dark:bg-slate-850 h-full sm:h-auto p-4 sm:my-4 sm:rounded-md w-full sm:w-4/5 md:w-3/4 lg:w-2/3">
      <div className="relative group">
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
            <span
              className="text-gray-800 hover:text-black dark:text-gray-200 dark:hover:text-white bg-gray-300 dark:bg-gray-700 rounded-md px-2 py-1 font-medium self-center hover:cursor-pointer"
              onClick={handleCopy}
            >
              {truncateAccount(accountToString(toAccount(connectedUser)))}
            </span>
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
        { copied && (
          <div
            className={`absolute -top-6 left-1/2 z-50 transform -translate-x-1/2 bg-white text-black text-xs rounded px-2 py-1 transition-opacity duration-500 ${
              copied ? "opacity-100" : "opacity-0"
            }`}
          >
            Copied!
          </div>
        )}
      </div>
      <div className="flex flex-row justify-center w-full p-3 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800 rounded-lg">
        <ThemeToggle/>
      </div>

      {/* Mining Section */}
      <div className="w-full p-4 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800 rounded-lg">
        <h3 className="text-lg font-semibold mb-3 text-gray-900 dark:text-white">Mining</h3>

        {tracker ? (
          <div className="space-y-3">
            <div className="flex justify-between items-center">
              <span className="text-gray-700 dark:text-gray-300">TWV Received:</span>
              <span className="font-medium text-gray-900 dark:text-white">
                {formatAmount(tracker.received)}
              </span>
            </div>

            <div className="flex justify-between items-center">
              <span className="text-gray-700 dark:text-gray-300">TWV Owed:</span>
              <span className="font-medium text-gray-900 dark:text-white">
                {formatAmount(tracker.owed)}
              </span>
            </div>

            {tracker.owed > 0n && (
              <button
                onClick={handleWithdraw}
                disabled={withdrawLoading}
                className="w-full mt-3 px-4 py-2 bg-blue-500 hover:bg-blue-600 disabled:bg-gray-400 disabled:cursor-not-allowed text-white rounded-md transition-colors"
              >
                {withdrawLoading ? "Withdrawing..." : "Withdraw TWV"}
              </button>
            )}

            {tracker.owed === 0n && (
              <p className="text-sm text-gray-500 dark:text-gray-400 text-center mt-3">
                No TWV available to withdraw
              </p>
            )}
          </div>
        ) : (
          <div className="text-center text-gray-500 dark:text-gray-400">
            <p>No mining data available</p>
          </div>
        )}
      </div>
    </div>
  );
}

export default Profile;