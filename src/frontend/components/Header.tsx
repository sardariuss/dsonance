import { Link, useLocation, useNavigate } from "react-router-dom";
import React, { useState } from "react";
import { useAuth } from "@nfid/identitykit/react";
import LoginIcon from "./icons/LoginIcon";
import TowerLight from "../assets/towerview_light.png";
import TowerDark from "../assets/towerview_dark.png";
import Avatar from "boring-avatars";
import { useUser } from "./hooks/useUser";
import { MdOutlineAccountBalanceWallet, MdOutlineGroups } from "react-icons/md";
import { RiDashboardLine, RiWaterFlashLine, RiStackLine, RiSettings3Line } from "react-icons/ri";
import Wallet from "./wallet/Wallet";
import ThemeToggle from "./ThemeToggle";
import { useMediaQuery } from "react-responsive";
import { MOBILE_MAX_WIDTH_QUERY } from "../constants";

const NavigationComponent: React.FC<{ location: ReturnType<typeof useLocation> }> = ({ location }) => {
  return (
    <nav className={`flex flex-row items-center justify-center w-full h-12 min-h-12 sm:overflow-visible overflow-x-auto`}>
      <div className="flex flex-row items-center space-x-0 sm:space-x-8 sm:px-0 px-2">
        <Link
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-md transition-colors whitespace-nowrap ${
            location.pathname === "/"
              ? "text-black dark:text-white font-semibold"
              : "text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
          }`}
          to={"/"}
        >
          <RiStackLine size={18} />
          <span className="text-sm sm:text-base">Pools</span>
        </Link>
        <Link
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-md transition-colors whitespace-nowrap ${
            location.pathname === "/dashboard"
              ? "text-black dark:text-white font-semibold"
              : "text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
          }`}
          to={"/dashboard"}
        >
          <RiDashboardLine size={18} />
          <span className="text-sm sm:text-base">Dashboard</span>
        </Link>
        <Link
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-md transition-colors whitespace-nowrap ${
            location.pathname === "/dao"
              ? "text-black dark:text-white font-semibold"
              : "text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
          }`}
          to={"/dao"}
        >
          <MdOutlineGroups size={18} />
          <span className="text-sm sm:text-base">DAO</span>
        </Link>
        <Link
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-md transition-colors whitespace-nowrap ${
            location.pathname === "/protocol"
              ? "text-black dark:text-white font-semibold"
              : "text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
          }`}
          to={"/protocol"}
        >
          <RiSettings3Line size={18} />
          <span className="text-sm sm:text-base">Protocol</span>
        </Link>
        <Link
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-md transition-colors whitespace-nowrap ${
            location.pathname === "/faucet"
              ? "text-black dark:text-white font-semibold"
              : "text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
          }`}
          to={"/faucet"}
        >
          <RiWaterFlashLine size={18} />
          <span className="text-sm sm:text-base">Faucet</span>
        </Link>
      </div>
    </nav>
  );
};

const Header: React.FC = () => {
  const { connect } = useAuth();
  const { user } = useUser();
  const isMobile = useMediaQuery({ query: MOBILE_MAX_WIDTH_QUERY });
  const [showWallet, setShowWallet] = useState(false);
  const location = useLocation();
  const isDarkMode = document.documentElement.classList.contains("dark");
  const navigate = useNavigate();

  return (
    <header className="sticky top-0 z-30 flex flex-col relative w-full border-b border-gray-300 dark:border-gray-700 bg-slate-100 dark:bg-slate-900">
      {/* First Row: Logo and User Controls */}
      <nav className="flex flex-row items-center justify-between w-full xl:px-4 lg:px-3 md:px-2 px-2 h-14 min-h-14 relative">
        <img src={isDarkMode ? TowerDark : TowerLight} className="h-12 w-auto object-contain hover:cursor-pointer" onClick={() => navigate("/")}/>

        {/* Centered Navigation Links */}
        { !isMobile && (
          <div className="absolute left-1/2 transform -translate-x-1/2">
            <NavigationComponent location={location} />
          </div>
        )}

        {/* Right-aligned User Controls */}
        <div className="flex flex-row items-center space-x-2 sm:space-x-3">
          <ThemeToggle />
          {user && (
            <button
              className="h-9 w-9 sm:h-10 sm:w-10 rounded-full bg-white p-2 text-xl text-black dark:bg-white/10 dark:text-white hover:cursor-pointer"
              onClick={() => setShowWallet(true)}
            >
              <MdOutlineAccountBalanceWallet size={20} />
            </button>
          )}
          {user ? (
            <Link
              className="flex items-center stroke-gray-800 hover:stroke-black dark:stroke-gray-200 dark:hover:stroke-white rounded-lg hover:cursor-pointer"
              to={`/user/${user.principal}`}
            >
              <Avatar size={36} name={user.principal.toString()} variant="marble" />
            </Link>
          ) : (
            <div
              className="flex fill-gray-800 hover:fill-black dark:fill-gray-200 dark:hover:fill-white rounded-lg hover:cursor-pointer"
              onClick={() => {
                connect();
              }}
            >
              <LoginIcon />
            </div>
          )}
        </div>
      </nav>

      {/* Second Row: Navigation Links */}
      { isMobile && <NavigationComponent location={location} /> }

      <Wallet isOpen={showWallet} onClose={() => setShowWallet(false)} />
    </header>
  );
};

export default Header;