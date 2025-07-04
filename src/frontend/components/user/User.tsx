
import { Link, useParams } from "react-router-dom";
import { useMemo, useState } from "react";
import Wallet from "../Wallet";

import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../../../frontend/constants";
import ThemeToggle from "../ThemeToggle";
import { useAuth } from "@ic-reactor/react";
import { Account } from "@/declarations/ck_btc/ck_btc.did";
import { fromNullable, uint8ArrayToHexString } from "@dfinity/utils";
import LogoutIcon from "../icons/LogoutIcon";

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

const User = () => {
  
  const { principal } = useParams();
  const { identity, logout } = useAuth();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });

  if (!principal || !identity) {
    return <div>Invalid principal</div>;
  }
  
  const account : Account = useMemo(() => ({
    owner: identity?.getPrincipal(),
    subaccount: []
  }), [identity]);
  
  const [copied, setCopied] = useState(false);
  const handleCopy = () => {
    navigator.clipboard.writeText(accountToString(account));
    setCopied(true);
    setTimeout(() => setCopied(false), 2000); // Hide tooltip after 2 seconds
  };

  if (principal !== identity.getPrincipal().toString()) {
    return <div>Unauthorized</div>;
  }

  return (
    <div className="flex flex-col gap-y-4 items-center bg-slate-50 dark:bg-slate-850 h-full sm:h-auto p-4 sm:my-4 sm:rounded-md w-full sm:w-4/5 md:w-3/4 lg:w-2/3">
      <div className="relative group">
        <div className="flex flex-row items-center space-x-2">
          <span
            className="text-gray-800 hover:text-black dark:text-gray-200 dark:hover:text-white font-medium self-center hover:cursor-pointer"
            onClick={handleCopy}
          >
            {accountToString(account)}
          </span>
          { identity.getPrincipal().toString() === principal && 
            <Link 
              className="self-end fill-gray-800 hover:fill-black dark:fill-gray-200 dark:hover:fill-white p-2.5 rounded-lg hover:cursor-pointer"
              onClick={()=>{logout()}}
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
      {
        !identity.getPrincipal().isAnonymous() && identity.getPrincipal().toString() === principal && <Wallet/>
      }
      {
        isMobile && 
          <div className="flex flex-row justify-center w-full p-3 shadow-sm border dark:border-gray-700 border-gray-300 bg-slate-200 dark:bg-gray-800 rounded-lg">
            <ThemeToggle/>
          </div>
      }
    </div>
  );
}

export default User;